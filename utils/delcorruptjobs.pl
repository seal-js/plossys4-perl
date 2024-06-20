#!/usr/local/bin/seppperl -w
#!/usr/local/bin/seppperl -w -d:ptkdb

# "@ $Id: delcorruptjobs.pl,v 1.9 2013/08/14 09:39:50 karin Exp $"

# Function:   s. Usage
#
# CVS Log at EOF

# Mark xx::yy, Shift+Strg+h => help concerning Lib
use strict;
no strict 'subs';
use Getopt::Long;
use File::Basename;
use File::Copy;
use File::Find;
use Cwd;
use Time::HiRes qw(sleep);

require 'libmenu.pl';

my @FilesFound = ();
my @SubDirs = ();
my $Stage0 = "";

# Get name and version of script out of CVS-String
my @ID         = split(/[, ]/, '$Id: delcorruptjobs.pl,v 1.9 2013/08/14 09:39:50 karin Exp $');
my $PrgName    = $ID[1];
my $PrgVersion = $ID[3];
print "\nInitialize $PrgName\n";

#TODO fill in Usage
my $Usage = <<USAGE;

Function:     Delete jobs in case of deadlocks

Pgm sequence: 1) Search given job in DB or
                 search inconsistant jobs in DB
              2) remove DB entries
              3) remove files from file system

Call:         ${PrgName} [-d]
              ${PrgName} [-j|-job JobId]
              ${PrgName} [-a|-auto]
              ${PrgName} [-h|-history|-v]

Parameters:
              -j JobId   remove job given by JobId
              -auto      remove all inconsistant jobs
              -d         debug mode
              -h         this message is displayed
              -history   script history
              -v         version of ${PrgName} is displayed

USAGE

my %Opt;
$Opt{JOBID} = "";

&GetOptions(
            "job|j:s"   => \$Opt{JOBID},
            "auto|a"    => \$Opt{AUTO},
            "debug|d"   => \$Opt{DEBUG},
            "help|h"    => \$Opt{HELP},
            "history"   => \$Opt{HISTORY},
            "version|v" => \$Opt{VERSION}
) or die <<EOF;
$PrgName: wrong call - abort
EOF

# display version number
if ($Opt{VERSION})
    {
    print "${PrgVersion}\n";
    exit(0);
    }

# display usage message
if ($Opt{HELP})
    {
    print <<EOF;

$PrgName Version $PrgVersion

$Usage

EOF
    exit(0);
    } ## end if ($Opt{HELP})

if ($Opt{HISTORY})
    {
    while (<DATA>) { print $_, "\n"; }
    exit 0;
    }

my $LogFile = "$ENV{PLSDATA}/log/" . substr($PrgName, 0, length ($PrgName)-3) . ".log";
my $DateTime = &DateTimeString ("nix");
&Log ("I", "Start $PrgName");

my ($AutoMode, $JobId, $SqlResult);
# For future use
###if (!$Opt{AUTO} && $Opt{JOBID} eq "")
###    {
###    &Log ("I", "Either -auto or -job JobID must be given - abort.");
###    exit 1;
###    }

if ($Opt{AUTO})
    {
    &Log ("E", "Auto mode not yet supported, use parameter -j jobid.", 1);
    exit;
###    &Log ("I", "Use auto mode, ignore any given job IDs.", 1);
###    $AutoMode = 1;
###    $JobId = "";
    }

if ($Opt{JOBID} ne "")
   {
    &Log ("I", "Remove job $Opt{JOBID} from system.", 1);
    $JobId = "$Opt{JOBID}";
    $SqlResult = "$ENV{PLSDATA}/postgresql/${JobId}_SqlResult.dat";
   }
# TODO: remove when auto mode is supported:
else
   {
    &Log ("E", "Parameter -j jobid missing\nAbort", 1);
    exit;
   }
# end of TODO: remove when auto mode is supported:

my $Files;
my $CurrentDir = &cwd();

my $IsWin = 0;
if (defined($ENV{WINDIR}) && $ENV{WINDIR} ne "")
    {
    $IsWin = 1;
    }

my $PSQL = "$ENV{PGBIN}/psql";
if ($IsWin)
    {
    $PSQL = "$ENV{PGBIN}\\psql";
    }
my $SqlLog = "$ENV{PLSDATA}/log/${JobId}_SqlLog.log";


&_debug("debug mode active");

#----------------------------------------------------------------------
#XXX Subs
#----------------------------------------------------------------------

