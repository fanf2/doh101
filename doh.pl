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
	SSL_verify_mode => 0,
    }) if $k;

my $server = shift;
my $q = Net::DNS::Packet->new(@ARGV)->verbose;
$q->header->rd(1);
my $dns = encode_base64url $q->data;
my $ua = LWP::UserAgent->new(%lwp);
my $hr = $ua->get($server.'?dns='.$dns);
printf "%s%s\n%s\n", $hr->request->as_string,
    $hr->status_line, $hr->headers_as_string;
if ($hr->is_success) {
	Net::DNS::Packet->new($hr->content_ref)->verbose;
} else {
	die $hr->content;
}

package Net::DNS::Packet;

use Data::Hexdumper qw(hexdump);

sub verbose {
	my $p = shift;
	my $len = length $p->data;
	printf "  0x%04x = %d\n%s\n", $len, $len,
	    hexdump $p->data, { suppress_warnings => 1 };
	$p->print;
	return $p;
}
