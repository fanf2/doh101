#!/usr/bin/perl -s

use warnings;
use strict;

use Data::Hexdumper qw(hexdump);
use IO::Socket::SSL;
use Net::DNS;

our $k; # like curl --insecure
our $p; # persist

my %opt;
%opt = (verify_hostname => 0,
	SSL_verify_mode => SSL_VERIFY_NONE,
    ) if $k;

$opt{PeerHost} = shift;
$opt{PeerPort} = 853;

my $s = IO::Socket::SSL->new(%opt) or die "$SSL_ERROR\n";
my $n = 0;

while (my @q = splice @ARGV, 0, 3) {
	my $q = Net::DNS::Packet->new(@q)->verbose;
	$q->header->rd(1);
	my $qd = pack 'n', length $q->data;
	$qd .= $q->data;
	$s->print($qd);
	$n++;
}

while ($n--) {
	$s->sysread(my $l, 2) == 2
	    or die "could not read response length: $!\n";
	my $len = unpack 'n', $l;
	$s->sysread(my $rd, $len) == $len
	    or die "truncated response\n";
	Net::DNS::Packet->new(\$rd)->verbose;
}

$s->sysread(my $l, 2) == 2
    or die "waited for connection to close: $!\n"
    if $p;

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
