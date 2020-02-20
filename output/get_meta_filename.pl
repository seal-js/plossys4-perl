use strict;

use Cwd qw(abs_path);  # import function 'abs_path' to get a absolute path
use FindBin qw($Bin);
use lib "$Bin/../lib";  # get absolute path o subdirectory 'lib' 

use Carp;
use File::Basename;
use File::Spec;

use Test::More qw(no_plan);

use sealperl::logger;

#load logger
my $logfile = File::Spec->catfile($Bin, 'get_meta_filename.log');
my $log     = 'sealperl::logger'->new(FILE => $logfile);
#$log->info("Write messages to logfile: $logfile");

# Test header data
my %header = (
    PLS_META_TYPE => 'CoverSheet',
	PLS_ORIG_NAME => 'Test_document.pdf'
);

# Default tests using english names
my $meta_filename = get_meta_filename(\%header);
is($meta_filename, 'Cover.pdf', 'is cover sheet');

$header{PLS_META_TYPE} = 'TrailerSheet';
$meta_filename = get_meta_filename(\%header);
is($meta_filename, 'Trailer.pdf', 'is trailer sheet');

$header{PLS_META_TYPE} = 'MissingSheet';
$meta_filename = get_meta_filename(\%header);
is($meta_filename, 'Test_document_MissingSheet.pdf', 'is missing sheet');

$header{PLS_META_TYPE} = 'ErrorSheet';
$meta_filename = get_meta_filename(\%header);
is($meta_filename, 'Test_document_ErrorSheet.pdf', 'is error sheet');

$header{PLS_META_TYPE} = 'XXX';
$meta_filename = get_meta_filename(\%header);
is($meta_filename, undef , 'is not a meta file');


# Default tests using german names
my $language = 'D';

$header{PLS_META_TYPE} = 'CoverSheet';
my $meta_filename = get_meta_filename(\%header, $language);
#$log->info("CoverSheet filename: $meta_filename");
is($meta_filename, 'Deckblatt.pdf', 'is german cover sheet');

$header{PLS_META_TYPE} = 'TrailerSheet';
$meta_filename = get_meta_filename(\%header, $language);
is($meta_filename, 'Endeblatt.pdf', 'is german trailer sheet');

$header{PLS_META_TYPE} = 'MissingSheet';
$meta_filename = get_meta_filename(\%header, $language);
is($meta_filename, 'Test_document_Fehlblatt.pdf', 'is german missing sheet');

$header{PLS_META_TYPE} = 'ErrorSheet';
$meta_filename = get_meta_filename(\%header, $language);
is($meta_filename, 'Test_document_Fehlerblatt.pdf', 'is german error sheet');

$header{PLS_META_TYPE} = 'XXX';
$meta_filename = get_meta_filename(\%header, $language);
is($meta_filename, undef , 'is not a meta file');



#----------------------------------------------------------------------------
# Purpose:  Get filename of META files
#----------------------------------------------------------------------------
sub get_meta_filename {
    my ($header_href, $language) = @_;

    if (ref $header_href ne 'HASH') {
        confess 'Missing header data. Function parameter must be an hash reference.';
    }

    my $new_filename;

    $language ||= 'E';
    my ($basename, $dir, $ext) = fileparse($header_href->{PLS_ORIG_NAME} , '\.[^.]*?');

    if ($header_href->{PLS_META_TYPE} eq "CoverSheet") {
        if ($language eq "D")  {
            $new_filename = "Deckblatt.pdf";
        }
        else {
            $new_filename = "Cover.pdf";
        }
    }
    elsif ($header_href->{PLS_META_TYPE} eq "TrailerSheet") {
        if ($language eq "D")  {
            $new_filename = "Endeblatt.pdf";
            }
        else {
            $new_filename = "Trailer.pdf";
        }
    }
    elsif ($header_href->{PLS_META_TYPE} eq "MissingSheet") {
        if ($language eq "D")  {
            $new_filename = "$basename" . '_Fehlblatt.pdf';
        }
        else {
            $new_filename = "$basename" . '_MissingSheet.pdf';
        }
    }
	elsif ( $header_href->{PLS_META_TYPE} eq "ErrorSheet" ) {
			if ($language eq "D")  {
				$new_filename = "$basename" . '_Fehlerblatt.pdf';
			}
			else {
				$new_filename = "$basename" . '_ErrorSheet.pdf';
			}
		}

    return $new_filename;
}


1;