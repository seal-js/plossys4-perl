use strict;

use Carp;
use Cwd;
use Data::Dumper;

#-----------------------------------------------------------------------------
# Purpose: Read directory. Use parameter DIR | FILE | ALL to select what should 
#          be read.
# Param:  $dir  : /path/to/directory
#         $type : file type to read: DIR | FILE | ALL
#-----------------------------------------------------------------------------
sub read_directory 
    {
    my ($dir, $type) = @_;
    my $Fct = (caller(0))[3]; 
    
    return unless (-d $dir);
    
    $type ||= 'ALL';

    my @files;
    my $dir_handle;
    opendir ($dir_handle, $dir) or
        do { confess qq|Cannot read directory $dir|; }; 

    while (defined (my $file = readdir($dir_handle)))
        {
        my $path = "$dir/$file";
        if ($type =~ /DIR/i and -d $path )
            {
            push @files, $file;
            }
        elsif ($type =~ /FILE/i and -f $path ) 
            {
            push @files, $file;
            }
        elsif ($type =~ /ALL/i and (-f $path || -d $path) ) 
            {
            push @files, $file;
            }
       }
    closedir ($dir_handle); 
        
    return \@files;
    }

my $status = eval {
  my $dir = getcwd;
  my $files_aref = read_directory($dir, 'FILE');
  print Data::Dumper->Dump([$files_aref]);
};

if ($@) {
  print qq|EXCEPTION cougth: $@|;
}