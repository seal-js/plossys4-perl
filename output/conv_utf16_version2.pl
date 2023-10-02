# Usage:
#   conv_utf16.pl infile

#--------------------------
# Needs Perl 5.28 or newer.
#--------------------------
use strict;
use warnings;

binmode(STDOUT, ':raw:encoding(UTF-8)');


exit main();

sub main {
	
	for my $utf16_file (@ARGV) {
		
	    print '-' x 80 . "\n";
	
        my $lines_aref = read_utf16_graphic_file($utf16_file);
		if ( ! $lines_aref ) {
			exit 1;
		}
		
	    foreach my $line (@$lines_aref) {
	        if  ($line =~ /^ST.......Belegnummer/) {
               print "$line\n";
	        }
			
			if  ($line =~ /^ST.......Document number/) {
               print "$line\n";
            }				
            if ( ($line =~ /^ST.......Kontakt$/) or ($line =~ /^ST.......Contact$/) ) {
               print "$line\n";
            }
            if ( ($line =~ /^ST.......Lieferantennummer$/) or ($line =~ /^ST.......Vendor No.$/) ) {
               print "$line\n";
            }
            if ( ($line =~ /^ST.......Lieferant$/) or ($line =~ /^ST.......Recipient$/) ) {
               print "$line\n";
            }			
			
	    }
	}
	
	return 0;
}


sub read_utf16_graphic_file {
    my ($file) = @_;

    my $fct = (caller(0))[3];

    if (! $file ) {
        #Log("Missing File [$file]", 'E', $fct);
		print "Missing File [$file]\n";
        return;
    }

    my $fh;
	
	# Use the following open when Perl version >= 5.26
    #if (open $fh, '<:raw:encoding(UTF-16)', $file) {
		
	# Use the following open when Perl version == 5.8.8		
    if (open $fh, '<:encoding(UCS-2BE)', $file) {		
    #Does not work! if (open $fh, '<:encoding(UTF-16LE)', $file) {
		
        # Read file. Store each line as array element.
        my @content = <$fh>;
        close($fh);

        my @lines;
        foreach my $line (@content) {
			# Remove CR/LF from line end
            chomp($line);
            push @lines, $line;
        }
        return \@lines;
    }
    else {
		print "Cannot read file [$file]\n";
    }
	
    return;
}
