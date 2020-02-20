#!/usr/local/bin/seppperl
#!/usr/local/bin/seppperl -d:ptkdb
# -----------------------------------------------------------------
# $Id: logger.pm,v 1.2 2016/02/05 10:30:03 juergen Exp $
# -----------------------------------------------------------------
package sealperl::logger;
{

use strict;
use vars qw($Utf8Available $VERSION);
$VERSION = '$Revision: 1.2 $';
$VERSION =~ s/\$\w+:\s*([0-9.,]+)\s*\$/$1/;


$Utf8Available = 1;
eval 'use Encode;';
if ($@)
    {
    $Utf8Available = 0;
    }

my $onlyLogger;

sub new
    {
    my $this = shift;
    
    my $class = ref($this) || $this;
    my %tmp = @_;
    unless ($tmp{FILE})
#    unless ($tmp{FILE} && $tmp{FILE} ne "$ENV{PLSLOG}/sealcc.log")
        {
        # allow new logger objects
        if(ref $onlyLogger)
            {
            my $p = __PACKAGE__;
            my $p2 = caller();
            $onlyLogger->Log("new $p called again from package $p2 - same object - log level ignored", "N");
            return $onlyLogger;
            }
        }

    my $self = {
                LEVEL => "I",
                @_,
               };
    die "FILE parameter required" unless(defined $self->{FILE});
    $self->{LEVELNUM} = levelnum($self->{LEVEL});
    unless ( defined ($self->{LEVEL_BOUNDARY_LEFT}) ) { $self->{LEVEL_BOUNDARY_LEFT} = "["; }
    unless ( defined ($self->{LEVEL_BOUNDARY_RIGHT}) ) { $self->{LEVEL_BOUNDARY_RIGHT} = "]"; }
    
    # set default size for logfile to 1 MB or 
    # value of environment variable MAX_LOG_SIZE if > 1 MB
    if (!defined ($self->{MAXSIZE}))
        {
        if ($ENV{MAX_LOG_SIZE} &&($ENV{MAX_LOG_SIZE} > 1024*1024))
            {
            $self->{MAXSIZE} = $ENV{MAX_LOG_SIZE};
            }
        else
            {
            $self->{MAXSIZE} = 1024*1024;
            }
        }
    bless $self, $class;

    eval {require Time::HiRes;};
    if ($@)
        { # oops, we dont have it
        $self->{TimeHires} = 0;
        }
    else
        {
        $self->{TimeHires} = 1;
        }

    my $IsNew = (!-f $self->{FILE});
    if ($Utf8Available)
        {
        if ($IsNew)
            {
            # start a new log file
            unless (defined $self->{UTF8})
                {
                # backward compatibility, use latin1
                $self->{UTF8} = 0;
                }
            }
        else
            {
            # use current encoding of existing log file
            if (open my $fh, "<$self->{FILE}")
                {
                my $firstline = <$fh>;
                close $fh;
                if ($firstline =~ /^\357\273\277/ ) # check for 0xefbbbf UTF-8 BOM
                    {
                    $self->{UTF8} = 1;
                    }
                elsif (defined $self->{UTF8} && $self->{UTF8})
                    {
                    # old log file is latin1, but we have to enforce UTF-8
                    unlink "$self->{FILE}.old";
                    rename ($self->{FILE}, "$self->{FILE}.old");
                    }
                }
            }
        }

    $onlyLogger = $self unless (defined $onlyLogger);
    return $self;
    } # new

sub getLogFileName
    {
    my ($self) = @_;
    return $self->{FILE};
    }

sub clear
    {
    # delete the content of the current file
    my ($self, $user) = @_;
    my $file = $self->getLogFileName();
    unless (-s $file)
        {
        $self->warn("File already empty");
        return 1;
        }
    my $stat = unlink $file;
    if ($stat)
        {
        $self->info("User '$user' deleted file content");
        }
    else
        {
        $self->error("Error deleting file %1: %2", $file, $!);
        }
    return $stat;
    }

sub info
    {
    my ($self, $msg, $caller) = @_;
    return $self->Log($msg, "I", $caller);
    }

sub warn
    {
    my ($self, $msg, $caller) = @_;
    return $self->Log($msg, "W", $caller);
    }

sub fatal
    {
    my ($self, $msg, $caller) = @_;
    return $self->Log($msg, "F", $caller);
    }

sub error
    {
    my ($self, $msg, $caller) = @_;
    return $self->Log($msg, "E", $caller);
    }

sub debug
    {
    my ($self, $msg, $caller) = @_;
    return $self->Log($msg, "D", $caller);
    }

sub trace
    {
    my ($self, $msg, $caller) = @_;
    return $self->Log($msg, "T", $caller);
    }

sub run
    {
    my ($self, $msg, $caller) = @_;
    return $self->Log($msg, "R", $caller);
    }

sub Log
    {
    my ($self, $msg, $level, $caller) = @_;
    $level = "I" if (not defined $level || $level eq "");
    return if (levelnum($level) > $self->{LEVELNUM});
    if ($level eq "X")
        {
        $level = "E";
        }
    my $DateTime;
    unless ($self->{TimeHires})
        {
        # Modul nicht installiert
        my ($sec, $min, $hour, $day, $mon, $year, $wday) = localtime (time); 
        $mon++;
        $year = $year + 1900;

        $DateTime = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d    ",
                                $year, $mon, $day, $hour, $min, $sec);
        }
    else
        {
        my $now_fractions = &Time::HiRes::time();
        my ($sec, $min, $hour, $day, $mon, $year, $wday) = localtime (int $now_fractions); 
        my $msec = sprintf "%.3f", $now_fractions;
        $msec =~ s/\d+\.//g;
        $mon++;
        $year = $year + 1900;

        $DateTime = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d.%03d",
                                $year, $mon, $day, $hour, $min, $sec, $msec);
        }

    my $msg2;
    if (! defined $caller || $caller eq "")
        {
        $msg2 = "$DateTime " . $self->{LEVEL_BOUNDARY_LEFT} . $level . $self->{LEVEL_BOUNDARY_RIGHT} . " $msg\n";
        }
    else
        {
#        $msg2 = "$DateTime [$level] $caller $msg\n";
        $msg2 = "$DateTime " . $self->{LEVEL_BOUNDARY_LEFT} . $level . $self->{LEVEL_BOUNDARY_RIGHT} . " $caller " . "$msg\n";
        }
    
    eval {
        # rename logfile if it gets too big
        my $FileSize;
        my $CurrLogFile = $self->{FILE};
        $FileSize = (stat $CurrLogFile)[7] || 0;
        if ($FileSize >= $self->{MAXSIZE}) 
            {
            unlink "$CurrLogFile.old";
            rename ($CurrLogFile, "$CurrLogFile.old");
            $FileSize = 0; # reset file size to write UTF-8 BOM to new file
            }
        my $stat;
        my $fh;
        if ($Utf8Available && $self->{UTF8})
            {
            eval '$stat = open($fh,">>:utf8", $self->{FILE});';
            if (!$FileSize)
                {
                print $fh "\x{FEFF}" or die $!;
                }
            }
        else
            {
            $stat = open($fh, ">>$self->{FILE}");
            }
        die $! if (!$stat);
        #    binmode $fh; ??? -> no good idea on windows -> make windows log file work with notepad
        print $fh $msg2 or die $!;
        close $fh or die $!;
    };

    if($@) {
        print "writing logfile failed: $@";
        return;
    }
    return $self;
    } # Log

