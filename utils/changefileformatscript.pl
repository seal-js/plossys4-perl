#!/usr/local/bin/seppperl
#!/usr/local/bin/seppperl -d:ptkdb
#--------------------------------------------------------------------------
# "@(#) $Id: changefileformatscript.pl,v 1.1 2013/01/28 16:41:15 carlos Exp $"
#
# Script for setting a fileformat_script within PLOSSYS netdome
# Conversion Service.
# 
# $Log: changefileformatscript.pl,v $
# Revision 1.1  2013/01/28 16:41:15  carlos
# Initial version, created for SDT-1227
#
#
#--------------------------------------------------------------------------
use strict;
use Getopt::Long;
use seppperl::msghandler;
use pgmanage;

my $ID = '$Id: changefileformatscript.pl,v 1.1 2013/01/28 16:41:15 carlos Exp $';
my $rLang = "seppperl::msghandler"->New(undef, "os", "plotserv");
my $Script = "changefileformatscript";

# Check environment
if (not $ENV{"PLSROOT"})
   {
   print $rLang->Get("PlsEnvironmentNotSet", $Script, "PLSROOT");
   print $rLang->Get("PlsExit");
   exit 1;
   }

# Get command line parameters
my %Parameters;
GetOptions('file=s' => \$Parameters{'FILE'},
           'h|help' => \$Parameters{'HELP'},
           'v|version' => \$Parameters{'VERSION'}) or do
    {
    PrintUsage();
    exit 1;
    };

# Start processing depending on the command line parameters
if ($Parameters{'HELP'})
    {
    # Print usage
    PrintUsage();
    exit 0;
    }
elsif ($Parameters{'VERSION'})
    {
    # Print version
    PrintVersion();
    exit 0;
    }
elsif (not $Parameters{'FILE'})
    {
    # Print usage
    print "Specify files URI with comman line parameter 'file'\n";
    PrintUsage();
    exit 1;
    }

# Start PostgreSQL server if not running
my $PgStateScript = "$ENV{PGSRV}/startstop/100.psql.status";
my $PgStartScript = "$ENV{PGSRV}/pgstart.pl";
if (-f $PgStateScript and -f $PgStartScript)
    {
    open STATION_STATE, "perl $PgStateScript|";
    my @StateText = <STATION_STATE>;
    close STATION_STATE;
    if (not defined @StateText or $StateText[0] =~ /^\[[W|E]\] /i)
        {
        # Postgres is not running, start it
        print $rLang->Get("PlsStartCall", $PgStartScript);
        eval {require "$PgStartScript"};
        if ($@)
            {
            exit 1;
            }
        }
    }

# Set fileformat_script
my $DB = new pgmanage();
$DB->SetValue("PGUSER", $DB->GetValue("ADMINUSER"));
$DB->SetValue("PGDATABASE", "netdome");
if (not $DB->RunQuery("update public.global_context set value='".
                      $Parameters{'FILE'}."' ".
                      "where key = 'fileformat_script'"))
    {
    exit 1;
    }
$DB->Destroy();
exit 0;


#
# Print usage message
#
sub PrintUsage
    {
    my ($Revision, $Dummy);
    my $Indent = " " x length("$Script.pl");
    print "******************************************************\n";
    print "$Script.pl\n";
    print "(C) SEAL Systems                          Version".
          "$Revision: 1.1 $Dummy\n";
    print "\n";
    print "Script for setting a fileformat_script within\n";
    print "PLOSSYS netdome Conversion Service.\n";
    print "------------------------------------------------------\n";
    print "Usage: $Script.pl -h\n";
    print "Usage: $Script.pl -v\n";
    print "Usage: $Script.pl -file <URI>\n";
    print "\n";
    print "-file <URI>         the files URI to set\n";
    print "-h                  this helptext\n";
    print "-v                  show version of script\n";
    print "******************************************************\n";
    }


#
# Print version
#
sub PrintVersion
    {
    my ($Revision, $Dummy);
    print "$Script.pl Version$Revision: 1.1 $Dummy\n";
    }



