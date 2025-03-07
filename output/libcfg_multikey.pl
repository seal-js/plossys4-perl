use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use libcfg2;
use File::Basename;
use File::Copy;
use Data::Dumper;

exit main();

#-----------------------------------------------------------------------
# The main function is the entry point.
#-----------------------------------------------------------------------
sub main {

    my $status = eval {

		my $bookmark_file = get_bookmark_file();

		if ( ! -e $bookmark_file ) {
			print "Bookmark file [$bookmark_file] not found!\n";
			my $err_code = 2;
			return $err_code;
		}

		my $content = custom_read_bookmark_file($bookmark_file);
		if ( ! $content ) {
            print "Cannot read bookmark file [$bookmark_file].\n";
			my $err_code = 3;
			return $err_code;
		}

		custom_exchange_chapters_by_pages($content);
		$content->Write($bookmark_file);
		
		return 0;
	};
	
	if ($@) {
		my $err_msg = $@;
		print "Exception: $err_msg\n";
		$status = 4;
	}
	
    return $status;
}

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
sub get_bookmark_file {
    
    my $bookmark_file_orig = "$Bin/../testfiles/Table of Contents.bookm.txt.orig";
    my $bookmark_file      = "$Bin/../testfiles/Table of Contents.bookm.txt";

    copy("$bookmark_file_orig","$bookmark_file") or die "Copy failed: $!";
    
    return $bookmark_file;
}

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
sub custom_read_bookmark_file {
    my ($file) = @_;

    print "Read bookmark file [$file]\n";
	
    my $bookmarks = libcfg2->New();
    if ( ! $bookmarks )  {
       return;
    };
      
    return $bookmarks->ReadCfg($file);
 }

#-----------------------------------------------------------------------
# Purpose: Substitute chapter number by page number in each bookmark textarea
#          PLS_BOOKTXT.
#-----------------------------------------------------------------------
sub custom_exchange_chapters_by_pages {
    my ($bookmark_content) = @_;

	# PLS_BOOKTXT is a multiple key. This means that key PLS_BOOKTXT appears in multiple
	# lines with different values:
	#
	#   PLS_BOOKTXT = 1 Cover Sheet@0@1@@open@
    #   PLS_BOOKTXT = 2 Table of Contents@0@4@@open@
    #   PLS_BOOKTXT = 3 ITP AUSSENGEH�USE &GEH�USEDECKEL&STUTZEN@0@5@@open@
    #   PLS_BOOKTXT = 4 ITP AUSSENGEH�USE KOMPLETT@0@6@@open@
	#
    my $section = 'Page1';
	my $key     = 'PLS_BOOKTXT';
    my @values  = $bookmark_content->GetValue($section, $key);

    my @new_values;
	
    foreach my $val (@values) {

        my @elements = split (/\@/, $val);
		my $page = $elements[2];
        print "Substitute chapter number [$val] by page $page\n";
	
		$val =~ s/^\s*(\d)+/$page/;
		
		print "New bookmark text [$val]\n";
		push @new_values, $val;
    }
		
	my $section_obj = $bookmark_content->GetSection($section);
	$section_obj->DeleteKey($key);	
	
	# Set new values for multi key
	map { $bookmark_content->SetValue($section, $key, $_, 'NOQU', 1) } @new_values;
	
	my @mod_values = $bookmark_content->GetValue($section, $key);
		
	return @mod_values;
}
