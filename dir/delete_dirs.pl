use strict;
use warnings;

use Carp;
use File::Path qw(remove_tree);
use Cwd qw(abs_path);
use File::Spec;

use seppperl::msghandler;   #- Modul to provide multiple languages independently.

my $rLang;                #- The scope of message object is valid only in this file.

$rLang = "seppperl::msghandler"->New(undef, "os", "tools", GetLocalMessages());

#----------------------------------------------------------------
# Purpose:    Delete all directories passed in the array reference.
# Parameters: Array reference of directories to be deleted.
# Returns:    List of all deleted files.
# Exceptions: Confess if parameter is not an array reference.
#----------------------------------------------------------------
sub delete_directories {
    my ($dirs_to_deleted_aref) = @_;
    
    confess 'Function need an array reference as parameter!' if (ref $dirs_to_deleted_aref ne 'ARRAY');

    my @total_deleted_files;

    foreach my $dir (@$dirs_to_deleted_aref) {
        if ( ! -d $dir ) {
            print $rLang->Get("ERR_NoDirectory", $dir);
            next;
        }

        my $abs_dir = abs_path($dir) || File::Spec->rel2abs($dir);
        
        my $deleted_files;
        my $errors;
        
        remove_tree($dir, 
            {
                safe      => 1,
                keep_root => 0,
                result    => \$deleted_files,
                error     => \$errors
            } 
        );

        # Print succesful deleted files
        foreach my $file (@$deleted_files) {
            my $abs_path = File::Spec->file_name_is_absolute($file)
                ? $file
                : File::Spec->catfile($abs_dir, $file);
            $abs_path = File::Spec->canonpath($abs_path);
            #print "$abs_path\n";
        }
        if (scalar @$deleted_files) {
            push @total_deleted_files, map { File::Spec->catfile($abs_dir, $_) } @$deleted_files;
        }

        # Print erronous or skipped files
        if (@$errors) {
            print $rLang->Get("ERR_DelFilesSkipped");
            foreach my $diag (@$errors) {
                my ($file, $message) = each %$diag;
                print $rLang->Get("File_Skipped", $file, $message);
            }
        }

    }

    return @total_deleted_files;
}

#---------------------------------------------------------------------------------
# Get locally defined messages
#---------------------------------------------------------------------------------
sub GetLocalMessages
    {
    my $rh_Table;
    return $rh_Table = {
        de => {
            ERR_DelFilesSkipped => "Folgende Dateien wurden uebersprungen (Fehler):",
            ERR_NoDirectory => "Verzeichnis %1 existiert nicht oder ist nicht verfuegbar.",
            File_Skipped => "Datei/Verzeichnis uebersprungen: %1 (%2)",
            },
        en => {
            ERR_DelFilesSkipped => "Following files have been skipped (error):",
            ERR_NoDirectory => "Directory %1 does not exist or is not available.",
            File_Skipped => "File/directory skipped: %1",
            },
        }
    }
