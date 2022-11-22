#!/usr/local/bin/seppperl -w
#!/usr/local/bin/seppperl -w -d:ptkdb

# "@ $Id: create_printers.pl,v 1.27 2013/03/28 14:26:23 master Exp $"

# Function:   s. Usage
#
# Call:       xx.pl
#
# Parameters: None
#
# CVS Log at EOF

# Mark xx::yy, Shift+Strg+h => help concerning Lib
use strict;
use locale;
use Getopt::Long;
use File::Copy;
use File::Basename;
use File::Find;

require "libcfg2.pm";
use sealperl::time;

use vars qw(
$configdir
$rPlsCfg
@TplFiles
$TplDir
%configCache
$qprefixStart
$qprefixMax
);

if ($ENV{PLSTPA_CONFIG})
    {
    $configdir = "$ENV{PLSTPA_CONFIG}/am/PRIME";
    }
else
    {
    $configdir = "$ENV{PLSTOOLS}";
    }

$TplDir   = "$ENV{PLSPLS}/templates/plotter";


my $Stat = main();
exit $Stat;

#----------------------------------------------------------------------
#XXX Main main Main main Main main Main main Main main Main main Main main

sub main
    {

    # Get name and version of script out of CVS-String
    my @ID                 = split(/[, ]/, '$Id: create_printers.pl,v 1.27 2013/03/28 14:26:23 master Exp $');
    my $PrgName            = $ID[1];
    my $PrgVersion         = $ID[3];
    my $defaultconfigdir   = "$configdir/plscfgconfigs";
    my $defaultplscfg      = "$ENV{PLSPLS}/plossys.cfg";

    my $timestamp = DateTimeStamp();

    my $Usage = <<USAGE;

Function:     Create printer queues in plossys.cfg for benchmark tests

Pgm sequence: - save plossys.cfg
              - read plossys.cfg
              - read configuration that determines the printers to be
                installed
              - create all printer sections
              - change PLOTTER_SECTIONS
              - write plossys.cfg

Call:         ${PrgName} -c configuration file [-b basic plossys.cfg]
              ${PrgName} [-d]
              ${PrgName} [-h|-history|-v]

Parameters:
              -config|c  name of configuration file that determines the 
                         printers to be installed
              -p         name plossys.cfg to be used as base, default:
                         $ENV{PLSPLS}/plossys.cfg
              -qpstart   lowest value for printersimulator port
              -qpmax     highest value for printersimulator port 
              -d         debug mode
              -h         this message is displayed
              -history   script history
              -v         version of ${PrgName} is displayed

USAGE

my %Opt;

&GetOptions(
            "config|c:s" => \$Opt{config},
            "plscfg|p:s" => \$Opt{baseplscfg},
            "qpstart:s"  => \$Opt{qprefixstart},
            "qpmax:s"    => \$Opt{qprefixmax},
            "help|h"     => \$Opt{HELP},
            "history"    => \$Opt{HISTORY},
            "version|v"  => \$Opt{VERSION}
) or die <<EOF;
$PrgName: wrong call - abort
EOF

# display version number
if ($Opt{VERSION})
    {
    print "${PrgVersion}\n";
    return (0);
    }

# display usage message
if ($Opt{HELP})
    {
    print <<EOF;

$PrgName Version $PrgVersion

$Usage

EOF
        return (0);
        } ## end if ($Opt{HELP})

    my $config  = $Opt{config};
    my $PlsCfg  = $Opt{baseplscfg}  || $defaultplscfg;
    
    unless (defined $config)
        {
        print "A config file must be given, look into directory\n";
        print "$defaultconfigdir\n";
        return 10;
        }

    if (! -e $config)
        {
        print "Configuration file $config not found - Abort\n";
        return 20;
        }

    if (! -e $PlsCfg)
        {
        print "PLOSSYS configuration file $PlsCfg not found - Abort\n";
        return 30;
        }

    open PRTCFG, "<$config" or do
        {
        print "Could not open file $config\n";
        return 40;
        };

# plossys.cfg sichern
    my $PlsBak = "$PlsCfg" . "." . "$timestamp" . ".BAK";
    print "Copy $PlsCfg to $PlsBak\n";
    copy ("$PlsCfg", "$PlsBak") or die "Error while copying $PlsCfg to $PlsBak: $!";
# plossys.cfg lesen
    print "Reading $PlsCfg\n";
    $rPlsCfg = libcfg2->New(" ");
    $rPlsCfg->ReadCfg($PlsCfg) or die "$PlsCfg kann nicht gelesen werden.\n";

# Begrenzung der Ports für die Printersimulatoren:
#   Momentan werden Printersimulatoren für Ports 9100 bis 9199 gestartet
#   Evtl. Start und Ende variabel halten und als Parameter uebergebbar
    $qprefixStart = 9100;
    if ($Opt{qprefixstart})
        {
        $qprefixStart = $Opt{qprefixstart};
        }
    $qprefixMax = 9199;
    if ($Opt{qprefixmax})
        {
        $qprefixMax = $Opt{qprefixmax};
        }

# Datei mit gewünschten Druckerkonfigurationen lesen
    my ($Line, @Params, $AnzParams, @Values, $AnzVals, @Cfgs, $AnzQueues);
    my ($Stat, %Template);
    my $AktLine = 0;

# Je Zeile in Konfigurationsdatei die angeforderte(n) Queue(s) installieren
    while ($Line = <PRTCFG>)
        {
        $AktLine++;
        chomp $Line;
        $Line = &DeleteWhiteSpaces ($Line);
        $AnzQueues = 1; # Default (neu) setzen
# Leerzeilen skippen
        if ($Line eq "")
            {
            next;
            }

# Kommentarzeilen skippen
        if ($Line =~ /^#/)
            {
            next;
            }

        my %Tmp; 
# in der ersten Zeile müssen die Parameter aufgeführt sein
        if ($AktLine == 1)
            {
# Alle Parametername sollen Großbuchstabig sein
            $Line = uc($Line);
            @Params = split /;/, $Line;
            $AnzParams = $#Params;
            next;
            }
        
# Parameter aus der aktuellen Zeile raus holen
        my $Count = 1;
        my $Start = 1;
        @Values = split /;/, $Line;
        for (my $i=0; $i<=$AnzParams; $i++)
            {
            if ($Params[$i] eq "NUMBER")
                {
                $AnzQueues = $Values[$i];
                }
            else
                {
                if ($Params[$i] eq "CONFIG")
                    {
# Merken, welche Konfigurationen verwendet werden, zum späteren Kopieren der
# Dateien nach $PLSPLT
                    $Template{$Values[$i]}++;
                    }
                elsif ($Params[$i] eq "COUNT")
                    {
# COUNT = TRUE => Drucker bekommen eine lfd. Nummer angehängt
# COUNT nicht gesetzt = TRUE, damit bei bestehenden Konfigs nummeriert wird
                    $Count = $Values[$i];
                    if (! defined $Count or $Count eq "")
                        {
                        $Count = 1;
                        }
                    }
                elsif ($Params[$i] eq "START")
                    {
# Wenn die Nummerierung nicht bei 1 starten soll, kann das über den Parameter
# START angegeben werden
                    $Start = $Values[$i];
                    if (! defined $Start or $Start eq "")
                        {
                        $Start = 0;
                        }
                    }
                if ($Values[$i] eq "!DEL!")
                    {
                    undef $Tmp{$Params[$i]};
                    }
                else
                    {
                    $Tmp{$Params[$i]} = $Values[$i];
                    }
                }
            } # $i=0; $i<=$AnzParams; $i++
        
        if (!$Tmp{PLOTTER_NAME})
            {
            print "Parameter PLOTTER_NAME ist in Zeile $AktLine nicht angegeben\n - skip.";
            next;
            }

# Gewünschte Anzahl Drucker in plossys.cfg eintragen
        print "Create $AnzQueues $Tmp{PLOTTER_NAME}\n";
        $Stat = &UpdatePlsCfg ($rPlsCfg, \%Tmp, $AnzQueues, $Count, $Start);
        }

# Druckerkonfigurationsdateien nach $PLSPLT kopieren
    print "Copy all templates\n";
    $Stat = &CopyConfigs (\%Template);

# Prüfe lizenzierte Drucker
    my $licensedPlotters = $rPlsCfg->GetValue("LICENSE", "LICENSED_PLOTTERS", "NO");
    my $plotters = $rPlsCfg->GetValue("SYSTEM", "PLOTTER_SECTIONS", "NO");
    my @plotters = split " ", $plotters;
    my $numberPlotters = scalar @plotters;
    if ($licensedPlotters < $numberPlotters)
        {
        print "Warning: number of plotters ($numberPlotters) exceeds licended plotters ($licensedPlotters)!\n";
        }

# plossys.cfg schreiben
    print "Writing new $PlsCfg\n";
    $rPlsCfg->Write($PlsCfg);
    print "Done.\n";

    return 0;
    }

#----------------------------------------------------------------------
#XXX Subs
sub DeleteWhiteSpaces
    {
    my ($String) = @_;

    $_ = $String;
    /^\s*(.*)/;
    $_ = $1;
    /(.*\S)\s*/;
    $String = $1;
    return $String;
    }

sub expandEnvironmentVariable
    {
    my ($var) = @_;
    my $val;

    if ($var eq "")
        {
        $val = "%";    # %% -> %
        }
    else
        {
        $val = $ENV{$var};
        if (! defined $val)
            {
            $val = "";
            }
        }
    return $val;
    }


sub UpdatePlsCfg
    {
    my ($rPlsCfg, $rPrParm, $AnzQueues, $Count, $QueueNumber) = @_;

# Treibername von CONFIG entfernen
    my $Template = $rPrParm->{CONFIG};
    my @Parts = split /\./, $Template;
    $rPrParm->{CONFIG} = "$Parts[0].$Parts[1]";
    my $Config = $rPrParm->{CONFIG};
    if (!$rPrParm->{PLOTTER_CONS_NAME})
        {
        $rPrParm->{PLOTTER_CONS_NAME} = $rPrParm->{PLOTTER_NAME};
        }


    # zuerst im Cache nachsehen
    my $rPlsCfgTpl = $configCache{$Config};
    unless (defined $rPlsCfgTpl)
        {
        # noch nicht geladen, dann laden und in den Cache mit aufnehmen
        # plossys.cfg Schnipsel zur gewünschten Konfiguration lesen
        my $PlsCfgTpl = "$TplDir/$Template/$Config.plossys.cfg";
        unless (-f $PlsCfgTpl)
            {
            die "Plotter-Template $PlsCfgTpl nicht gefunden!\n";
            return 10;
            }

        $rPlsCfgTpl = libcfg2->New(" ");
        $rPlsCfgTpl->ReadCfg($PlsCfgTpl) or die "$PlsCfgTpl kann nicht gelesen werden.\n";
        $configCache{$Config} = $rPlsCfgTpl;
        }

    my @sectionKeys = $rPlsCfgTpl->GetSectionKeys ($Config);
    my @newPlotters;
    my $qprefix = $rPrParm->{QPREFIX};

    # geforderte Anzahl Drucker anlegen
    for (my $i=1; $i<=$AnzQueues; $i++)
        {
        my ($Printer);
        if ($Count)
            {
            $Printer = "$rPrParm->{PLOTTER_NAME}_$QueueNumber";
            $QueueNumber++;
            }
        else
            {
            $Printer = "$rPrParm->{PLOTTER_NAME}";
            }
        push @newPlotters, $Printer;

        # evtl vorhandene Druckersection löschen
        $rPlsCfg->DeleteSection ($Printer);
        # neue Section für den neuen Drucker anlegen
        $rPlsCfg->AddSection ($Printer);
        foreach my $Key (@sectionKeys)
            {
            my $Value = $rPlsCfgTpl->GetValue($Config, $Key, "NO");
            if ($Key eq "PLOTTER_NAME")
                {
                $Value = $Printer;
                }
            if ($Key eq "PLOTTER_CONS_NAME")
                {
                $Value = $Printer;
                }
            if ($Key eq "COUNT")
                {
                next;
                }
            if ($Key eq "QPREFIX")
                {
                next;
                }
            if (defined $Value)
                {
                if ($Value eq "")
                    {
                    $Value = "\"\"";
                    }
                if ($Value =~ /\s/)
                    {
                    $Value = "\"$Value\"";
                    }
                $rPlsCfg->SetValue ($Printer, $Key, $Value);
                }
            }

        # Parameter aus Konfiguration (er)setzen
        foreach my $Key (keys %$rPrParm)
            {
            my $Value = $rPrParm->{$Key};


            if ($Key eq "PLOTTER_NAME")
                {
                $Value = $Printer;
                }
            if ($Key eq "PLOTTER_CONS_NAME")
                {
                $Value = $Printer;
                }
            if (defined $qprefix && $qprefix ne "" && $Value ne "" && ($Key eq "QUEUE" || $Key eq "SEPP_QUEUE"))
                {
                # SS: expand environment variables %VAR% for performance test to expand %SSHSERVER%
                $Value =~ s/(%)([^\%]*)(%)/&expandEnvironmentVariable($2)/geo;
                $Value = "$qprefix\@$Value";
                }
            if ($Key eq "COUNT")
                {
                next;
                }
            if ($Key eq "QPREFIX")
                {
                next;
                }
            if ($Key eq "OWNCFG")
                {
                $Key = "CONFIG";
                $rPlsCfg->SetValue ($Printer, $Key, $Printer);
                next;
                }
            if (defined $Value && $Value ne "")
                {
                if ($Value =~ /\s/)
                    {
                    $Value = "\"$Value\"";
                    }
                $rPlsCfg->SetValue ($Printer, $Key, $Value);
                }
            }
        if (defined $qprefix and $qprefix ne "")
            {
            if ($qprefix < $qprefixMax)
                {
                $qprefix++;
                }
            else
                {
                $qprefix = $qprefixStart;
                }
            }
        }

    # aktualisiere key PLOTTER_SECTIONS
    my $Value = $rPlsCfg->GetValue("SYSTEM", "PLOTTER_SECTIONS", "NO");
    my @plotters = split " ", $Value;
    my %plotters;
    foreach (@plotters)
        {
        $plotters{$_} = 1;
        }
    foreach (@newPlotters)
        {
        $plotters{$_} = 1;
        }
    delete $plotters{dummy};
    @plotters = keys %plotters;

    # sortiere nach Zahlen wie im Windows Explorer
    @plotters = sort {
        my $tmpa = $a;
        my $tmpb = $b;
        $tmpa =~ s/(\d+)/sprintf("%05d",$1)/geo;
        $tmpb =~ s/(\d+)/sprintf("%05d",$1)/geo;
        uc $tmpa cmp uc $tmpb
    } @plotters;

    $Value = join " \\\n             ", @plotters;

    $rPlsCfg->SetValue("SYSTEM", "PLOTTER_SECTIONS", $Value);

    return 0;
    }

# 
sub CopyConfigs
    {
    my ($rhTemplate, $AnzTpl) = @_;
   
    foreach my $Template (keys %$rhTemplate)
        {
        my $TplBase = "$TplDir/$Template";
        my $PltDir = $ENV{PLSPLT};

        undef @TplFiles;
        find (\&wanted, $TplBase);
        foreach my $file (@TplFiles)
            {
            copy ("$file", "$PltDir") or die "Error while copying $file to $PltDir: $!";
            if ($^O ne "MSWin32")
                {
                # unix must create executable bits for .pl scripts
                my $targetfile = $file;
                $targetfile =~ s/^.*[\\\/]+//; # remove path
                $targetfile = $PltDir . "/" . $targetfile;
                chmod 0755, $targetfile;
                }
            }
        } 
    return 0;
    }

sub wanted
    {
    if (! -d "$File::Find::name")
        {
        push @TplFiles, "$File::Find::name";
        }
    return 1;
    }



#----------------------------------------------------------------------

#TODO implement your function

#1;   #uncomment if you create a lib
__DATA__

HISTORY

$Header: /home/e1/plscvs/testsystem/config/am/tools/create_printers.pl,v 1.27 2013/03/28 14:26:23 master Exp $

$Log: create_printers.pl,v $
Revision 1.27  2013/03/28 14:26:23  master
KS: use "!DEL!" to remove a parameter in the printer section

Revision 1.26  2012/10/02 13:30:16  master
KS: use return code from "sub main" to get notice of errors.

Revision 1.25  2012/09/07 08:52:06  master
SS: expand variables in plotter section only if we fill port@host for mtfilter. So other tests will work again.

Revision 1.24  2012/09/06 15:59:00  master
SS: skip comment lines beginning with a #,
SS: expand environment variables, so QUEUE and SEPP_QUEUE could be
expanded with eg. %SSHSERVER% for AM45 performance test to direct
to the client node where the printersims are running.

Revision 1.23  2012/06/29 08:33:04  master
(SS): create .pl scripts with chmod 0755 to have executable rights on linux

Revision 1.22  2012/06/28 16:13:37  master
KS/MT: remove white spaces in lines out of configuration file - line feed at end of
 line gave strange results

Revision 1.21  2012/06/13 16:38:04  master
KS: enabled use of own configuration files for each queue instead of using all the same

Revision 1.20  2012/06/13 11:37:27  master
KS: Added parameter START to enable start queue counting with 0 instead of 1

Revision 1.19  2012/05/23 09:42:44  master
SS: quote values with blanks

Revision 1.18  2012/05/23 08:20:35  master
KS:
- set default for COUNT to TRUE for compatibility reasons
- set value for PLOTTER_CONS_NAME to value for PLOTTER_NAME (=default)

Revision 1.17  2012/05/21 13:56:35  master
KS: Added parameter COUNT: FALSE = do not add a count to printer name, default = TRUE

Revision 1.16  2011/11/18 16:02:20  master
KS: enable minimum and maximum for printersimulator ports

Revision 1.15  2011/11/11 16:10:56  master
KS: für Ports der Printersimulatoren nur Werte von 9100 bis 9199 verwenden, da
      aktuell nur 100 Simulatoren gestartet werden

Revision 1.14  2011/11/11 15:18:43  master
KS:
- exclude directories when copying printer configs
- corrected copy statement

Revision 1.13  2011/11/11 14:57:18  master
KS: Removed user and server - not used

Revision 1.12  2011/11/11 13:02:29  master
KS: set configdir to $PLSTOOLS if PLSTPA_* not available

Revision 1.11  2011/11/11 12:47:35  master
KS: Removed variables for logging - not used.

Revision 1.10  2011/11/10 13:42:49  master
KS:
- Logfiles now in PLSTPA_ARCHIV
- User PLSTPA-Variables

Revision 1.9  2011/05/16 11:56:32  master
KS: set value in printer section to two double quotes if empty.

Revision 1.8  2011/05/16 09:12:21  master
KS: create BAK file for plossys.cfg

Revision 1.7  2011/05/16 07:52:08  master
added blank before multiline value PLOTTER_SECTIONS (ss)

Revision 1.6  2011/05/16 07:46:41  master
print warning if we have exceeded the number of licensed plotters (ss)

Revision 1.5  2011/05/16 07:43:03  master
read small template plossys.cfg part only once for each template (ss)

Revision 1.4  2011/05/16 07:28:19  master
sort printers by name AND number suffix like Windows Explorer does (ss)

Revision 1.3  2011/05/14 16:16:14  master
improved creating a bulk of printers (ss)

Revision 1.2  2011/05/13 14:50:20  master
KS: Sicherung der bisherigen Arbeit - noch keine funktionsfähige Version

Revision 1.1  2011/05/12 16:35:01  master
KS: not yet ready

