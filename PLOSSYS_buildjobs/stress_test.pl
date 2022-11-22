#!/usr/bin/perl

use strict;
use warnings;

use Encode;
use File::Copy;
use File::Spec;
use FindBin qw($Bin);
use Getopt::Long 'HelpMessage';
use Time::HiRes qw(gettimeofday tv_interval);

$| = 1;

exit main();

#------------------------------------------------------------------------------
# Purpose: Read parameters passed to current script.
# Parameters: ---
# Return: hash that store script parameteres
# Global: use global array @ARGV that stores parameters passed to the script
#------------------------------------------------------------------------------
sub getScriptArguments {
    my %scriptArguments;
    
    GetOptions("users=s" => \($scriptArguments{users}  = "$Bin/plossys-team.txt"),
			   "jobs=s"  => \($scriptArguments{jobs}   = "$Bin/plossys-jobnames.txt"),
               "queue=s" => \($scriptArguments{queues} = "$Bin/plossys-printers.txt"),
               "testfiles=s" => \($scriptArguments{testfiles} = "$Bin/testfiles"),
               "gatedir=s"   => \($scriptArguments{gatedir} = File::Spec->catdir($ENV{PLSIO}, 'stargate')),
               "help"    => sub { HelpMessage(0) },
    );

    return %scriptArguments;
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
sub main {
    my %script_arg = getScriptArguments();

    my $PLSROOT    = $ENV{PLSROOT} || File::Spec->catdir("C:", 'SEAL' , 'Netdome');
    my $plossysCfg = File::Spec->catfile($ENV{PLSROOT}, 'server', 'plotserv', 'plossys.cfg');
    my $testfile   = File::Spec->catfile($ENV{PLSROOT}, 'tools', 'testfiles', 'ps', 'multips.ps');

	my (@usernames, @jobnames, @queuenames, @testfiles);
	my $num_jobs = 3;  # create number of PLOSSYS single jobs
    my $slowdown = 1;  # 0|1  1-> sleep 2 seconds between each job

    # Read configuration files
	readUserNames(\@usernames, $script_arg{users});  
	readJobNames(\@jobnames, $script_arg{jobs});
	readFileIntoArray(\@queuenames, $script_arg{queues});
    readTestFileNames(\@testfiles, $script_arg{testfiles});

#    readQueueNames(\@queuenames, $plossysCfg);

	# Now read largest jobid from table.
    my $jobid = 1;	
	print "Starte bei jobid = $jobid\n";

	my $jobname = "";
	my $jobuser = "";
	my $jobqueue = "";
	my $jobstatus = 0;
	my $jobmessage = "";
	my $jobcount = 1;
	my $jobpagecount = 1;
	
	print "Erzeuge $num_jobs Jobs ...\n";
	my $t0 = [gettimeofday];

	for (my $i=1; $i<=$num_jobs; $i++) {
        # Create random jobs and random queues
		$jobname  = $jobnames[int(rand($#jobnames + 1))];
		$jobuser  = $usernames[int(rand($#usernames + 1))];
		$jobqueue = $queuenames[int(rand($#queuenames + 1))];
		$testfile = $testfiles[int(rand($#testfiles + 1))];

		$jobpagecount = 1;

		if (! ($i % 10)) {
			$jobpagecount = int(rand(200)) || 1;
		}

        # create a job in gateDir
        createJob($jobid, $jobname, $jobuser, $jobqueue, $jobpagecount, $testfile, $script_arg{gatedir});
#        print "$jobid, $jobname, $jobuser, $jobqueue, $jobpagecount, $testfile, $gateDir\n";

        if ($slowdown) {
            # sleep
            sleep 1;
            print "\r$i       ";
            }
        elsif (! ($i % 500)) {
           print "\r$i       ";
        }

		$jobid++;
	}
	print "\n >>> Fertig!\n";

	my $tend = [gettimeofday];
	my $elapsed = tv_interval ($t0, $tend);
	my $jobsPerSecond = $num_jobs / $elapsed;
	print "Dauer: " . sprintf("%.03f", $elapsed) . " Sekunden -> " . int($jobsPerSecond) . " Jobs / Sekunde angelegt.\n";

    return 0;
}

sub readTestFileNames
    {
    my ($ra_testfiles, $dirname) = @_;

    if (-d $dirname)
        {
        opendir my $dir, $dirname or return;
        my @files = readdir $dir;
        closedir $dir;

        foreach my $file (@files)
            {
            next if ($file =~ /^\./);
            next if (! -f "$dirname/$file");
            push @$ra_testfiles, "$dirname/$file";
            }
        }
    }

sub readUserNames {
	my ($ra_usernames, $file) = @_;

	readFileIntoArray($ra_usernames, $file);

	print "Sortiere Namensliste\n";
	@$ra_usernames = sort @$ra_usernames;
}

sub readJobNames {
	my ($ra_jobnames, $file) = @_;

	readFileIntoArray($ra_jobnames, $file);
}

sub readFileIntoArray {
	my ($ra_target, $filename) = @_;

	print "Lese Datei $filename ...";
	my $count = 0;

	if (open my $file, '<', $filename)	{
        my $bAtStart = 1;

        while (<$file>)	{
            if ($bAtStart) {
                if (/^\357\273\277/) # check for 0xefbbbf UTF-8 BOM
                    {
                    $_ = substr $_, 3;  # cut UTF-8 BOM for further regex to find sections correctly
                    }
            }
            
            eval '$_ = decode("UTF-8", $_, Encode::FB_CROAK);';

			if ($_ =~ /^\s*(\S.*\S)\s*$/) {
				my $val = $1;
				$val =~ s/A"/�/g;
				$val =~ s/O"/�/g;
				$val =~ s/U"/�/g;
				$val =~ s/a"/�/g;
				$val =~ s/o"/�/g;
				$val =~ s/u"/�/g;
				$val =~ s/sS/�/g;
				push @$ra_target, $val;
				$count++;
			}
		}
		close $file;
	}
    else {
        print qq|Cannot open file [$filename]\n|;
        return 1;
    }

	print " -> $count Zeilen.\n";
    return 0;
}

sub readQueueNames
    {
    my ($ra_queues, $plossysCfg) = @_;

    print "Lese Queues aus $plossysCfg\n";
	if (open my $file, '<', $plossysCfg)
        {
        my $section;
        my $continue = 0;
        while (<$file>)
            {
            if ( /^\s*\[([^\]]+)\]/ )
                {
                $section = $1;
                }
            if ($section eq "SYSTEM")
                {
                my $val;
                if ( /^\s*PLOTTER_SECTIONS\s*(.*)$/ )
                    {
                    $val = $1;
                    }
                elsif ($continue)
                    {
                    $val = $_;
                    }
                $continue = ($val =~ /\\\s*$/ ) ? 1 : 0;
                $val =~ s/\\\s*$//; # remove backslash if it is there
                my @queues = split " ", $val; 
                push @$ra_queues, @queues;
                }
            }
        close $file;
        }
        else {
            print qq|Cannot open file [$plossysCfg]\n|;
            return 1;
        }

    print "Habe " . scalar @$ra_queues . " Queues gefunden.\n";
    return 0;
    }

#------------------------------------------------------------------------------
# Purpose   :
# Parameters:
#------------------------------------------------------------------------------
sub createJob  {
    my ($jobid, $jobname, $jobuser, $jobqueue, $jobpagecount, $testfile, $gateDir) = @_;

    my $status = 0;
    my $basename = $gateDir . "/" . $$ . "_" . sprintf ("%08d", $jobid);
    my $filename = $testfile;
    $filename =~ s/^.*[\\\/]+//;
  
    my $ext = $testfile;
    $ext =~ s/.*(\.[^\.]+)$/$1/;
    my $hedfile = $basename . ".hed";
    $jobname =~ s/\\/\\\\/g;
    $jobname =~ s/\"/\\"/g;

    # Create PLOSSYS header file 
    if ( open my $hed, ">:utf8", "$hedfile" ) {

        print $hed "\$ SEAL_CODEPAGE == \"UTF-8\"\n";
        print $hed "\$ PLS_SRCNODE   == \"pls_node\"\n";
        print $hed "\$ PLS_USERNAME  == \"$jobuser\"\n";
        print $hed "\$ PLS_PLOTID    == \"$jobname $filename $jobid $$\"\n";
        print $hed "\$ PLS_PLOTTER   == \"$jobqueue\"\n";
        print $hed "\$ PLS_PLOTPAPER == \"BE\"\n";
        print $hed "\$ PLS_PLOTPEN   == \"BE\"\n";
        print $hed "\$ PLS_PLOTCOPY  == \"0\"\n";
        print $hed "\$ PLS_PLOTOPT   == \"/FLAG\"\n";
        print $hed "\$ PLS_DELTYPE   == \"AFT24H\"\n";
        close $hed;

        my $psfile = $basename . $ext;

        # Copy testfile into gate directory
        copy $testfile, $psfile;

        my $rdyfile = $basename . '.rdy';
        $status = create_ready_file($rdyfile);
    }
    else {
        print qq|Cannot open file [$hedfile]\n|;
        return 1;
    }

    return $status;
}

sub create_ready_file {
    my ($file) = @_;

    if (open my $rdy, '>', $file)  {
        close $rdy;
    }
    else {
        print qq|Cannot open file [$file]\n|;
        return 1;
    }
    return 0;
}

1;

__END__

=head1 NAME

stress_test.pl - Create arbitrary PLOSSYS jobs and move them to PLOSSYS inputgate

=head1 SYNOPSIS

  --jobs      File contains arbitrary job names (default ./plossys-jobnames.txt)
  --gatedir   Move new job to this PLOSSYS input directory (default stargate)
  --queues    File contains arbitrary queue names (default ./plossys-printers.txt)
  --testfiles Directory contains testfiles used as PLOSSYS job (default ./testfiles)
  --users     File contains arbitrary user names (default ./plossys-team.txt)
  --help,-h   Print this help

=head1 VERSION

0.01

=cut