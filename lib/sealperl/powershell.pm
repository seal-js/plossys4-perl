package sealperl::powershell;

use strict;
use warnings;
our $VERSION = '1.0';

use Encode qw(decode FB_CROAK);
use File::Spec;
use Exporter 'import';

our @EXPORT_OK = qw(RunPowerShellScript);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub _quote_cmd_arg {
	my ($value) = @_;
	$value = '' if !defined $value;
	$value =~ s/"/""/g;
	return qq("$value");
}

sub _log {
	my ( $message, $level ) = @_;
	return if !defined &main::Log;
	main::Log( $message, $level );
}

sub _log_stream_file {
	my ( $file, $prefix, $level ) = @_;
	return if !-f $file;

	open my $fh, '<:raw', $file or return;
	local $/ = undef;
	my $raw = <$fh>;
	close $fh;

	return if !defined $raw || $raw eq '';

	my $text;

	if ( $raw =~ /^\xFF\xFE/ ) {
		$text = eval { decode( 'UTF-16LE', $raw, FB_CROAK ) };
	}
	elsif ( $raw =~ /^\xFE\xFF/ ) {
		$text = eval { decode( 'UTF-16BE', $raw, FB_CROAK ) };
	}
	elsif ( $raw =~ /^\xEF\xBB\xBF/ ) {
		$text = eval { decode( 'UTF-8', $raw, FB_CROAK ) };
	}
	elsif ( $raw =~ /\x00/ ) {
		$text = eval { decode( 'UTF-16LE', $raw, FB_CROAK ) };
		$text = eval { decode( 'UTF-16BE', $raw, FB_CROAK ) } if !defined $text;
	}
	else {
		# ASCII is a strict subset of UTF-8, so this also covers pure ASCII files.
		$text = eval { decode( 'UTF-8', $raw, FB_CROAK ) };
	}

	$text = $raw if !defined $text;

	$text =~ s/^\x{FEFF}//;
	$text =~ s/\r\n/\n/g;

	for my $line ( split /\n/, $text ) {
		next if !defined $line || $line eq '';
		_log( "[$prefix] $line", $level );
	}
}

#-------------------------------------------------------------------------------
# Purpose: Run a PowerShell script with given parameters and log the output.
# Parameters:
#   script  - Path to the PowerShell script to run
#   params  - Array reference of parameters to pass to the script
#   logging - Boolean flag to enable/disable logging
# Returns: Exit code of the PowerShell script
# Example usage:
#   my $exit_code = RunPowerShellScript(
#       script  => 'C:/path/to/script.ps1',
#       params  => [ '-EmailAddresses', 'test@test.de;test2@test.de' ],
#       logging => 1
#   );
#-------------------------------------------------------------------------------
sub RunPowerShellScript {
	my %args = @_;
	my $script_path = $args{script};
	my $params_ref  = $args{params};
	my @script_args = ref $params_ref eq 'ARRAY' ? @{$params_ref} : ();
	my $do_logging  = defined $args{logging} && $args{logging} == 1 ? 1 : 0;

	my $exit_code = 1;

	eval {
		my $tmp_dir     = File::Spec->tmpdir();
		my $stdout_file = File::Spec->catfile( $tmp_dir, "test_systemcall_stdout_$$.log" );
		my $stderr_file = File::Spec->catfile( $tmp_dir, "test_systemcall_stderr_$$.log" );

		my @cmd_parts = (
			'powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
			'-File', _quote_cmd_arg($script_path),
			( map { _quote_cmd_arg($_) } @script_args ),
			'1>' . _quote_cmd_arg($stdout_file),
			'2>' . _quote_cmd_arg($stderr_file)
		);

		my $cmdline = 'cmd.exe /d /c ' . join( ' ', @cmd_parts );
		_log( "Start PowerShell script: [$cmdline]", 'I' ) if $do_logging;
		my $result = system($cmdline);

		if ($do_logging) {
			_log_stream_file( $stdout_file, 'STDOUT', 'I' );
			_log_stream_file( $stderr_file, 'STDERR', 'E' );
		}

		unlink $stdout_file if -f $stdout_file;
		unlink $stderr_file if -f $stderr_file;

		$exit_code = ( $result == -1 ) ? 1 : ( $result >> 8 );
		_log( "PowerShell exit code: $exit_code", $exit_code == 0 ? 'I' : 'E' ) if $do_logging;
		1;
	} or do {
		my $err = $@ || 'Unknown error when calling PowerShell script';
		chomp $err;
		_log( "PowerShell call failed: $err", 'E' ) if $do_logging;
	};

	return $exit_code;
}

1;
