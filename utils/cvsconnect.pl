#!/usr/local/bin/seppperl
#!/usr/local/bin/seppperl -d:ptkdb
# $Id: cvsconnect.pl,v 1.15 2012/09/26 09:12:17 stefan Exp $
#
# $Log: cvsconnect.pl,v $
# Revision 1.15  2012/09/26 09:12:17  stefan
# renamed roettsun2 -> sealscm001, use alias which works better in VMs
# with DNS
#
# Revision 1.14  2011/01/13 15:55:55  stefan
# removed DEB: messagebox
#
# Revision 1.13  2010/07/23 07:40:03  stefan
# simplified the UTCFileTime trick for windows. Put it into BEGIN function and
# everything works with just this one line.
#
# Revision 1.12  2010/07/15 10:36:27  stefan
# fixed SDT-65, workaround for buggy lstat() implementation from Microsoft
# with Perl module Win32::UTCFileTime if available. Warn if not available.
#
# Revision 1.11  2009/11/10 13:37:28  wow
# don't glob if no * in file name, useful for pathes with blanks using cvsconnect.pl in SEAL Shell Extender
#
# Revision 1.10  2009/10/27 15:14:15  sek
# removed / at beginning of relative path in Repository
#
# Revision 1.9  2009/10/06 12:00:48  stefan
# use /home/e1/plscvs instead of /home/u1/plscvs, roettsun2 only supports
# the correct path without symlinks
#
# Revision 1.8  2009/01/23 10:55:53  stefan
# use roettsun2 viewvc.cgi and no longer sepplin6
#
# Revision 1.7  2007/10/17 14:30:26  stefan
# windows only with MsgBoxes and -update feature to
# download latest version from CVS server
#
# Revision 1.6  2006/11/24 08:50:26  stefan
# lower case GetUserName
#
# Revision 1.5  2006/06/29 07:20:27  stefan
# connecting subdirs improved, create a CVS directory in the subdir
# with an empty "D" Entries file.
#
# Revision 1.4  2006/06/02 07:12:30  stefan
# sepplin3 -> roettlin3 so other departments could use this
#
# Revision 1.3  2006/06/01 08:54:43  stefan
# add directories as well
#
# Revision 1.2  2006/06/01 08:16:42  stefan
# use file modification time instead of CVS Id's date and time value,
# so TortoiseCVS now knows that this file is not modified
#
#
sub BEGIN { eval 'use Win32::UTCFileTime qw(:globally)'; }

use strict;
use Cwd;
use Time::Local;
use Getopt::Long;
use Win32;
use FindBin;
use LWP::Simple;
use File::Copy;

my $bDebug = 0;

my $help;
my $recursive;
my $CvsServer;
my $CvsUser;
my $CvsRoot;
my $CvsRootPath;
my $debugtext;
my $bNoOp;
my $bUpdate;

my $script = $0;
$script =~ s/.*[\\\/]//;

my $ID = '$Id: cvsconnect.pl,v 1.15 2012/09/26 09:12:17 stefan Exp $';
my @ID = split (/[, ]/, $ID);
my $version = $ID[3];


GetOptions (
    "h" => \$help,
    "server:s" => \$CvsServer,
    "user:s" => \$CvsUser,
    "R" => \$recursive,
    "n" => \$bNoOp,
    "update" => \$bUpdate,
    "debug" => \$bDebug,
    ) || &usage || exit (1);

if ($bUpdate)
    {
    # try to download latest cvsconnect.pl from CVS CGI script.
    &update();
    Exit(0);
    }

