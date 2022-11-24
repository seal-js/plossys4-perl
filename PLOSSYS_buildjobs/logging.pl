use strict;

use Carp;
use Time::HiRes qw(gettimeofday tv_interval);

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
#
# 
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


#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
sub DateTime {
    my %default = (use => 'iso');

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


#-----------------------------------------------------------------------------
# Examples
#-----------------------------------------------------------------------------
my $log = create_logger(debug => 1);
$log->('info', 'Das ist ein INFO Text mit debug=1');
$log->('info', 'Das ist ein weiterer INFO Text mit debug=1');
$log->('debug', 'Das ist ein DEBUG Text mit debug=1');
$log->('error', 'Das ist ein ERROR Text mit debug=1');

$log->('set_debug', 0);
$log->('debug', 'Jetzt ist DEBUG off');
$log->('info', 'Das ist ein INFO Text mit debug=0');

eval {
    $log->('dummy');
};

if ($@) {
    print  "Exception: $@";
}