#----------------------------------------------------------------------
sub GetWanted
#----------------------------------------------------------------------
    {
    # filter for more than one extension
    my $Tmp = $File::Find::name;
    if ($_ =~ /^stage000/i && -d $Tmp)
        {
        push @SubDirs, $Tmp;
        # keep in mind stage0000 to save files stored there later
        if ($_ eq "stage0000")
            {
            $Stage0 = $Tmp;
            }
        &Log ("I", "Found directory $Tmp");
        }
    if ($_ =~ /^$Files/i)
        {
        push @FilesFound, $Tmp;
        &Log ("I", "Found file $Tmp");
        }
    }

#----------------------------------------------------------------------
sub FindAndRemoveJobFiles
#----------------------------------------------------------------------
    {
    @FilesFound = ();
    @SubDirs = ();
    find(\&GetWanted,  @_);
    my $Result = 1;
    my ($File, $Dir);
    my $StrJobid = sprintf ("%06d", $JobId);
    my $TarFile = "$ENV{PLSDATA}/omng/${StrJobid}.tar";
    if (-e $TarFile)
        {
        $TarFile = "$ENV{PLSDATA}/omng/${JobId}_${DateTime}.tar";
        }
    # Save files found in stage0000
    if ($Stage0 ne "" and -d $Stage0)
        {
        chdir "$Stage0" or do
            {
            &Log ("W", "Cannot change to $Stage0, $!, 1");
            next;
            };
        my $Cmd = "tar cf $TarFile .";
        my $Status = system ($Cmd) >> 8;
        if ($Status)
            {
            print "Could not save files in $Stage0\n";
            print "Error code: $Status\n";
            print "Save files manually and then:\n";
            print "Hit Y to continue with deleting all files for job $JobId\n";
            print "Hit N to stop this script without deleting the files\n";
            print "Continue deleting the files for job $JobId Y/N [N]: ";
            chomp (my $Answer = uc <STDIN>);
            if ($Answer ne "Y")
                {
                print "Script aborted by user\n";
                &Log ("I", "Script aborted by user", 1);
                exit;
                }
            }
        }
    if (-e $TarFile)
        {
        if ($IsWin)
            {
            $TarFile =~ s/\//\\/g;
            }
        &Log ("I", "Job files found in stage0000 saved in:\n$TarFile", 1);
        }
    chdir $CurrentDir;
    # remove all files found for given job
    foreach $File (@FilesFound) 
        {
        &Log ("I", "remove $File");
        unlink $File;
    }
    # remove all stage-dirs found for given job
    foreach $Dir (@SubDirs) 
        {
        &Log ("I", "remove $Dir");
        rmdir $Dir;
        }
    # remove parent job dir
    my $Parent;
    my $Part1 = substr ($StrJobid, 0, 3);
    my $Part2 = substr ($StrJobid, 3, 3);
    if ($IsWin)
        {
        $Parent = "$ENV{PLSDATA}\\omng\\$Part1\\$Part2";
        }
    else
        {
        $Parent = "$ENV{PLSDATA}/omng/$Part1/$Part2";
        }
    my $Cmd = "rmdir $Parent";
    my $Status = system ($Cmd);
    return $Result;
    }

#----------------------------------------------------------------------
sub CheckForSet
#----------------------------------------------------------------------
    {
    # check whether job is member of a set -> ask if
    # - only this member shall be deleted
    # - complete set shall be deleted
    # - script shall abort
    my $SqlCheckSet = "$ENV{PLSDATA}/postgresql/${JobId}_SqlCheckSet.sql";
    if (-e $SqlCheckSet)
        {
        $SqlCheckSet = "$ENV{PLSDATA}/postgresql/${JobId}_${DateTime}_SqlCheckSet.sql";
        }
    open (SQLC ,">$SqlCheckSet") or die "Cannot open file $SqlCheckSet, $!\n";
    print SQLC "SELECT parentid from isjobdata where id = $JobId;\n";
    close SQLC;
    my $SqlSetResult = "$ENV{PLSDATA}/postgresql/${JobId}_SetResult.sql";
    my $Cmd = "$PSQL -t -h localhost -p $ENV{DB_PORT} -d netdome -U plsadmin -L $SqlLog -w -1 -f $SqlCheckSet -o $SqlSetResult";
    my $Status = system ($Cmd) >> 8;
    if ($Status)
        {
        &Log ("I", "Error while retrieving list of set members from database, $Status", 1);
        &Log ("I", "$Cmd", 1);
        &Log ("I", "Abort", 1);
        my $CatError = "cat $SqlLog >> $LogFile";
        system ($CatError);
        return 0;
        }
    open (SQLS, "<$SqlSetResult") or die "Cannot open file $SqlSetResult, $!\n";
    my $TmpJob;
    while (<SQLS>)
        {
        chomp $_;
        $_ =~ s/^\s+//;
        $_ =~ s/\s+$//;
        if ("$_" eq "")
            {
            next;
            }
        $TmpJob = $_;
        last;
        }
    if ($TmpJob > 0)
        {
        print "Job $JobId is member of set $TmpJob\n";
        print "Choose one of the following options to continue:\n";
        my @Options;
        push @Options, "Abort";
        push @Options, "Delete only member $JobId of set $TmpJob";
        push @Options, "Delete set $TmpJob with all its members";
        my $Answer = &_Choose (@Options);
        print "$Answer\n";
        if ("$Answer" eq "$Options[0]")
            {
            &Log ("I", "Script aborted by user\n", 1);
            exit;
            }
        elsif ("$Answer" eq "$Options[1]")
            {
            &Log ("I", "Delete only member $JobId of set $TmpJob\n", 1);
            }
        elsif ("$Answer" eq "$Options[2]")
            {
            &Log ("I", "Delete set $TmpJob with all its members\n", 1);
            $JobId = $TmpJob;
            }
        }
    }

