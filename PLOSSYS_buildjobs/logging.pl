use strict;


#my $debug = 0;

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

    $settings{info}      = sub { my $msg = shift; print "[INFO]  $msg\n" };
    $settings{debug}     = sub { my $msg = shift; print "[DEBUG] $msg\n" if $settings{verbose}; };
    $settings{error}     = sub { my $msg = shift; print "[ERROR] $msg\n" };    
    $settings{set_debug} = sub { my $switch = shift;  $settings{verbose} = $switch; };
    
    return sub {
        my ($sub, $message) = @_;

        $sub = lc $sub;

        if ( exists $settings{$sub} ) { 
            $settings{$sub}->($message);
        }
        return;
    } ;
}

my $log = create_logger(debug => 1);
$log->('info', 'Das ist ein INFO Text');
$log->('info', 'Das ist ein weiterer INFO Text');
$log->('debug', 'Das ist ein DEBUG Text');
$log->('error', 'Das ist ein ERROR Text');

$log->('set_debug', 0);
$log->('debug', 'Jetzt ist DEBUG off');
