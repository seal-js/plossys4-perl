use strict;

my @strings = (undef, '012345' , '0012345', '00012345', '12345', '0000', '   0987');

foreach my $string (@strings) {
    print "Origin string: [$string]\n";
    if ($string) {
        $string =~ s/^[\s0]+//;  # Remove leading whitespaces and zeros
        print "Without leading zeros: [$string]\n\n"
    }
    else {
        print "Invalid string: [$string]\n\n";
    }
}