if ($#ARGV < 0 || $help)
    {
    &usage();
    Exit(0);
    }

if ($CvsServer eq "")
    {
    # nimm Default-Server
    $CvsServer = "sealscm001";
    }

if ($CvsUser eq "")
    {
    $CvsRoot = $ENV{'CVSROOT'};
    if ($CvsRoot =~ /^:pserver:(\S+)@(\S+):(\S+)$/)
        {
        # Oh, die CVSROOT Environment ist richtig gesetzt, nimm halt die
        $CvsUser = $1;
        $CvsServer = $2;
        $CvsRootPath = $3;
        }
    elsif ($CvsRoot =~ /^(\S+)@(\S+):(\S+)$/)
        {
        # Oh, die CVSROOT Environment ist richtig gesetzt, nimm halt die
        $CvsUser = $1;
        $CvsServer = $2;
        $CvsRootPath = $3;
        }
    else
        {
        if (-e "CVS/Root")
            {
            open ROOT, "<CVS/Root";
            $CvsRoot = <ROOT>;
            chomp $CvsRoot;
            close ROOT;
            if ($CvsRoot =~ /^:pserver:(\S+)@(\S+):(\S+)$/)
                {
                # Oh, die CVSROOT Environment ist richtig gesetzt, nimm halt die
                $CvsUser = $1;
                $CvsServer = $2;
                $CvsRootPath = $3;
                }
            elsif ($CvsRoot =~ /^(\S+)@(\S+):(\S+)$/)
                {
                # Oh, die CVSROOT Environment ist richtig gesetzt, nimm halt die
                $CvsUser = $1;
                $CvsServer = $2;
                $CvsRootPath = $3;
                }
            }
        else
            {
            # auf Windows kann man es noch mit dem NT-Usernamen probieren
            # auf Unix ist man ja womöglich schon ein plstest* oder test*
            # User.
            $CvsUser = lc &GetUsername();
            $CvsRootPath = "/home/e1/plscvs";
            }
        }
    }

if ($CvsUser eq "")
    {
    # CVSROOT nicht gesetzt oder zumindest falsch gesetzt
    &showErrorOK("Bitte Username angeben!");
    &usage("Bitte Username angeben!");
    Exit(1);
    }
else
    {
    # Username wurde angegeben
    $CvsRootPath = "/home/e1/plscvs";
    $CvsRoot = ":pserver:$CvsUser\@$CvsServer:$CvsRootPath";
    }

my $state;
# CVSROOT Environment fuer dieses Script setzen
$ENV{'CVSROOT'} = $CvsRoot;
$debugtext .= "CVSROOT = $CvsRoot\n" if $bDebug;

# vom aktuellen Verzeichnis aus die plossys.ini suchen, um
# damit den relativen Pfad im CVS zu ermitteln

my $CurrDir = getcwd();
$debugtext .= "current dir is $CurrDir\n" if ($bDebug);
my $PlsIniDir = &GetPlsIniDir ($CurrDir);
if ($PlsIniDir eq "")
    {
    &showErrorOK("Die Datei plossys.ini konnte nicht gefunden werden!\nDas aktuelle Verzeichnis\n\n$CurrDir\n\nist wohl kein Teststand.");
    Exit(1);
    }

my $CvsRelDir = substr ($CurrDir, length($PlsIniDir)+1);
$debugtext .= "reldir $CvsRelDir\n" if ($bDebug);

my @Files;
my $File;
foreach $File (@ARGV)
    {
    if ($File =~ /\*/)
        {
        push @Files, glob($File);
        }
    else
        {
        push @Files, $File;
        }
    }

while ($#Files >= 0)
    {
    my $RelFile = $Files[0];
    shift @Files;
    my $RelDir;
    my $CvsRepository;

    # '\' -> '/'
    $RelFile =~ s/\\/\//g;

    # suche, ob relativer Pfad oder nur Filename angegeben ist
    my $slash = rindex ($RelFile, "/");
    if ($slash >= 0)
        {
        # suche, ob absoluter Pfad oder nur relativer Pfad angegeben ist
        my $len1 = length ($RelFile);
        my $len2 = length ($CurrDir);
        my $len;
        if ($len1 >= $len2)
            {
            $len = $len2;
            }
        else
            {
            $len = $len1;
            }

        if (substr ($RelFile, 0, $len) eq substr ($CurrDir, 0, $len))
            {
            # absolut
            $debugtext .= "absoluter Pfad\n" if ($bDebug);
            $File   = substr ($RelFile, $slash+1);
            $RelDir = substr ($RelFile, length($CurrDir)+1);
            $slash = rindex ($RelDir, "/");
            if ($slash >= 0)
                {
                $RelDir = substr ($RelDir, 0, $slash);
                $CvsRepository = "$CvsRelDir/$RelDir";
                }
            else
                {
                $RelDir = "";
                $CvsRepository = "$CvsRelDir";
                }
            }
        else
            {
            # relativ
            $debugtext .= "relativer Pfad\n" if ($bDebug);
            $File   = substr ($RelFile, $slash+1);
            $RelDir = substr ($RelFile, 0, $slash);
            $CvsRepository = "$CvsRelDir/$RelDir";
            }
        }
    else
        {
        $File   = $RelFile;
        $RelDir = "";
        $CvsRepository = "$CvsRelDir";
        }

    $debugtext .= "file $File, reldir = $RelDir, cvsrep = $CvsRepository\n" if ($bDebug);

    my $CvsIsDir = "";
    my $CvsFile = "";
    my $CvsRev = "";
    my $CvsDateTime = "";

    if (-d $RelFile)
        {
        # directory
        $CvsFile = $RelFile;
        $CvsFile =~ s/^.*[\\\/]//g;
        $CvsFile =~ s/[\\\/]*$//g;
        $CvsIsDir = "D";
        }
    else
        {
        # Datei einlesen
        open TMP, "<$RelFile" or do
            {
            &showErrorAbort("Kann Datei $RelFile nicht öffnen!\n$!");
            next;
            };

        my @Stat;
        @Stat = lstat $RelFile;
        # schau auch gleich mal nach, ob Id und/oder Log enthalten sind
        $CvsFile = "";
        while (<TMP>)
            {
            if ( /.*\$Id\:\s+(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)\s+.*\$.*/ )
                 {
                 $CvsFile = $1;
                 $CvsRev  = $2;
                 my $CvsDate = $3;
                 my $CvsTime = $4;
                 if ($CvsFile ne $File)
                     {
                     &showWarnAbort("Filename $File ungleich CVS-Filename $CvsFile !!");
                     $CvsFile = "";
                     last;
                     }
                 $debugtext .= "File          = $CvsFile\n" if ($bDebug);
                 $debugtext .= "Revision      = $CvsRev\n" if ($bDebug);
                 $debugtext .= "CVS DateTime  = $CvsDate $CvsTime\n" if ($bDebug);
                 $debugtext .= "File DateTime = $Stat[9]\n" if ($bDebug);

                 # Umwandlung des Datums aus Id in anderes Format
                 # "1999/02/22 16:42:14"  ->  "Mon Feb 22 16:42:14 1999"
                 my ($year,$mon,$day) = ($CvsDate =~ /(\d+)\/(\d+)\/(\d+)/);
                 my ($hour,$min,$sec) = ($CvsTime =~ /(\d+):(\d+):(\d+)/);

                 my $epoch_seconds =timelocal($sec, $min, $hour, $day, $mon-1, $year);
                 $CvsDateTime = localtime($epoch_seconds);
                 $epoch_seconds = $Stat[9];
                 $CvsDateTime = gmtime($epoch_seconds);
#    &showInfoOK("DEB: $RelFile $epoch_seconds -> $CvsDateTime");
                 $debugtext .= "CvsDateTime = $CvsDateTime\n" if ($bDebug);
                 last;
                 }
            }
        close TMP;
        }

    if ($CvsFile eq "")
        {
        &showWarnAbort("File $RelFile enthält keine CVS-Id!");
        }
    else
        {
        # the work begins ...

        my $EntriesLine = "$CvsIsDir/$CvsFile/$CvsRev/$CvsDateTime//";
        &CreateCVS($RelDir, $CvsRepository, $CvsFile, $EntriesLine);
        if ($CvsIsDir eq "D")
            {
            if (length $RelDir)
                {
                $RelDir .= "/";
                }
            $RelDir .= $CvsFile;
            $CvsRepository .= "/";
            $CvsRepository .= $CvsFile;
            $EntriesLine = "D";
            &CreateCVS($RelDir, $CvsRepository, $CvsFile, $EntriesLine);
            }
        }
    }
Exit (0);


sub Exit
    {
    my ($code) = @_;

    if ($bDebug && $debugtext ne "")
        {
        Win32::MsgBox($debugtext, MB_ICONINFORMATION, "$script V$version");
        }
    exit $code;
    }
sub CreateCVS
    {
    my ($RelDir, $CvsRepository, $CvsFile, $EntriesLine) = @_;
    my $NewCvsDir;

    # Verzeichnis CVS erzeugen
    if ($RelDir ne "")
        {
        $NewCvsDir = "$RelDir/CVS";
        }
    else
        {
        $NewCvsDir = "CVS";
        }

    if (! -e "$NewCvsDir")
        {
        if ((mkdir "$NewCvsDir", 0777) == 0)
            {
            &showErrorOK("Fehler bei mkdir $NewCvsDir!\n$!");
            Exit(1);
            }
        }

    # Datei CVS/Root erzeugen
    my $CvsRootFile = "$NewCvsDir/Root";
    my $bWriteRootFile = 1;
    if (-f $CvsRootFile)
        {
        open ROOT, "<$CvsRootFile";
        my $LastCvsRoot = <ROOT>;
        chomp $LastCvsRoot;
        close ROOT;
        $bWriteRootFile = 0;
        if ($LastCvsRoot ne $CvsRoot)
            {
            &showWarnAbort("CVS-Root Datei $CvsRootFile wird geändert\n\nALT:\t$LastCvsRoot\nNEU:\t$CvsRoot");
            $bWriteRootFile = 1;
            }
        }

    if ($bWriteRootFile && !$bNoOp)
        {
        open ROOT, ">$CvsRootFile" or do
            {
            &showErrorOK("Fehler beim Schreiben von $CvsRootFile!\n$!");
            Exit(1);
            };
        print ROOT "$CvsRoot\n";
        close ROOT;
        }

    # Datei CVS/Repository erzeugen
    my $CvsRepositoryFile = "$NewCvsDir/Repository";
    my $bWriteRepositoryFile = 1;
    if (-f $CvsRepositoryFile)
        {
        open ROOT, "<$CvsRepositoryFile";
        my $LastCvsRepository = <ROOT>;
        chomp $LastCvsRepository;
        close ROOT;
        $bWriteRepositoryFile = 0;
        if ($LastCvsRepository ne $CvsRepository)
            {
            &showWarnAbort("CVS-Repository Datei $CvsRepositoryFile wird geändert von\n\nALT:\t$LastCvsRepository\nNEU:\t$CvsRepository");
            $bWriteRepositoryFile = 1;
            }
        }

    if ($bWriteRepositoryFile && !$bNoOp)
        {
        open REP, ">$CvsRepositoryFile" or do
            {
            &showErrorOK("Fehler beim Schreiben von $CvsRepositoryFile!\n$!");
            Exit(1);
            };
        $CvsRepository =~ s/^\///;
        print REP "$CvsRepository\n";
        close REP;
        }


    # Datei CVS/Entries erzeugen
    my @Entries;
    my $CvsEntriesFile = "$NewCvsDir/Entries";
    my $haveEntriesFile = 0;
    if (-f $CvsEntriesFile)
        {
        open ENT, "<$CvsEntriesFile";
        @Entries = <ENT>;
        chomp @Entries;
        $haveEntriesFile = 1;
        close ENT;
        }

    # neuen Eintrag uebernehmen
    my @NewEntries;
    my $Entry;
    foreach $Entry (@Entries)
        {
        if ( ! ($Entry =~ /^\/$CvsFile\//))
            {
            push @NewEntries, $Entry;
            }
        }
    if ($EntriesLine ne "D")
        {
        # always add new entry for files and real dirs
        push @NewEntries, $EntriesLine;
        }
    else
        {
        # just create an empty Entries file for a new connected subdir
        if (! $haveEntriesFile)
            {
            push @NewEntries, $EntriesLine;
            }
        }

    # und neu herausschreiben
    if (!$bNoOp)
        {
        open ENT, ">$CvsEntriesFile" or do
            {
            &showErrorOK("Fehler beim Schreiben von $CvsEntriesFile!\n$!");
            Exit(1);
            };
        foreach $Entry (@NewEntries)
            {
            print ENT "$Entry\n";
            }
        close ENT;
        }
    }


# suche eine plossys.ini ab dem angegebenen Verzeichnis
sub GetPlsIniDir ()
    {
    my ($CurrDir) = @_;
    my ($PlsIniName);


    while ($CurrDir ne "")
        {
        $debugtext .= "search in $CurrDir\n" if ($bDebug);
        $PlsIniName = "$CurrDir/plossys.ini";

        if (-f $PlsIniName)
            {
            # plossys.ini gefunden, liefere Directory zurueck
            return $CurrDir;
            }

        # eins hoeher suchen
        my $slash = rindex ($CurrDir, "/");
        if ($slash <= 0)
            {
            # nicht gefunden
            return "";
            }
        $CurrDir = substr ($CurrDir, 0, $slash);

        }
    
    }

sub usage ()
    {
    my ($msg) = @_;
    my $text;
    $text .= $msg . "\n\n" if (defined $msg);

    $text .= "Aufruf: cvsconnect.pl [-user username] [-server servername] file [file ...]\n";
    $text .= "cvsconnect.pl aktiviert für die angegebenen Files die CVS-Struktur im Teststand.\n";
    $text .= "\n";
    $text .= "Optionen:\n";
    $text .= "  -user     Name Deines Unix-Useraccounts\n";
    $text .= "  -server   Name des pserver CVS-Rechners, Default: sealscm001\n";
    $text .= "\n";
    $text .= "CVS wird hier per pserver Protokoll betrieben.  Zum einen, damit man auch in\n";
    $text .= "NT-Testständen von NT aus CVS-Dateien editieren kann.  Zum anderen, damit\n";
    $text .= "der Testuser unter Unix (plstest...) für CVS-commits umgangen wird.  Dies wird\n";
    $text .= "vom CVS ja auch verhindert und man muss eh einen anderen Unixuser verwenden.\n";
    $text .= "\n";
    $text .= "Es muss die pserver-Verbindung zum CVS Server auch funktionieren.\n";
    $text .= "Hierzu muss man sich meist einmalig mit 'cvs login' anmelden, es\n";
    $text .= "wird das Unixpasswort eueres Unixusers benötigt.\n";
    $text .= "\n";
    $text .= "cvsconnect.pl ist im CVS zu finden unter tools/cvstools/cvsconnect.pl";

    my $flags = MB_ICONINFORMATION;
    if (defined $msg)
        {
        $flags = MB_ICONSTOP;
        }
    Win32::MsgBox($text, $flags, "$script V$version");
    }

sub GetUsername
{
    my ($Username);

    # Get username
    $Username = Win32::LoginName();

    return $Username;
}

sub _msgbox
    {
    my ($msg, $flags) = @_;

    if ($bDebug && $debugtext ne "")
        {
        $msg .= "\n\nDEBUG INFORMATION:\n$debugtext";
        $debugtext = "";
        }

    return Win32::MsgBox($msg, $flags, "$script V$version");
    }

sub showWarnAbort
    {
    my ($msg) = @_;

    my $stat = _msgbox($msg, MB_ICONWARNING|1);
    if ($stat == 2)
        {
        exit 1;
        }
    }

sub showErrorAbort
    {
    my ($msg) = @_;

    my $stat = _msgbox($msg, MB_ICONSTOP|1);
    if ($stat == 2)
        {
        exit 1;
        }
    }

sub showInfoOK
    {
    my ($msg) = @_;

    my $stat = _msgbox($msg, MB_ICONINFORMATION);
    }

sub showErrorOK
    {
    my ($msg) = @_;

    my $stat = _msgbox($msg, MB_ICONSTOP);
    }

sub update
    {
    my $downloadLink = 'http://sealscm001:8080/cgi-bin/viewvc.cgi/tools/cvstools/cvsconnect.pl?view=co';
    my $content = get ($downloadLink);
    my $stat = 0;
    unless (defined $content)
        {
        &showErrorOK("Fehler beim Download des Scripts $script von\n$downloadLink");
        Exit(1);
        }
    if ( $content =~ /.*\$Id\:\s+(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)\s+.*\$.*/ )
        {
        my $CvsFile = $1;
        my $CvsRev  = $2;
        if ($CvsRev eq $version)
            {
            &showInfoOK("$script V$version ist bereits aktuell.");
            Exit(0);
            }
        else
            {
            &showInfoOK("Aktualisiere $script V$version -> V$CvsRev.");
            my $myscript = $FindBin::RealBin . "/" . $script;
            copy ($myscript, "$myscript.last") or do
                {
                &showErrorOK("Fehler beim Kopieren\nVON:\t$myscript\nNACH:\t$myscript.last\n$!");
                Exit(1);
                };
            open PERL, ">$myscript" or do
                {
                &showErrorOK("Fehler beim Schreiben von\n$myscript\n$!");
                Exit(1);
                };
            print PERL $content;
            close PERL;
            Exit(0);
            }
        }
    else
        {
        &showErrorOK("Download korrupt, kann keine CVS-Id ermitteln.\n$downloadLink.");
        }
    }

