use strict;
use warnings;

# Test harness for sealperl::powershell::RunPowerShellScript.
# It validates success, explicit non-zero return code, STDERR logging,
# and a technical failure case (missing PowerShell script).

use FindBin qw($Bin);
use File::Spec;

use lib "$Bin/../lib";
use sealperl::powershell qw(RunPowerShellScript);

my @log_lines;

sub Log {
    my ( $message, $level ) = @_;
    $level = defined $level ? $level : 'I';
    push @log_lines, "$level $message";
    print "$level $message\n";
}

sub run_case {
    my (%args) = @_;

    my $name          = $args{name};
    my $params        = $args{params} || [];
    my $expected_rc   = $args{expected_rc};
    my $expect_nonzero = $args{expect_nonzero} || 0;
    my $expect_stderr = $args{expect_stderr} || 0;

    @log_lines = ();

    my $rc = RunPowerShellScript(
        script  => $args{script},
        params  => $params,
        logging => 1,
    );

    my $ok_rc = $expect_nonzero ? ( $rc != 0 ? 1 : 0 ) : ( $rc == $expected_rc ? 1 : 0 );
    my $has_stderr_log = scalar grep { /\[STDERR\]/ } @log_lines;
    my $ok_stderr = $expect_stderr ? $has_stderr_log : 1;

    my $status = ( $ok_rc && $ok_stderr ) ? 'PASS' : 'FAIL';
    my $expected_text = $expect_nonzero ? 'rc!=0' : "rc=$expected_rc";
    print "$status: $name (expected $expected_text, got rc=$rc)\n";

    if ( !$ok_stderr ) {
        print "FAIL: expected STDERR log line but none was found\n";
    }

    return ( $ok_rc && $ok_stderr ) ? 1 : 0;
}

sub main {
    my $temp_dir = File::Spec->catdir( $ENV{SystemRoot} || 'C:\\Windows', 'Temp' );

    # Force a cmd.exe compatible temp folder when running on Windows-like shells.
    $ENV{TMP}  = $temp_dir;
    $ENV{TEMP} = $temp_dir;
    $ENV{TMPDIR} = $temp_dir;

    my $script = File::Spec->catfile( $Bin, '..', 'testfiles', 'test_powershell_module.ps1' );

    my @results;
    push @results, run_case(
        name        => 'Success case',
        script      => $script,
        params      => [ '-Name', 'PerlCaller', '-Payload', 'ok', '-ReturnCode', '0' ],
        expected_rc => 0,
    );

    push @results, run_case(
        name        => 'Non-zero return code case',
        script      => $script,
        params      => [ '-Name', 'PerlCaller', '-Payload', 'error_code', '-ReturnCode', '7' ],
        expected_rc => 7,
    );

    push @results, run_case(
        name          => 'STDERR logging case',
        script        => $script,
        params        => [ '-Name', 'PerlCaller', '-Payload', 'stderr', '-EmitError', '-ReturnCode', '0' ],
        expected_rc   => 0,
        expect_stderr => 1,
    );

    my $missing_script = File::Spec->catfile( $Bin, '..', 'testfiles', 'missing_test_powershell_module.ps1' );
    push @results, run_case(
        name        => 'Missing script error case',
        script      => $missing_script,
        params      => [ '-Name', 'PerlCaller' ],
        expect_nonzero => 1,
    );

    my $passed = scalar grep { $_ } @results;
    my $total  = scalar @results;

    print "Summary: $passed/$total tests passed\n";

    return $passed == $total ? 0 : 1;
}

exit main();