#----------------------------------------------------------------------
sub DelJobInDB
#----------------------------------------------------------------------
    {
    my $SqlResult = "$_[0]";

    # get list of set members if available
    my $SqlFind = "$ENV{PLSDATA}/postgresql/${JobId}_SqlFind.sql";
    if (-e $SqlFind)
        {
        $SqlFind = "$ENV{PLSDATA}/postgresql/${JobId}_${DateTime}_SqlFind.sql";
        }
    open (SQLF, ">$SqlFind") or die "Cannot open file $SqlFind, $!\n";
    print SQLF "SELECT id from isjobdata where parentid = $JobId;\n";
    close SQLF;
    my $Cmd = "$PSQL -t -h localhost -p $ENV{DB_PORT} -d netdome -U plsadmin -L $SqlLog -w -1 -f $SqlFind -o $SqlResult";
    my $Status = system ($Cmd) >> 8;
    if ($Status)
        {
        &Log ("I", "Error while retrieving list of set members from database, $Status", 1);
        &Log ("I", "$Cmd", 1);
        &Log ("I", "Abort", 1);
        my $CatError = "cat $SqlLog >> $LogFile";
        system ($CatError);
        return 0;
        }

# Datenbank = netdome
# Schema = public
# ---------------------
# Tabelle       Spalte
# ---------------------
# job_context   job_no
# file_storage  job_no
# job           job_no
# isjobmore     id
# isjobdata     id
# set_sync      set_header

    my $SqlData = "$ENV{PLSDATA}/postgresql/${JobId}_SqlData.sql";
    if (-e $SqlData)
        {
        $SqlData = "$ENV{PLSDATA}/postgresql/${JobId}_${DateTime}_SqlData.sql";
        }
    open (SQL ,">$SqlData") or die "Cannot open file $SqlData, $!\n";

#   delete entries in data base: DO NOT CHANGE SEQUENCE!!!


    # delete all set members if available
    print SQL "DELETE from job_context where job_no in (select id from isjobdata where parentid = $JobId);\n";
    print SQL "DELETE from file_storage where job_no in (select id from isjobdata where parentid = $JobId);\n";
    print SQL "DELETE from job where job_no in (select id from isjobdata where parentid = $JobId);\n";
    print SQL "DELETE from isjobmore where id in (select id from isjobdata where parentid = $JobId);\n";
    print SQL "DELETE from isjobdata where parentid = $JobId;\n";
    # delete set or single job
    print SQL "DELETE from job_context where job_no = $JobId;\n";
    print SQL "DELETE from file_storage where job_no = $JobId;\n";
    print SQL "DELETE from set_sync where set_header = $JobId;\n";
    print SQL "DELETE from job where job_no = $JobId;\n";
    print SQL "DELETE from isjobmore where id = $JobId;\n";
    print SQL "DELETE from isjobdata where id = $JobId;\n";
    close SQL;
    $Cmd = "$PSQL -h localhost -p $ENV{DB_PORT} -d netdome -U plsadmin -L $SqlLog -w -1 -f $SqlData";
    $Status = system ($Cmd) >> 8;
    my $Cat = "cat $SqlLog >> $LogFile";
    system ($Cat);
    if ($Status)
        {
        &Log ("I", "Error while removing job from database, $Status", 1);
        &Log ("I", "$Cmd", 1);
        &Log ("I", "Abort", 1);
        return 0;
        }
    return 1;
    }

#----------------------------------------------------------------------
sub DelJobInFileSystem
#----------------------------------------------------------------------
    {
# ACHTUNG: from PLOSSYS netdome 4.5.0 upwards it will be 000/000/001 instead of
#          000/001
# save data from stage0000 and collect all stagennnn-names
    my ($Part1, $Part2, $Status, @Dirs);
    my $StrJobid = sprintf ("%06d", $JobId);

# get omng directory of job to be deleted
    $Part1 = substr ($StrJobid, 0, 3);
    $Part2 = substr ($StrJobid, 3, 3);
    push @Dirs, "$ENV{PLSDATA}/omng/$Part1/$Part2";
    
# Find and delete all files jobnnnnnn* in stage000?
    # job000327.hed
    $Files = "job$Part1$Part2";
    my $Result = &FindAndRemoveJobFiles(@Dirs);
    return 0;
    }

