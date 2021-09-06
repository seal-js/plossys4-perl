use strict;

my @words_1 = ('time', 'output', 'date');
my @words_2 = ('time', 'output');
my @words_3 = ();
my @words_4;
my @words_5 = ('huhu', 'hihi', 'haha');
my %words_6 = ( city => 'Hamburg', street => 'Buxtehuder Strasse');

my @test_data = (\%words_6, \@words_1, \@words_2, \@words_3, \@words_4, \@words_5, \%words_6);

my @expected_words = ('date', 'output', 'time');

foreach my $data (@test_data) {
    my $result =  have_same_elements($data, \@expected_words);
    print "result: $result\n";
}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
sub have_same_elements {
    print qq|have_same_elements()\n|;

    my ($arr1, $arr2) = @_;

    return 0 unless ( ref($arr1) eq 'ARRAY' );
    return 0 unless ( ref($arr2) eq 'ARRAY' );
    return 0 if (scalar @$arr1 != scalar @$arr2);

    my %counts = ();
    $counts{$_} += 1 foreach (@$arr1);
    $counts{$_} -= 1 foreach (@$arr2);
    
    return !(grep { $_ != 0 } values %counts);
}
