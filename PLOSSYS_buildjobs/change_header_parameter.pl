#!/usr/bin/perl

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Encode;
use File::Copy;
use File::Spec;
use FindBin qw($Bin);
use Getopt::Long 'HelpMessage';
use Time::HiRes qw(gettimeofday tv_interval);

require "libhed.pl";  

{
    $Data::Dumper::Sortkeys = 1;
}

$| = 1;

my $log;  # global logger is created in main()

exit main();


#------------------------------------------------------------------------------
# Purpose: Read parameters passed to the current script.
# Parameters: ---
# Return: hash that stores script parameteres
# Global: use global array @ARGV that stores parameters passed to the script
#------------------------------------------------------------------------------
sub getScriptArguments {

    my %scriptArguments;
    
    GetOptions(
        "header=s" => \($scriptArguments{headerfile}),
        "parameter=s"  => \($scriptArguments{parameter}),        
        "debug"    => \($scriptArguments{debug}),
        "help"     => sub { HelpMessage(0) },
    );

    return %scriptArguments;
}

#------------------------------------------------------------------------------
# Purpose: Script entry point. Complete logic to change header parameters.
# GLOBAL parameters: $log
#------------------------------------------------------------------------------
sub main {
    
    my $fct =  (caller(0))[3];

    my %script_arg = getScriptArguments();

    $log = create_logger( debug => $script_arg{debug} );

    $log->('INFO', Data::Dumper->Dump([\%script_arg], [qw(script_arg)]));

    my @files = glob("$script_arg{headerfile}"); # read file pattern

    my @header_params;

    if ( $script_arg{parameter} ) {
       @header_params =
            map { 
               my ($key, $value) = split( /=/, $_); 
               [$key,$value];
            }
           split( /,/, $script_arg{parameter} );

           $log->('DEBUG', "-parameter:\n" . Data::Dumper->Dump([\@header_params], [qw(*header_params)]));
        
    }

    for my $headerfile (@files) {

        $log->('INFO', "$fct : Headerfile [$headerfile]");

        create_backup($headerfile);
        change_header_file(
            headerfile => $headerfile,
            params     => \@header_params
        );
    }

    return 0;
}


#----------------------------------------------------------------------
# Purpose: Create a backup file in the same directory. A timestamp
#          and extension '.bak' is appended to the original filename.
#----------------------------------------------------------------------
sub create_backup {
    my ($file) = @_;

    my $fct =  (caller(0))[3];
    
    if ( ! -e $file ) {
        confess "File $file does not exist!\n";
    }

    my $timestamp = DateTime(use => 'bak');
    my $backup_file = "$file.$timestamp.bak ";

    copy($file, $backup_file) or do {
        confess "Copy $file to $backup_file failed!";
    };

    $log->('INFO', "$fct: Backup file $backup_file created.");
    return 0;
}

#----------------------------------------------------------------------
# Purpose   : Change header parameter in header file.
# Parameters: %arg - 
#             { 
#               headerfile => <path/to/headerfile>,
#               params     => <header parameters (string)>
#             }
#----------------------------------------------------------------------
sub change_header_file {
    my (%arg) = @_;

    my $fct =  (caller(0))[3];
    
    my %header = HedRead($arg{headerfile}, {}, 1); # Read job header file
    my $header_aref = $arg{params};

    $log->('DEBUG', "Original header data:\n" . Data::Dumper->Dump([\%header], [qw(header)]));

    foreach my $item (@$header_aref) {
        $log->('DEBUG',  Data::Dumper->Dump([$item], [qw(item)]));
        if ( $item->[0] && $item->[1] ) {
            $log->('INFO', "Add/Change Key=" . $item->[0] . ', value=' . $item->[1]);
            $header{$item->[0]} = $item->[1];
        }
        else {
            $log->('ERROR', "$fct [ERROR] Invalid parameters will not be added to header file.");
        }

    }

    $log->('DEBUG', "Modified header data:\n" . Data::Dumper->Dump([\%header], [qw(header)]) );

    HedWrite($arg{headerfile}, %header);

    return;
}

#----------------------------------------------------------------------
#----------------------------------------------------------------------
sub DateTime {
    my %default = (use => 'default');

    my %arg = (%default, @_ );

    my ($secs, $msecs) = gettimeofday;
    my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime ($secs); 
   
    # Patch for month (0..11) and year 2000
    $mon++;
    $year = $year + 1900;

    # Format datetime string
    if ( $arg{use} =~ /iso/i ) {
        return sprintf ("%04d-%02d-%02dT%02d:%02d:%02d.%03d", $year, $mon, $day, $hour, $min, $sec, $msecs);
    }
    elsif ( $arg{use} =~ /bak/i ) {
        return sprintf ("%04d%02d%02d_%02d%02d%02d", $year, $mon, $day, $hour, $min, $sec);
    }
}

#-----------------------------------------------------------------
# Purpose: A poor man logger ;-)
#
# SYNOPSIS:
#
# my $log = create_logger(debug => 1);
#
# $log->('info', 'Das ist ein INFO Text');
# $log->('info', 'Das ist ein weiterer INFO Text');
# $log->('debug', 'Das ist ein DEBUG Text');
# $log->('error', 'Das ist ein ERROR Text');
#
# $log->('set_debug', 0);
# $log->('debug', 'Jetzt ist DEBUG off');
#-----------------------------------------------------------------
sub create_logger {
    my (%arg) = @_;
    
    my %settings;

    
    $arg{debug} ||= 0;

    $settings{verbose} = $arg{debug};

    $settings{info} = sub {
         my $msg = shift;

         if ( $settings{verbose} ) {
            print DateTime(use => 'iso') . " [INFO]  $msg\n";
         }
         else {
            print "[INFO]  $msg\n"; 
         }
    };

    $settings{debug} = sub {
        my $msg = shift;
         
        if ( $settings{verbose} ) {
            print DateTime(use => 'iso') . " [DEBUG] $msg\n";
        }
    };

    $settings{error} = sub {
        my $msg = shift; 

        if ( $settings{verbose} ) {
            print DateTime(use => 'iso') . " [ERROR] $msg\n"; 
        }
        else {
            print "[ERROR] $msg\n";
        }
    };    

    $settings{set_debug} = sub { my $switch = shift;  $settings{verbose} = $switch; };
    
    return sub {
        my ($sub, $message) = @_;

        $sub = lc $sub;

        if ( exists $settings{$sub} ) { 
            $settings{$sub}->($message);
        }
        else {
            $sub ||= '';
            confess "First parameter must be a valid function name. Unknown function '$sub' called!";
        }
        return;
    } ;
}


1;

__END__

=head1 NAME

change_header_parameter.pl - Change values of a given header parameter.

=head1 SYNOPSIS

  change_header_parameter.pl  -header <path> -parameter <header_parameters> [-debug] [-help]

  Add new or change header parameters in a given header file.
  You can pass a single header file or a regular expression like job_*.hed.
  After start a backup file of each header file is created (extension '.bak') in the
  same directory. 

  -header      Headerfile path (extension '.hed')
  -parameter   String with key/value pairs representing a header entry
                   "PLS_PLOTTER=PDFOUT"
               Separate multiple entries with comma
                   "PLS_PLOTTER=PDFOUT,PLS_PLOTCOPY=2,PLS_PLOTTYPE=dwg"               
  -help        Print this help
  -debug       Print more messages (switch)

=head1 VERSION

1.0

=cut