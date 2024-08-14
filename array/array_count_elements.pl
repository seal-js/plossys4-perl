use strict;

use List::Util qw(sum);


#--- Use this array to find number of elements which fullfill a certain criterion
my @member = (
     'NATIVE', 'PDF', 'PDF', 'NATIVE', 'NATIVE', 'PDF', 'NATIVE'
);

#-------------------------------------------------------
# Filter functions
#-------------------------------------------------------
my $pdf_filter = sub {

   my ($ele) = @_;
   $ele eq 'PDF' ? 1 : 0;
};

my $native_filter = sub {

   my ($ele) = @_;
   $ele eq 'NATIVE' ? 1 : 0;
};

#-- Store filter functions into hash
my %filter = (
    'PDF'    => $pdf_filter,
    'NATIVE' => $native_filter,
);

#-- Select a filter function. It is passed to the script.

my $use_filter = $ARGV[0];

if ( ! $use_filter ) {
    print "usage: $0 <PDF|NATIVE>\n";
    exit 1;
}

if ( ! exists $filter{$use_filter} ) {

    print "usage: $0 <PDF|NATIVE>\n";
    exit 1;
}

# my $sum = sum map { $_ eq 'PDF' ? 1 : 0 } @member; 
 
my $sum = sum map { $filter{$use_filter}->($_) } @member; 

print "Anzahl $use_filter: $sum\n";
