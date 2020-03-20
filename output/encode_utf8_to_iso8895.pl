use strict;

use Cwd qw(abs_path);  # import function 'abs_path' to get a absolute path
use FindBin qw($Bin);
use lib "$Bin/../lib";  # get absolute path o subdirectory 'lib' 

use Carp;
use Encode qw(decode encode from_to);

#---------------------------------------------------------------------
# Purpose: Substitute characters not allowed in Windows OS
#---------------------------------------------------------------------
sub CleanFileNameSimple {
    # Only replace characters not allowed in Windows file names
    $_[0] =~ tr/\\\/:*?"<>|/_/;
    return $_[0];
}

#-----------------------------------------------------------------------
# Purpose  : Encode utf8 filename to iso-8859-1 and substitute invalid
#            characters not allowed by OS.
#            CAUTION: Take care that current queue in plossys.cfg has
#                     following setting: HEADER_OUTPUT_CODEPAGE "UTF-8"
#
#
# Parameter: $filename - utf8 string
# Return   : $filename encoded in iso-8859-1
#-----------------------------------------------------------------------
sub create_valid_filename_iso_8859_1 {
    my ($filename) = @_;
	
  my $fct =  (caller(0))[3];
	if (!$filename) {
	    confess "[E] $fct: first parameter must be a filename.";
	}
	
#	Log("Use filename [$filename]", 'I', $fct);
	my $new_filename = CleanFileNameSimple($filename);
#	Log("Invalid characters in filename substituted: [$new_filename]", 'I', $fct);
	Encode::from_to($new_filename, 'utf8', 'iso-8859-1', Encode::FB_QUIET);
#	Log("Filename iso-8859-1 encoded: [$new_filename]", 'I', $fct);
	return $new_filename;
}


1;