sub setLogLevel
    {
    my ($self, $loglevel) = @_;

    if ($self->{LEVELNUM} != levelnum($loglevel))
        {
        my $num = $self->{LEVELNUM} = levelnum($loglevel);
        $self->{LEVEL} = $loglevel;
        $self->Log("Loglevel set to $loglevel ($num)", "D");
        }
    return $self;
    } # setLogLevel

sub getLogLevel
    {
    my ($self) = @_;

    $self->{LEVEL};
    } # getLogLevel

# logScriptVersion - show version of WU script in job.log
# parameters: $0, '<Dollar>Id<Dollar>'
sub logScriptVersion
    {
    my ($self, $script, $ID) = @_;

    # $ID looks like '<Dollar>Id: createContents.pl,v 1.5 2006/07/08 13:00:15 stefan Exp <Dollar>';
    my @ID = split (/[, ]/, $ID);
    my $version = $ID[3];

    $script =~ s/.*[\\\/]//g;  # remove path

    my $Lang = $ENV{PLS_LANG};
    $Lang = defined $Lang
          ? substr($Lang, 0, 2)
          : "en"
          ;
    my $string = "Working unit script $script has version $version.";
    if ((lc $Lang) eq "de")
        {
        $string = "Working Unit Script $script hat Version $version.";
        }
    $self->Log ($string, "I");
    }

