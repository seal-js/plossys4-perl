#!/usr/local/bin/perl -w
#!/usr/local/bin/perl -d:ptkdb
#
# 20.06.2007 JS  
#
###############################################################
use File::Basename;

#use strict;
sub printLine { my $char = "-" ; my $ele = $char x 70; print "$ele\n";}

#-------------------------------------------
# Sortieren eines Hash nach den Keys
#-------------------------------------------
%Test1 = ( 1 => 222, 2 => 43, 3 => 555, 4 => 87, 5 => 333 );
print "Hash_1 unsortiert\n";
foreach my $Key (keys %Test1)
    {
    my $Value = $Test1{$Key};
    print "$Key => $Value \n";
    }

print "\n\n";
print "Hash_1 sortiert nach Keys\n";
my @SortedKeys = sort keys %Test1;
foreach my $Key (@SortedKeys)
    {
    my $Value = $Test1{$Key};
    print "$Key => $Value \n";
    }

#-------------------------------------------
# Sortieren eines Hash nach den Values 
#-------------------------------------------
print "\n\n";
print "Hash_1 sortiert nach Values\n";
my @SortedValues = sort { $Test1{$a} <=> $Test1{$b} } keys %Test1;
foreach my $Key (@SortedValues)
    {
    my $Value = $Test1{$Key};
    print "$Key => $Value \n";
    }

#-----------------------------------------------------------------
# Sortieren eines komplizierten Hashes nach den 2. Values im Array 
#-----------------------------------------------------------------
print "\n\n";
print "Hash_2 unsortiert\n";
%Test2 = ( 1 => [222,10000], 
           2 => [43 ,45],
           3 => [555,6665],
           4 => [87 ,7777],
           5 => [333,444] );

foreach my $Key (keys %Test2)
    {
    my $Value1 = $Test2{$Key}->[0];
    my $Value2 = $Test2{$Key}->[1];
    print "$Key => [$Value1,$Value2] \n";
    }

print "\n\n";
print "Hash_2 sortiert nach 2. Value im Array\n";
my @SortedValues1 = sort { $Test2{$a}->[1] <=> $Test2{$b}->[1] } keys %Test2;
foreach my $Key (@SortedValues1)
    {
    my $Value = $Test2{$Key}->[1];
    print "$Key => $Value \n";
    }


sub GetUsedSubgates
    {
    my @SubGates = keys %GateSize;
    my @SortedGates = sort { $a <=> $b } @SubGates;
    my @Result = map { my $Value = $_;
                       if ( $Value > 0 && $Value < 10) 
                         { sprintf ("%02d", $Value); }
                       else
                         { $Value }
                       } @SortedGates;
    return @Result;
    }

%GateSize = ( 1 => [222,10000], 
              2 => [43 ,45],
              3 => [555,6665],
             10 => [555,6665],
             11 => [87 ,7777],
              9 => [333,444], 
              4 => [87 ,7777],
              5 => [333,444] );


#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
my @SortedSubGates = GetUsedSubgates ();
print "\n\nSubgates: @SortedSubGates\n";

printLine();

my @files = (
        { PLS_ORIG_NAME => "c:\\temp\\s1.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s2.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s20.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s21.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s3.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s31.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s11.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s4.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\s40.ras"},
        );


my @extendedFiles = (
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s1.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s2.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s20.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s21.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s3.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s31.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s11.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s4.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\2222222_s40.ras"},
        
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s1.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s2.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s20.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s21.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s3.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s31.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s11.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s4.ras"},
        { PLS_ORIG_NAME => "c:\\temp\\1111111_s40.ras"},
       
        );



# sort 1. by leading numbers
#      2. split and sort by last numbers
sub sortByFilename
    {
    my ($rl_Data) = @_;
    my @sortByLeadingNumbers =
    sort {
          my ($NameA, $DirA, $ExtA) = fileparse($a->{PLS_ORIG_NAME}, '\.[^\.]*');
          my ($NameB, $DirB, $ExtB) = fileparse($b->{PLS_ORIG_NAME}, '\.[^\.]*');
          $NameA cmp $NameB; 
          } @$rl_Data;
    
    sort {
          my ($NameA, $DirA, $ExtA) = fileparse($a->{PLS_ORIG_NAME}, '\.[^\.]*');
          my ($NameB, $DirB, $ExtB) = fileparse($b->{PLS_ORIG_NAME}, '\.[^\.]*');
          my @nameA = split ('_', $NameA);
          my @nameB = split ('_', $NameB);
          $NameA cmp $NameB; 
          } @sortByLeadingNumbers;

    }

my @sortedFiles = sortByFilename (\@extendedFiles);

printLine();
foreach my $rh_Data (@sortedFiles) { print $rh_Data->{PLS_ORIG_NAME} . "\n"; }
printLine();
1;

