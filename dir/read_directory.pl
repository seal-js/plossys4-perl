use strict;

use Carp;
use Cwd;
use Data::Dumper;

#-----------------------------------------------------------------------------
# Purpose: Read directory. Use parameter DIR | FILE | ALL to select what should 
#          be read.
# Parameters: $dir  : /path/to/directory
#             $type : file type to read: DIR | FILE | ALL
#             $absolute_path: 0 | 1
# Returns: array_ref
#-----------------------------------------------------------------------------
sub read_directory {
	
	my %defaults = (
		dir           => undef,
		type          => 'ALL',
		absolute_path => 0
	);
    my  %arg = (%defaults, @_);
	
    my $fct = (caller(0))[3]; 
    
	my $dir           = $arg{dir};
    my $type          = $arg{type};
	my $absolute_path = $arg{absolute_path};

    return unless (-d $dir);
	
    my $dir_handle;
    opendir ($dir_handle, $dir) or
        do { confess qq|Cannot read directory $dir|; }; 

	my $add_path = sub {
			my ($files_aref, $absolute_path, $path, $file) = @_;
			if ( $absolute_path ) {
				push @$files_aref, $path;
			}
			else {
				push @$files_aref, $file;
			}
	};	
	
    my @files;

    while (defined (my $file = readdir($dir_handle))) {
        my $path = "$dir/$file";
		
		next if ( $file eq '.' || $file eq '..');
		
        if ($type =~ /DIR/i and -d $path ) {
			$add_path->(\@files, $absolute_path, $path, $file);
        }
        elsif ($type =~ /FILE/i and -f $path ) {
			$add_path->(\@files, $absolute_path, $path, $file);			
        }
        elsif ($type =~ /ALL/i and (-f $path || -d $path) ) {
			$add_path->(\@files, $absolute_path, $path, $file);			
        }
    }
    closedir ($dir_handle); 
        
    return \@files;
}

#---------------------------------------------------------------------------
# Examples
#---------------------------------------------------------------------------
my $status = eval {

  my $dir = getcwd;
  my $files_aref = read_directory(dir => $dir, type => 'FILE');
  print qq|Only Files:\n|;
  print Data::Dumper->Dump([$files_aref]);
  print '-'x 80 . "\n";
  
  my $dir_aref = read_directory(dir => $dir, type => 'DIR');
  print qq|Only Directories:\n|;
  print Data::Dumper->Dump([$dir_aref]);
  print '-'x 80 . "\n";
  
  my $all_aref = read_directory(dir => $dir, type => 'ALL');
  print qq|All files:\n|;
  print Data::Dumper->Dump([$all_aref]);
  print '-'x 80 . "\n";
 
  my $all_absolute__aref = read_directory(dir => $dir, type => 'ALL', absolute_path => 1);
  print qq|All files:\n|;
  print Data::Dumper->Dump([$all_absolute__aref]);
  print '-'x 80 . "\n";
 
};

if ($@) {
  print qq|EXCEPTION caugth: $@|;
}