#prints debug messages to STDERR if debug mode is active
#----------------------------------------------------------------------
sub _debug
#----------------------------------------------------------------------
    {
    if ($Opt{DEBUG})
        {
        foreach (@_) { if ($_) {warn "[D] $_\n"; }}
        }
    return 1;
    } ## end sub _debug

# build iso datetime string from given Time::HiRes value
#----------------------------------------------------------------------
sub DateTimeString
#----------------------------------------------------------------------
    {
    my $DateTimeStr;
    my $now_fractions = &Time::HiRes::time();
    my ($sec, $min, $hour, $day, $mon, $year, $wday) = localtime (int $now_fractions); 
    my $msec = sprintf "%.3f", $now_fractions;
    $msec =~ s/\d+\.//g;
    $mon++;
    $year = $year + 1900;

    if ($_[0] eq "log")
        {
        $DateTimeStr = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d.%03d",
                            $year, $mon, $day, $hour, $min, $sec, $msec);
        }
    else
        {
        $DateTimeStr = sprintf ("%04d%02d%02d%02d%02d%02d%03d",
                            $year, $mon, $day, $hour, $min, $sec, $msec);
        }

    return $DateTimeStr;
    }

#----------------------------------------------------------------------
sub Log
#----------------------------------------------------------------------
    {
    my $DateTime = &DateTimeString ("log");
    open (LOG ,">>$LogFile") or die "Cannot open file $LogFile, $!\n";
    my $Text = "$DateTime \[$_[0]\] $_[1]\n";
    print LOG $Text;
    if ($_[2])
        {
        print $Text;
        }
    close LOG;
    }

#----------------------------------------------------------------------
#XXX Main main Main main Main main Main main Main main Main main Main main

my $Status;
my $OK = 0;

if ($JobId)
    {
    $Status = &CheckForSet;
    $Status = &DelJobInDB ($SqlResult);
    $Status = &DelJobInFileSystem;
    }

open (JOBS, "<$SqlResult") or do
    {
    &Log ("I", "No members to delete.\n");
    };

while (<JOBS>)
    {
    chomp $_;
    $_ =~ s/^\s+//;
    $_ =~ s/\s+$//;
    if ("$_" eq "")
        {
        next;
        }
    $JobId = $_;
    $Status = &DelJobInFileSystem;
    }
close JOBS;

# restart maingate
my $GateStop = "$ENV{PLSPLS}/gatestop.pl";
my $GateStart = "$ENV{PLSPLS}/gatestart.pl";
# stop it
$Status = 0;
if (-f $GateStop)
    {
    $Status = system ("$GateStop maingate");
    }
if ($Status)
    {
    &Log ("I", "Please stop and start station maingate if processing of jobs does not coninue.", 1);
    }
# start it if stop was successfully
elsif (-f $GateStart)
    {
    $Status = system ("$GateStart maingate");
    }
if ($Status)
    {
    &Log ("I", "Please check if station maingate is started.", 1);
    }
else
    {
    &Log ("I", "maingate restarted", 1);
    }

&Log ("I", "End $PrgName\n", 1);
if ($IsWin)
    {
    $LogFile =~ s/\//\\/g;
    }
print "For detailed information s. $LogFile\n";

exit;

#1;   #TODO uncomment if you create a lib
__DATA__

HISTORY

$Header: /home/e1/plscvs/server/plotserv/servertools/delcorruptjobs.pl,v 1.9 2013/08/14 09:39:50 karin Exp $

$Log: delcorruptjobs.pl,v $
Revision 1.9  2013/08/14 09:39:50  karin
Added restart for maingate

Revision 1.8  2013/08/12 14:31:50  karin
Improved handling if given job to be deleted is a set member

Revision 1.7  2013/08/06 07:40:45  karin
- Finished deleting files and directories for set members
- Added msecs to time stamp
- Changed slashes to backslashes in case of Windows for better copy/paste of log and tar file names

Revision 1.6  2013/08/05 16:07:09  karin
Loeschen der Dateien zu Satzmitgliedern eingefuegt - noch nicht ganz OK.

Revision 1.5  2013/08/01 15:45:13  karin
First steps to remove sets.

Revision 1.4  2013/08/01 14:58:53  karin
Minor corrections

Revision 1.3  2013/08/01 13:57:49  karin
Changed logging. Removed package for find, use sub instead. Improved logging and file names.

Revision 1.1  2013/08/01 11:28:02  karin
New script

