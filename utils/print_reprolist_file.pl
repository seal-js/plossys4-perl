#!/usr/local/bin/seppperl
#-----------------------------------------------------------------------------
# "@(#) $Id: print_reprolist_file.pl,v 1.2 2019/04/02 08:39:19 juergen Exp $"
#-----------------------------------------------------------------------------
# Copyright (c) by SEAL Systems AG, Lohmuehlweg 4, D-91341 Roettenbach
#-----------------------------------------------------------------------------
#
# Purpose: A little helper module to print key/values of each document
#          stored in a reprolist file in section [REPRO_LIST].
#
# Usage:     print_reprolist.pl -repro <rli file> [<logfile>] [<json>]
#
# If parameter <logfile>does not exist some log messages are written
# in logfile directory $ENV{PLSLOG}\<script_name.log>
#-----------------------------------------------------------------------------
# Revision History
#
# $Log: print_reprolist_file.pl,v $
# Revision 1.2  2019/04/02 08:39:19  juergen
# New feature: use script parameter -key to print specific document values.
# The value of parameter -key is a comma separated string, e.g "Art,Docuent"
#
# Revision 1.1  2019/03/11 15:46:05  juergen
# First commit!
#
#
#-----------------------------------------------------------------------------

use strict;

use Carp;
use Data::Dumper;
use Encode;
use File::Basename;
use Getopt::Long;
use JSON;

require "liblog.pl";
require "librli.pm";

# Define some constant variables.
my ($Revision, $Dummy);
my $SCRIPT = basename($0, '.pl');
my $SCRIPT_VERSION = "Version$Revision: 1.2 $Dummy";

if (scalar @ARGV == 0) {
   PrintUsage()->();
   exit 1;
}
my $args_href = get_script_arguments();
if ( $args_href->{help} ) {
    PrintUsage()->();
    exit 1;
}

exit main($args_href);

# -----------------------------------------------------------------------------
# Subroutines of this module
# -----------------------------------------------------------------------------

#--------------------------------------------------------------------
#--------------------------------------------------------------------
sub main {
    my ($args_href) = @_;

    if (ref($args_href) ne 'HASH') {
        confess 'ERROR! hash reference with script options are missing!';
    }

    # If necessary convert UTF-8 string to latin1, by using the following example
    # function call
    #
    #Encode::from_to($ARGV[0], "UTF-8", "iso-8859-1");

    # Get call parameters and build some paths.
    my $JobFile = $args_href->{reprolist};
    my ($Name, $Path, $Extension) = fileparse($JobFile, '\..*');
    my $RliGate = $Path;
    my $RliFile = $Path.$Name.".rli";
    my $LogFile = $args_href->{logfile} ne "" ? $args_href->{logfile} : $ENV{"PLSLOG"}."/".$SCRIPT.".log";

    # Open log file.
    SetLogFile($LogFile);

    # Start processing.
    Log("Process repro list file \"$JobFile\"...", "I");

    # Create a new repro list object and read the current repro list.
    my $RefRli = librli::new ();
    my $Stat = $RefRli->Read ($RliFile);
    if ($Stat) {
        my $error = "Error reading the repro list \"$RliFile\"";
        print $error . "\n";
        Log($error, "E");
        exit $Stat;
    }

    if ($args_href->{json}) {
        print_reprolist_json($RefRli)
    }
    elsif ($args_href->{key}) {
        print_reprolist_key($RefRli, $args_href->{key})
    }
    else {
        print_reprolist($RefRli);
    }

    Log ("Processing done.", "I");
    return 0;
}


#--------------------------------------------------------------------
# Purpose   : Store script arguments into hash.
# Parameters: -
# Return    : hash reference
#--------------------------------------------------------------------
sub get_script_arguments {
    my %scriptArguments;

    GetOptions("repro=s" => \$scriptArguments{reprolist},
               "log=s"   => \$scriptArguments{logfile},
               "json"    => \$scriptArguments{json},
               "key=s"   => \$scriptArguments{key},
               "help"    => \$scriptArguments{help});
    return \%scriptArguments;
}

#--------------------------------------------------------------------
# Purpose   :
# Parameters:
# Return    :
#--------------------------------------------------------------------
sub print_reprolist_key {
    my ($RefRli, $keys) = @_;

	my @keys = split(/,/, $keys);
    # Get count of documents stored in section [REPRO_LIST].
    my $Count = $RefRli->GetPlotNum ();
    for (my $Index = 0; $Index < $Count; $Index++) {

        # Get plot data stored in section [REPRO_LIST].
        my $Document = {};
        $RefRli->GetPlotInfo ($Index, $Document, 1);
		#my @keys = ($key, 'Art');
		my %data;
        @data{ @keys} = @$Document{ @keys };
		
        print "[$Index]" . Data::Dumper->Dump([\%data], [qw(Document)]);
    }
    return;
}

#--------------------------------------------------------------------
# Purpose   :
# Parameters:
# Return    :
#--------------------------------------------------------------------
sub print_reprolist {
    my ($RefRli) = @_;

    # Get count of documents stored in section [REPRO_LIST].
    my $Count = $RefRli->GetPlotNum ();
    for (my $Index = 0; $Index < $Count; $Index++) {

        # Get plot data stored in section [REPRO_LIST].
        my $Document = {};
        $RefRli->GetPlotInfo ($Index, $Document, 1);
        print "[$Index]" . Data::Dumper->Dump([$Document], [qw(Document)]);
    }
    return;
}


#--------------------------------------------------------------------
# Purpose   :
# Parameters:
# Return    :
#--------------------------------------------------------------------
sub print_reprolist_json {
    my ($RefRli) = @_;

    # Get count of documents stored in section [REPRO_LIST].
    my $Count = $RefRli->GetPlotNum ();
    for (my $Index = 0; $Index < $Count; $Index++) {

        # Get plot data stored in section [REPRO_LIST].
        my $Document = {};
        $RefRli->GetPlotInfo ($Index, $Document, 1);

        my $json = JSON->new;
        my $pretty_printed = $json->pretty->encode($Document);
        print $pretty_printed . "\n";
    }
    return;
}

#
# Print usage message.
#
sub PrintUsage {

    return sub {
        print "-----------------------------------------------------------\n";
        print "$SCRIPT.pl $SCRIPT_VERSION\n";
        print "Copyright (c) by SEAL Systems AG\n\n";
        print "Print documents defined in a reprolist file to STDOUT. \n";
        print "-----------------------------------------------------------\n";
        print "Usage: $SCRIPT.pl -repro <file> [-key, -logfile, -json]\n";
        print "         -repro      The repro list file path.\n";
        print "         -key        Show only this key entries defined in section [REPRO_LIST_FORMAT].\n";
        print "                     Use a comma separated string\n";		
        print "         -logfile    The file to write log messages into.\n";
        print "         -json       Print documents in JSON format.\n";
        print "         -h, -help   Print this usage message\n";
    };
}

1;