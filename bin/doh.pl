#!/usr/bin/perl

use warnings;
use strict;

use LWP::UserAgent;
use MIME::Base64 qw(encode_base64url);
use Net::DNS;

my $server = shift;
my $q = new Net::DNS::Packet(@ARGV);
my $dns = encode_base64url $q->data;
my $ua = LWP::UserAgent->new();
my $hr = $ua->get($server.'?ct&dns='.$dns);
if ($hr->is_success) {
	my $hc = $hr->content;
	my $r = new Net::DNS::Packet(\$hc);
	$r->print;
} else {
	die $hr->status_line;
}
