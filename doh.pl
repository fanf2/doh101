#!/usr/bin/perl -s

use warnings;
use strict;

use LWP::UserAgent;
use MIME::Base64 qw(encode_base64url);
use Net::DNS;

our $k; # like curl --insecure

my %lwp;
%lwp = (ssl_opts => {
	verify_hostname => 0,
	SSL_verify_mode => 'SSL_VERIFY_NONE'
    }) if $k;

sub hd {
	my $d = shift;
	printf "%d %s\n", length($d), unpack "H*", $d;
	return $d;
}

my $server = shift;
my $q = new Net::DNS::Packet(@ARGV);
my $dns = encode_base64url hd $q->data;
my $ua = LWP::UserAgent->new(%lwp);
my $hr = $ua->get($server.'?dns='.$dns);
printf "%s\n%s\n", $hr->status_line, $hr->headers_as_string;
if ($hr->is_success) {
	my $hc = hd $hr->content;
	my $r = new Net::DNS::Packet(\$hc);
	$r->print;
} else {
	die $hr->content;
}
