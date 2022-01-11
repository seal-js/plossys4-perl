use strict;

use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Cwd;
use Data::Dumper;
use File::Path;
use File::Spec;

#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
my $current_dir;

sub save_current_dir {
    $current_dir = getcwd;
}

sub get_current_dir { return $current_dir; }

sub die_with_chdir {
    my ($msg) = @_;
    $msg ||= '';

    chdir get_current_dir();
    die "$msg\n";
}

#--------------------------------------------------------------------------------------------
# Purpose: Extract files from Zip archive. Store relative/absolute file path in an array.
# Parameters: hash 
#               option   => 'change_dir' or undefined,
#               zip_dir  => directory where Zip file is stored
#               zip_file => Zip file path
# Return: array reference. Each item is a file path 
#--------------------------------------------------------------------------------------------
sub extract_zip_archive {
    my (%arg) = @_;

    my $option   = $arg{option};
    my $zip_dir  = $arg{zip_dir};
    my $zip_file = $arg{zip_file};

    save_current_dir();

    if ( $option =~ /change_dir/i ) {

        if (! -d $zip_dir) {
            die_with_chdir("Directory [$zip_dir] does not exist!");
        }

        chdir $zip_dir; 
    }

    die_with_chdir("Missing parameter 'zip_file' path") if (!$zip_file);
    die_with_chdir("Zip file $zip_file does not exist!") if (! -e $zip_file);

    my $zip = Archive::Zip->new();
    die_with_chdir('Error reading zip file.') if $zip->read($zip_file) != AZ_OK;
    my @members = $zip->members();
    
    my @files;
    my $status;
    foreach my $element (@members) {
        #print "$element\n";
        my $member_name = $element->{fileName}; 
        $status = $zip->extractMember($element);
        die_with_chdir("Extracting $member_name from $zip_file failed\n") if $status != AZ_OK;

        if ( $option =~ /change_dir/i ) {
            $member_name = File::Spec->catfile($zip_dir, $member_name);
        }
        push @files, $member_name;
    }

    chdir get_current_dir();

    return \@files;
}

#--------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------
sub main {

    my $current_dir = getcwd;
    print "Current directory: [$current_dir]\n";

    my $status = eval {

		#my $zip_dir = $ARGV[0];
        my $zip_dir  = File::Spec->catdir($ENV{HOMEPATH}, 'projects', 'plossys4-perl', 'data');
        my $zip_file = File::Spec->catfile($zip_dir, 'tools.zip');

        my $option = 'change_dir';
        #my $option;

        my $files_aref = extract_zip_archive( 
            'option'   => $option, 
            'zip_dir'  => $zip_dir,
            'zip_file' => $zip_file
        );

        if ( !$files_aref ) {
            print "ERROR: Missing zip member paths\n";
            return 1;
        }

        print Data::Dumper->Dump([$files_aref], [qw(*files)]);
        return 0;
    };

    chdir $current_dir;
    
    if ($@) {
        print "main::main EXCEPTION: $@\n";
        return 1;
    }

    return $status;
}

my $exit = main();
exit($exit);