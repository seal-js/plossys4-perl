use strict;

use FindBin qw($Bin);
use File::Spec;
use lib "$Bin/lib";

use FindFiles qw(traverse find_files);
use Data::Dumper;
use File::Find;

exit main();

#---------------------------------------------------------
#---------------------------------------------------------
sub main {

    #-------------------------------------------------------------------
    # Benutzung vordefinierter Suchaktionen
    #-------------------------------------------------------------------
    print '-' x 80 . "\n";
    print "Starte Funktion traverse() aus Modul lib/FindFiles.pm\n";
    traverse(dir => $ARGV[0], action => $ARGV[1]);

    #-------------------------------------------------------------------
    # Durchsuche Verzeichnisstruktur mit selbst definierten Selector
    #-------------------------------------------------------------------
    print '-' x 80 . "\n";
    my $dir = File::Spec->catfile('C:\SEAL', 'applications',);

    my @found = ();   # Wenn die Selektorbedingung true ist, dann Datei/Dir hier speichern

    # Baue Wanted-Funktion, die der Funktion find() übergeben wird.
    # find() ruft diese Funktion für jeden Knoten/Blatt auf.
    my $process = find_files(
        \@found,            # Reference auf Ergebnisliste
        sub { my $tmp = shift; -d $tmp && $tmp !~ /perl[-5]*/ ; }   # Selctor-Funktion, nur directories sammeln, keine Perl-Directories
    );

    #- 
    find(
        {
            wanted => $process,
            follow => 0  #  0 => don't follow links, 1 => follow links
        },
        $dir
        );

    print Data::Dumper->Dump([\@found], [qw(*found)]);

    return 0;
}