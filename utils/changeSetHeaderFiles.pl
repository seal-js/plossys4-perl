#!/usr/local/bin/seppperl
#!/usr/local/bin/seppperl -d:ptkdb
#--------------------------------------------------------------------------
# "@ $Id: changeSetHeaderFiles.pl,v 1.0 2002/03/01 14:02:57 gabiw Exp $"
#|------------------------------------------------------------------------|
#|Copyright (c) by SEAL Systems AG, Lohmuehlweg 4, D-91341 Roettenbach    |
#|------------------------------------------------------------------------| 
# $Log:  $
#
# Funktion und Aufruf: siehe Usage 
#
#--------------------------------------------------------------------
use seppperl::msghandler;   #- Modul to provide multiple languages independently.

my ($rLang);                #- The scope of message object is valid only in this file. 
#my ($Language) = "en";     #- Uncomment it to test different languages quickly !
#my ($Language) = "de";
$rLang = "seppperl::msghandler"->New($Language, "os", "tools", GetLocalMessages ());
#==================================================================

use strict;
use Getopt::Long;
use File::Basename;
require 'libhed.pl';

use constant TRUE  => 1;
use constant FALSE => 0;
use constant OK    => 0;
use constant ERROR => 1;


my $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

my @suffixlist = ("\.pl");
my ($ScriptBase,$path,$suffix) = fileparse($0, @suffixlist);
my $Script     = basename ($0);
my $ScriptExp  = "$Script::";

my $scriptOptions = 
    {
    SCRIPT_BASE  => $ScriptBase,
    LOGFILE      => "$ENV{PLSLOG}/${ScriptBase}.log",
    };

if ( scalar @ARGV == 0)
    {
    usage();
    exit 1;
    }
exit 1 if ( getScriptOptions ($scriptOptions) != 0 );
exit 1 if ( evaluateScriptOptions($scriptOptions) != 0 );

run ($scriptOptions);

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
sub run
    {
    my ($rh_ScriptOptions) = @_;
    
    my $rl_HeaderFiles = readDirectory ($rh_ScriptOptions->{DIRECTORY}, $rh_ScriptOptions->{EXTENSION});
 
    my ($countgood, $countwrong) = 0;
    my %hed;
    my (@wrongfiles);
    my ($keyword,$newvalue);
    my $return;

    # Dateien bearbeiten
    foreach my $file (@$rl_HeaderFiles)
        {
        my $file = $rh_ScriptOptions->{DIRECTORY} . "/$file";
        if ( -d $file )
            {
            next;
            }
        if (! -e  $file)
            {
            print ($rLang->Get("ToolErrNoHed", $file));
            $countwrong ++;
            push @wrongfiles, $file;
            }
        elsif (! -w $file)
            {
            print ($rLang->Get("ToolErrNoWriteHed", $file));

            $countwrong ++;
            push @wrongfiles, $file;
            }
        else
            {
            %hed = &HedRead ($file);
            $keyword  = $rh_ScriptOptions->{KEY};
            $newvalue = $rh_ScriptOptions->{VALUE};
            if ( defined $rh_ScriptOptions->{DELETE} )
                {
                delete $hed{ $rh_ScriptOptions->{DELETE} };
                }
            else
                {
                $hed{$keyword} = $newvalue;
                }
            $return = &HedWrite ($file,%hed);
            if ( $return == 1 )
                {
                print ($rLang->Get("ToolChangedHed", $file));
                $countgood ++;
                }
            else
                {
                print ($rLang->Get("ToolNotChangedHed", $file));
                $countwrong ++;
                push @wrongfiles, $file;
                }
            }
        }

        print ($rLang->Get("ToolCountHed", $countgood));
        if ($countwrong)
           {
           print ($rLang->Get("ToolCountWrongHed", $countwrong));
           print ($rLang->Get("ToolListNotChangedHed"));
           foreach my $file (@wrongfiles)
               {
               print "$file\n";
               }
           }
    }

