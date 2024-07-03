use strict;
use warnings;
use v5.10;

use LWP::UserAgent;
use HTTP::Request::Common;
use LWP::Protocol::https;

use IO::Socket::SSL qw(debug3 );   # enable debug messages printed to STDOUT

#--------------------------------
# THIS DOES NOT WORK!
#use IO::Socket::SSL;
#$IO::Socket::SSL::DEBUG=3;
#--------------------------------
 
my $ua = LWP::UserAgent->new(
            timeout => 20,
			ssl_opts => {
				verify_hostname => 0,
				SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE 
			}
);

my $user = 'manager-script';
my $pass = 'seal!Manage1';
my $realm = 'Tomcat Manager Application';

$ua->credentials("localhost:9126", $realm , $user, $pass);

my $url = 'https://localhost:9126/manager/text/list';


my $response = $ua->get($url);

print '-' x 80 . "\n";
if ($response->is_success) {
    print $response->decoded_content;
}
else {
    print STDERR $response->status_line, "\n";
}

print '-' x 80 . "\n";
say $response->as_string();