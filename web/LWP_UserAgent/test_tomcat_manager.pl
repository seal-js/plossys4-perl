use strict;

use Data::Dumper;

use IO::Socket::SSL;
use sealperl::managewebapps;

my $ua = sealperl::managewebapps->new();
$ua->ssl_opts(
				#verify_hostname => 0,
				SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE 
			 );
			 
my @result =  $ua->cmd("list", "localhost", $ua->{ApachePort}, "/manager");


 print Data::Dumper->Dump([\@result], [qw(result)]);

print "END of script\n";
