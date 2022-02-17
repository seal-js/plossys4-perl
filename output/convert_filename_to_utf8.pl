use strict;

use Carp;
use Data::Dumper;
use File::Spec;
use utf8;
use Win32::Unicode::File;

my $script = 'sepp.pdfout.customer.pl';

#-----------------------------------------------------------------
# Purpose: Create an empty file an make a copy with utf8 file name.
#-----------------------------------------------------------------
sub main {
	
	eval {
		
		#my $header_data = Data::Dumper->Dump([\%Hed],[qw(Hed)]);
		#Log($header_data, 'I', $script);
		
		#my $empty_file = File::Spec->catfile($ENV{PLSIO}, 'pdfout', 'test.txt');
		
		my $empty_file = 'test.pdf';
		create_file($empty_file);
        print "[I] File created [$empty_file]\n";
	    
		my $out_file = 'ПКУ-0007-00_EN.pdf';
	
		#my $out_file = File::Spec->catfile($ENV{PLSIO}, 'pdfout', 'ПКУ-0007-00_EN.pdf');
		
		#utf8::decode($Hed{NEW_FILENAME});
		#my $out_file = File::Spec->catfile($ENV{PLSIO}, 'pdfout', $Hed{NEW_FILENAME});
		
		if ( file_type(e => $out_file) ) {
			#Log("$out_file already exists.", 'I', $script);
			print "[I] $out_file already exists.\n";
			print "[I] delete $out_file\n";
			unlinkW($out_file);
			
			my $to_file = ' 中文字.pdf';
			print "[I] Move $empty_file to $to_file.\n";
			moveW($empty_file, $to_file) or confess $!;
		}
		else {	
			copyW($empty_file, $out_file) or confess $!;
		}
	};
	
	if ($@) {
		#Log("EXCEPTION: $@", 'E', $script);
		print "[E] EXCEPTION: $@ \n";
	}
	
	return;
}


#------------------------------------------------------------------------------
# Purpose   : Create empty trigger file (extension 'rdy').
# Parameters: $file
# Return    : 1 => ok
# Execption : throws exception if file cannot be opened
#------------------------------------------------------------------------------
sub create_file {
    my ($file) = @_;

    my $fct  = (caller(0))[3];

    if (!$file) {
        my $error_msg = qq|Missing parameter|;
        confess $error_msg;
    }
    my $fh_out;

    open ( $fh_out, '>', $file ) or
        do {
            my $error_msg = qq|Cannot open file [$file]: $!|;
            confess $error_msg;
        };
    close $fh_out;

    return 1;
}

exit main();

1;