#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
sub getScriptOptions
    {
    my ($rh_Options) = @_;
    my $Fct = $ScriptExp . (caller(0))[3]; 
    unless (ref ($rh_Options) eq "HASH") {die "$Fct: ERROR: Parameter not defined!"};

    GetOptions('h|help'        => \$rh_Options->{HELP},
               'v|version'     => \$rh_Options->{VERSION},
               'dir=s'         => \$rh_Options->{DIRECTORY},
               'ext=s'         => \$rh_Options->{EXTENSION},
               'key=s'         => \$rh_Options->{KEY},
               'value=s'       => \$rh_Options->{VALUE},
               'del=s'         => \$rh_Options->{DELETE},
#               'debug'         => \$rh_Options->{DEBUG},
              ) or do
        {
        usage();
        return ERROR;
        };
    return OK;
    }

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
sub evaluateScriptOptions    
    {
    my ($rh_Options) = @_;
    my $Fct = $ScriptExp . (caller(0))[3]; 
    unless (ref ($rh_Options) eq "HASH") {die "$Fct: ERROR: Parameter not defined!"};
    if ($rh_Options->{HELP})
        {
        usage();
        return ERROR;
        }
    if ($rh_Options->{VERSION})
        {
        printVersion();
        return ERROR;
        }
    
    if ( ! defined $rh_Options->{EXTENSION})
        {
        $rh_Options->{EXTENSION} = "hed";
        }

    if ( $rh_Options->{DELETE} )
        {
        print "Delete header keyword." . $rh_Options->{DELETE} . "\n";
        return OK;
        }
 
    if ( ! -d $rh_Options->{DIRECTORY})
        {
        print $rh_Options->{DIRECTORY} . " is not a directory\n";
        return ERROR;
        }
    
     if ( ! $rh_Options->{KEY} )
        {
        print "Missing header keyword.\n";
        return ERROR;
        }
    
    if ( ! $rh_Options->{VALUE} )
        {
        print "Header key available but no value.\n";
        return ERROR;
        }

#    if ($rh_Options->{DEBUG})
#        {
#        LogLevel ("debug");
#        return OK;
#        }
    return OK;
    }

#-------------------------------------------------------
#-------------------------------------------------------
sub readDirectory
    {
    my ($dir, $ext) = @_;

    unless ( opendir(DIR, $dir) )
        {
        print "Cannot open directory $dir\n";
        return;
        }

    my $expr = "\.${ext}\$";
    my @files = grep { /${expr}/ } readdir(DIR);
    closedir(DIR);
    return \@files;
    }

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
sub usage
    {
    print ($rLang->Get("ScriptUsage", $0));
   }

#---------------------------------------------------------------------------------
# Get locally defined messages
#---------------------------------------------------------------------------------
sub GetLocalMessages
    {
    my $rh_Table;
    return $rh_Table = {
        de => {
              ScriptUsage => "*******************************************************************************\n" .
                              "%1    \n" .
                              "(c) 2013 SEAL Systems $VERSION\n\n" .
                              "Dieses Skript aendert einen Headereintrag fuer alle Headerdateien in \n" .
                              "einem Verzeichnis, das mit der Option -dir anzugeben ist.\n" .
                              "Es muss mit -key das Schluesselwort und mit -value der Headereintrag\n" .
                              "angegeben werden. Ist das Schluesselwort noch nicht vorhanden, so wird es \n" .
                              "eingefuegt.\n" .
                              "Standardmaessig werden Headerdateien mit der Extension \"hed\" gesucht.\n" .
                              "Alternativ kann mit der Option -ext eine andere Extension vorgegeben werden,\n" .
                              "wie z.B. \"h00\ oder \"HED\" .\n" .
                              "\n" .
                              "-------------------------- ----------------------------------------------------\n".
                              "Aufruf: %1  \n" .
                              "       -dir   <Directory path> \n" .
                              "       -key   <Header keyword> \n" .
                              "       -value <Header value> \n" .
                              "       -ext   <Alternative Header Extension> (optional)\n".
                              "       -del   <Header keyword> header Keyword loeschen\n".
                              "          \n\n" , 
               },
        
        en => {
             ScriptUsage => "*******************************************************************************\n" .
                          "%1    \n" .
                          "(c) 2013 SEAL Systems $VERSION\n\n" .
                          "This script is called after job processing in PLOSSYS.\n" . 
                          "Normally a SAP system ist notified about that by omsmessage.pl\n".
                          "In configuration file \"plossys.cfg\" a keyword (application) must be set\n" . 
                          "in section [SYSTEM].\n" .
                          "After the application key all parameters are listed which will be passed to \n" .
                          "the script.\n" .
                          "The application key decides which script in pls_scrappl_generic.pl is called.\n" .
                          "Addtionally user defined functions will be called before and after application\n" .
                          "execution. These function must be defined in pls_scrappl_generic_customer.pl\n" .
                          "All parameter defined in plossys.cfg will also be passed to the functions.\n" . 
                          "and contains the repro list\n" .
                          ".\n" . 
                          "------------------------------------------------------------------------------\n".
                          "Usage: %1 -plssrcappl <Applikation> [-param1 <value1>] [-param2 <value2>] ...\n".
                          "             \n\n" , 
             }
       };

    }

sub printVersion { print $VERSION; };

exit 0;

1;
