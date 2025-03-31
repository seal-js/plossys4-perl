use strict;

use Data::Dumper;
use File::Find;
use File::Spec;

# -----------------------------------------------------------------------------
# This script is an example how to traverse a directory structure using
# the find function from File::Find.
#
# 1. Define the root directory where to search with function get_ressource_dir
# 2. The file_find_factory() creates a wanted function that is called for each
#    directory node/leaf by find(). Also file_find_factory() returns a function
#    ref that helps to acces to all collected files. 
#    file_find_factory() is a closure that gets and store a regular expression
#    applied to in the wanted function to select what kind of files you want.
#  3. At the moment the find() aborted after the first hit.
# -----------------------------------------------------------------------------

exit main();

# -----------------------------------------------------------------------------
# Definition of subroutines
# -----------------------------------------------------------------------------

sub get_ressource_dir {
    return File::Spec->catdir($ENV{PLSTF});
}


sub main {

    # It's a little bit tricky to get the collected results.
    # The file_find_factory function returns a reference to the wanted function
    # that is called by find(), also a function ref ($reporter) to get the collected
    # files.
    my $search = qr/harley.tif$/;
    #my $search = qr/harley/;
    my $abort  = 0;  # 0 or 1

    my ($wanted, $reporter) = file_find_factory(regex => $search, abort => $abort);

    # find() is called in a eval block because the wanted function aborts with 'die' when we got
    # the first match. There is no other way to abort the find search earlier.
    eval {
        find ($wanted, get_ressource_dir());
    };

    my $found = 0;

    if ( $@ ) {
        # The catch block is called, if wanted exits with die.
        # This is done if $abort=1 and at least one file has been found.
        if( $@ =~ /found/ ) {
            $found = 1;
        }
    }

    if ( $found ) {
        # Get results
        my @files = $reporter->();
        print scalar @files . " file(s) found\n";
        if ( $abort ) {
            print "File found: $files[0]\n";
        }
    }
    else {
        my @files = $reporter->();
        print scalar @files . " file(s) found\n";        
        print Data::Dumper->Dump([\@files], [qw(*files)]);
    }

  return 0;
}


# ---------------------------------------------------------------------------------
# Purpose: Factory creates the wanted function used by find function (File::Find).
#          as well as the result function.
# Parameter: $arg{regex}  - search for this file name
#            $arg{abort}  - if set to 1, the find is aborted with die and returns the 
#                           the first hit.
# Return: two references to anon functions
#         The first one is the wanted function, the second a function
#         to get the collected results (file paths).
# Exception: dies, if $file is found. find() unfortunately does not provide
#            a normal abort option
# --------------------------------------------------------------------------------
sub file_find_factory {
    
    my (%arg) = @_;

    my $regex = $arg{regex};
    die 'Function file_find_factory needs a regular expression as first parameter!' if ( ref($regex) !~ /REGEXP/i );

    my @files = ();  # results which match the regex

    sub {
        my $found = $_; 
        if ( !-d $found) {
            #print $File::Find::name . "\n";
            if ( $found =~ /$regex/ ) {
                push @files, File::Spec->canonpath( $File::Find::name );
                if ( $arg{abort} ) {
                    die 'found'; 
                }
            }
        }
    }, sub { wantarray? @files : [@files] }
}

