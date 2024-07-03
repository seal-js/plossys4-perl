use strict;

use Net::SSLeay qw(get_https post_https sslcat make_headers make_form);

use IO::Socket::SSL qw(debug3);

use MIME::Base64;
use Data::Dumper;
 
my $user = 'manager-script';
my $pass = 'seal!Manage1';

my ($page, $result, %headers)                                     # Case 2b
    = get_https('localhost', 9126, '/manager/text/list',
        make_headers(Authorization =>
            'Basic ' . MIME::Base64::encode("$user:$pass",''))
      );
	  

print "Result: [$result]\n";
print '-' x 80 . "\n";
print "Page: " . Data::Dumper->Dump([$page], [qw(page)]);
print '-' x 80 . "\n";
print "Headers: " . Data::Dumper->Dump([\%headers], [qw(Headers)]);