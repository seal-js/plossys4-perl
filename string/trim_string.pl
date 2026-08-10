use strict;

#remove beginning and trailing whitespaces and remove beginning, trailing and consecutive duplicates of each element given in @Unwanted
#  in  Value    -  this will be normalized
#    @Unwanted  -  check everything in this
#  out        -   normalized string
sub NormalizeValue($@) {
    my ( $Value, @Unwanted ) = @_;
    my $Result = $Value;
    $Result =~ s/^\s*//;
    $Result =~ s/\s*$//g;
    if (@Unwanted) {
        my $qm;
        foreach (@Unwanted) {
            $qm = quotemeta $_;
            $Result =~ s/^$qm+//g;
            $Result =~ s/$qm$//g;
            $Result =~ s/$qm{2,}/$_/g;
        }
    }
    return $Result;
}



#--------------------------------------------------------------------------------------
# Test the functions defined in current script.
#--------------------------------------------------------------------------------------
package TestLocal;

use lib 'c:/SEAL/plossys4-perl/lib';
use sealperl::constants;

use strict; 

use Test::More tests => 6;

#--------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------
sub test_NormalizeValue_leading_whitespaces {

  my $test_string_leading_whitespaces = '        This string starts with whitespaces';
  my $got = main::NormalizeValue($test_string_leading_whitespaces);

  my $expected = 'This string starts with whitespaces';
  is ($got, $expected, 'Remove leading whitespaces');

  return $CODES{SUCCESS};
}

#--------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------
sub test_NormalizeValue_trailing_whitespaces {

  my $test_string_trailing_whitespaces = 'This string ends with whitespaces         ';
  my $got = main::NormalizeValue($test_string_trailing_whitespaces);

  my $expected = 'This string ends with whitespaces';
  is ($got, $expected, 'Remove trailing whitespaces');

  return $CODES{SUCCESS};
}


#--------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------
sub test_NormalizeValue_whitespaces {

  my $test_string_whitespaces = '            This string starts/ends with whitespaces         ';
  my $got = main::NormalizeValue($test_string_whitespaces);

  my $expected = 'This string starts/ends with whitespaces';
  is ($got, $expected, 'Remove leading/trailing whitespaces');

  return $CODES{SUCCESS};
}


#--------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------
sub test_NormalizeValue_whitespaces_and_duplicate_substrings {

  my $test_string_whitespaces = "     \t       ThisThis string starts/ends with this whitespaces       \t ";
  my @unwanted = ('This', 'with');

  my $got = main::NormalizeValue($test_string_whitespaces, @unwanted);

  my $expected = 'This string starts/ends with this whitespaces';
  is ($got, $expected, 'Remove leading/trailing whitespaces and substrings');

  my $Norm2 = "1a2b3cca45dd67e8__9";
  $got = main::NormalizeValue( $Norm2, "a", "b", "c", "d", "e", "_" );
  $expected = "1a2b3ca45d67e8_9";
  is ($got, $expected, 'Remove specified substrings');

  my $Norm1 = "   C:\\SEAL\\\\applications\\server\\\\plotserv\\plotter  \t";
  $got = main::NormalizeValue( $Norm1, $BACKSLASH );
  $expected = "C:\\SEAL\\applications\\server\\plotserv\\plotter";
  is ($got, $expected, 'Remove specified substrings');

  return $CODES{SUCCESS};
}


package main;

TestLocal::test_NormalizeValue_leading_whitespaces();
TestLocal::test_NormalizeValue_trailing_whitespaces();
TestLocal::test_NormalizeValue_whitespaces();
TestLocal::test_NormalizeValue_whitespaces_and_duplicate_substrings();

exit 0;