sub levelnum
    {
    my ($level) = @_;

    $level = uc $level;
    return 1 if (($level eq "R") || ($level eq "LOG_RUN"));  # run
    return 2 if (($level eq "F") || ($level eq "LOG_FATAL"));  # fatal
    return 3 if (($level eq "E") || ($level eq "LOG_ERROR"));  # error
    return 4 if (($level eq "W") || ($level eq "LOG_WARN"));  # warnings
    return 5 if (($level eq "I") || ($level eq "LOG_INFO"));  # info
    return 6 if (($level eq "D") || ($level eq "LOG_DEBUG"));  # debug
    return 7 if (($level eq "T") || ($level eq "LOG_TRACE"));  # trace
    return 3 if (($level eq "X") || ($level eq "LOG_ERROR_SET_REASON")); # error and set ERR_REASON to log-message
    return 9 if ($level eq "ALL");
    return 0 if ($level eq "N" || $level eq "OFF" || $level eq "NONE");
    return 5;  # default: info
    } # levelnum

}
1;
=pod

=head1 NAME

 sealperl::logger

=head1 SYNOPSIS

 use sealperl::logger;

 #load logger
 my $log = logger->new(FILE=>"$ENV{PLSLOG}/sealcc.log");

 # set loglevel to an new value
 $log->setLogLevel("LOG_TRACE");

 # write messages
 $log->run("This is my message text");  # write message with run level
 $log->info("This is my message text"); # write message with info level
 $log->warn("This is my message text"); # write message with warn level
 $log->error("This is my message text"); # write message with error level
 $log->debug("This is my message text"); # write message with debug level
 $log->trace("This is my message text"); # write message with trace level


=head1 DESCRIPTION

 This module is used to write log messages within SEAL Control Center.
 Loglevels are given implicitly by log function names (info(), error(), ...)

=head2 FUNCTIONS

=over

=item * new(<Options>)

 This function creates a logger object. If no options are given, the default
 logger object for sealcc.log will be returned (singleton).
 If another log file is given, a new logger object will always be created.
 Valid options are:
 NAME => <Filename>
 MAXSIZE => <Maximum size of the file> (default: 1MB)
 UTF8 => <Flag, if logfile should be UTF-8 encoded> (default: 0)

=item * $log->setLogLevel()
 
 set loglevel to an new value. Every level listed below
 includes all levels listed above it
 Valid levels are:
    N, OFF, NONE: disable logging
    R, LOG_RUN:   only show start and stop messages
    F, LOG_FATAL: show fatal errors
    E, LOG_ERROR: show all errors
    W, LOG_WARN:  show warnings and errors
    I, LOG_INFO:  info level (default)
    D, LOG_DEBUG: show debug messages
    T, LOG_TRACE: show trace messages (maximum)
 
=item * $log->run();  

 write message with run level

=item * $log->info(); 
 
 write message with info level

=item * $log->warn(); 

 write message with warn level

=item * $log->error(); 

 write message with error level

=item * $log->debug(); 

 write message with debug level

=item * $log->trace(); 

 write message with trace level


=head1 AUTHOR

SEAL Systems (c) 2012

=head1 BUGS

none

=head1 SEE ALSO

no links

=cut

__DATA__
