use strict;

use Data::Dumper;
use List::MoreUtils;

my $params =  "PLS_PLOTTER=PDFOUT,PLS_PLOTCOPY=2";

my @header_params =
           map { 
               my ($key, $value) = split( /=/, $_); 
               [$key,$value];
            }
           split( /,/, $params);

print Data::Dumper->Dump([\@header_params], [qw(*header_params)]);