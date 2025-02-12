package FindFiles;

use Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(traverse find_files);

use strict;
use warnings;

use Data::Dumper;
use File::Find;

exit traverse() if not caller;

#-----------------------------------------------------------
#-----------------------------------------------------------
sub function_table {

    my %function_table = (
            'dir'  => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; -d $file; }
                    },        
            'exe'  => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; $file =~ /\.exe$/; }
                    },
            'hed'  => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; $file =~ /\.hed$/; }                        
                    },
            'json'  => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; $file =~ /\.json$/; }
                    },

            'log'  => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; $file =~ /\.log$/; }                        
                    },
            'perl' => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; $file =~ /\.p[lm]$/; }
                    },
            'pdf'  => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; $file =~ /\.pdf$/; }                        
                    },
            'rdy'  => {
                        function => sub { find_files(@_) },
                        selector => sub { my $file = shift; $file =~ /\.rdy$/; }
                    },
    );

    return %function_table;
}

#-----------------------------------------------------------
#-----------------------------------------------------------
sub find_files {
    my ($results_aref, $selector) = @_;
 
    if ( ref $results_aref ne 'ARRAY') {
        die "[ERROR] Pass array referrence for results!\n";
    }

    if ( ref $selector ne 'CODE') {
        die "[ERROR] Pass reference to a selector function to select your hits!\n";
    }

    return sub {
        my $tmp = $File::Find::name;

        if ( $selector->($tmp) ) {            
           # print "Found: [$tmp]\n";
           push @$results_aref, $tmp;
        };
    }
}

#-----------------------------------------------------------
#-----------------------------------------------------------
sub traverse {
 
    my %default = (
           dir    => '.',
           action => 'perl'
    );

    my %params= (%default, @_);

    my $dir    = $params{dir} || '.';
    my $action = $params{action} || 'perl';

    $action = lc $action;

    print qq/Search for files with action [$action] in a tree starting in directory [$dir]\n/;

    my %function_table = function_table();

    my $working_unit = $function_table{$action};
    if ( ! $working_unit ) {
        print qq/[ERROR] Unknown action [$action]/;
        return 1;
    }

    my @found = ();
    my $process = $working_unit->{function}->(\@found, $working_unit->{selector});

    find (
        {
          wanted => $process,
          follow => 0  #  0 => don't follow links, 1 => follow links
        },
        $dir
    );

    print Data::Dumper->Dump([\@found], [qw(*found)]);

    return 0;
}

1;