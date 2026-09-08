#!/usr/bin/perl
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use URI;
use URI::Escape qw(uri_unescape);
use Encode qw(decode);
use JSON::PP qw(decode_json encode_json);

# --- Configuration (config.json overrides defaults, env vars override config.json) ---
my $config_file = 'S4D300_DMS.json';
my $config      = {};
if (-f $config_file) {
    open(my $fh, '<', $config_file) or die "Cannot open $config_file: $!\n";
    local $/;
    $config = decode_json(<$fh>);
    close $fh;
}
my $uaa = $config->{uaa} // {};

my $token_url     = ($uaa->{url} ? "$uaa->{url}/oauth/token" : undef);
my $client_id     = $uaa->{clientid};
my $client_secret = $uaa->{clientsecret};
my $api_url       = $config->{uri};
my $grant_type    = 'client_credentials';

# --- CMIS browser request parameters ---
my $repo             = 'ZDMS';
my $browser_segment  = 'browser';
my $root_segment     = 'root';
my $object_id        = 'jwX-FoIMTtfuCEHVnHp1fq7Tz0skT3lj6y-DdSceK78';
my $cmis_selector    = 'content';
my $default_filename = 'download.pdf';

my $ua = LWP::UserAgent->new(timeout => 30);

my $token = get_bearer_token($ua, $token_url, $client_id, $client_secret, $grant_type);
call_api(
    ua              => $ua,
    url             => $api_url,
    token           => $token,
    repo            => $repo,
    browser_segment => $browser_segment,
    root_segment    => $root_segment,
    object_id       => $object_id,
    cmis_selector   => $cmis_selector,
    default_filename => $default_filename,
);

#--------------------------------------------------------------------------
# Requests an access token using the OAuth2 client_credentials grant.
#--------------------------------------------------------------------------
sub get_bearer_token {
    my ($ua, $url, $id, $secret, $grant_type) = @_;

    my $req = HTTP::Request->new(POST => $url);
    $req->content_type('application/x-www-form-urlencoded');
    $req->content(
        join('&',
            'grant_type=' . $grant_type,
            'client_id=' . $id,
            'client_secret=' . $secret,
        )
    );

    my $res = $ua->request($req);
    die "Token request failed: " . $res->status_line . "\n" . $res->decoded_content . "\n"
        unless $res->is_success;

    my $data = decode_json($res->decoded_content);
    die "No access_token in response\n" unless $data->{access_token};

    return $data->{access_token};
}

#--------------------------------------------------------------------------
# Calls a protected API endpoint using the bearer token and saves the returned file.
#--------------------------------------------------------------------------
sub call_api {
    my %args = @_;
    my ($ua, $url, $token, $repo, $browser_segment, $root_segment, $object_id, $cmis_selector, $default_filename)
        = @args{qw(ua url token repo browser_segment root_segment object_id cmis_selector default_filename)};

    my $uri = URI->new($url . $browser_segment . '/' . $repo . '/' . $root_segment);
    $uri->query_form(objectId => $object_id, cmisselector => $cmis_selector);
    print "Requesting: $uri\n";

    my $req = HTTP::Request->new(GET => $uri);
    $req->header(Authorization => "Bearer $token");

    my $res = $ua->request($req);
    die "API request failed: " . $res->status_line . "\n" . $res->decoded_content . "\n"
        unless $res->is_success;

    # Extract filename from Content-Disposition
    my $filename = $default_filename;
    my $cd       = $res->header('Content-Disposition') // '';

    if ($cd =~ /filename\*\s*=\s*([^']*)'[^']*'([^;]+)/) {
        # RFC 5987 form: filename*=<charset>''<percent-encoded name>
        $filename = decode($1 || 'UTF-8', uri_unescape($2));
    }

    open(my $fh, '>:raw', $filename) or die "Cannot write $filename: $!\n";
    print $fh $res->content;
    close $fh;

    print "Saved $filename (" . length($res->content) . " bytes)\n";
}
