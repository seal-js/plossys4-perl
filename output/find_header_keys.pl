use strict;

use Cwd qw(abs_path);  # import function 'abs_path' to get a absolute path
use FindBin qw($Bin);
use lib "$Bin/../lib";  # get absolute path o subdirectory 'lib' 

use Carp;
use Data::Dumper;
use File::Basename;
use File::Spec;

use Test::More qw(no_plan);

use sealperl::logger;

#load logger
my $logfile = File::Spec->catfile($Bin, 'find_header_keys.log');
my $log     = 'sealperl::logger'->new(FILE => $logfile);
#$log->info("Write messages to logfile: $logfile");

# Test header data
my %header = (
    COVER_TEXT_1 => 'Cover text 1',
    COVER_TEXT_7 => 'Cover text 7',
    COVER_TEXT_6 => 'Cover text 6',
    COVER_TEXT_2 => 'Cover text 2',
    COVER_TEXT_3 => 'Cover text 3',
    COVER_TEXT_10 => 'Cover text 10',
    COVER_TEXT_8 => 'Cover text 9',
    COVER_TEXT_12 => 'Cover text 12',
);

#-----------------------------------------------------------------------------
# Purpose  : Find all keys in header hash for a given header parameter basename.
#            The basename can occur several times added by a number.
#            Example:  MAILTEXT_LINE_1, MAILTEXT_LINE_2, ...
# Paramter : hash -
#             header => hash reference with job header data
#             key    => name of header parameter, ommit postfix '_<number>' for
#                       parameter 'key'
#             sort_by_number => 0|1  # it 1, sort by ascending number
# Return   : array reference
# Exception: none
#-----------------------------------------------------------------------------
sub find_header_keys {
    my (%arg) = @_;

    my @lines = grep( $_ =~ /$arg{key}/xims, keys %{$arg{header}} );
    if ($arg{sort_by_number}) {
       my @sorted_lines = sort {
           ($b =~ /_(\d+)/)[0] <=> ($a =~ /_(\d+)/)[0]
                     ||
             fc($a)  cmp  fc($b)
       } @lines;

       my @sorted_lines_reverse = reverse(@sorted_lines);
       return \@sorted_lines_reverse;
    }
    return \@lines;
}

#-----------------------------------------------------------------------------
# Purpose: Alternative in FP (functional programming) style.
#-----------------------------------------------------------------------------
sub find_header_keys_FP {
    my (%arg) = @_;

    die qq|Argument 'selector' must be a ref to CODE| if ( ref($arg{selector}) ne 'CODE');

    return
        reverse
        sort { $arg{selector}->($a, $b) }
        grep( $_ =~ /$arg{key}/xims, keys %{$arg{header}} );
}

#-----------------------------------------------------------------------------
# Run test
#-----------------------------------------------------------------------------
my $result_aref = 
    find_header_keys(
      header => \%header,
      key => 'COVER_TEXT',
      sort_by_number => 1
);

print  Data::Dumper->Dump([$result_aref], [qw(result)]);

#-----------------------------------------------------------------------------
# Run test in fuctional proramming style
# 1. Use small functions.
# 2. Don't mutate header data
# 3. Make it flexible
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Purpose: Create a comparator function used by sort(). 
#          The sort function passes $a and $b to this function.
# Params : $a, $b
# Returns: the result of $a compared with $b
#-----------------------------------------------------------------------------
my $selector = sub {
    my ($a, $b) = @_;

    ($b =~ /_(\d+)/)[0] <=> ($a =~ /_(\d+)/)[0]
                      ||
             fc($a)  cmp  fc($b)
};

#-----------------------------------------------------------------------------
# Purpose: Create a lambda function that stores %arg over end of function.
# Params: $arg{key}       - Find this header keyword
#         $arg{selector}  - Apply the comparator function on sort()
# Return: A function that return an array with header keywords
#-----------------------------------------------------------------------------
my $header_key_finder = sub {
    my(%arg) = @_;

    return sub {
        my (%header) = @_;

        find_header_keys_FP(
          header   => \%header,
          key      => $arg{key},
          selector => $arg{selector}
        );        
    };
};


my $find_COVER_TEXT = $header_key_finder->(key => 'COVER_TEXT', selector => $selector);

my @result_FP = $find_COVER_TEXT->(%header);

print  Data::Dumper->Dump([\@result_FP], [qw(result_FP)]);
print "Original header\n";
print  Data::Dumper->Dump([\%header], [qw(*header)]);