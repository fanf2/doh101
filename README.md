doh101: DNS-over-HTTPS using OpenResty, from the IETF 101 Hackathon
===================================================================

[OpenResty](https://openresty.org/) is a distribution of NGINX which
includes LuaJIT and a lot of web application support libraries.

This repository contains an [Ansible](https://www.ansible.com) role
that sets up an OpenResty server and configures it to support
[DNS-over-TLS](https://tools.ietf.org/html/rfc7858) and
[DNS-over-HTTPS](https://tools.ietf.org/html/draft-ietf-doh-dns-over-https).


Preparation
-----------

This role was developed for a Debian 9 "Stretch" VM.

You need to edit `inventory.yml` to change `your.doh.server.name` to
your VM's actual name. Note that you need a colon `:` at the end of
the line.

You can optionally change the `resolver` setting in `inventory.yml` to
use a different DNS server instead of the default Unbound resolver on
the DoH VM.

The DNS zone containing your DoH server hostname must support dynamic
DNS updates, for the ACME DNS-01 TLS certificate challenge. You can
create a TSIG key with `./keygen.sh <keyname>` which you will need to
install on your DNS server, or if you have an existing TSIG key, copy
it to `roles/doh101/files/dehydrated-nsupdate.key`.

You might also need to edit `ansible.cfg` if your VM does not allow
root login over `ssh`.


Installation
------------

Run `ansible-playbook main.yml`

The Ansible playbook installs:

* `unbound`: This provides the default resolver used by the DoH proxy.

* `dehydrated`: This is an ACME / Let's Encrypt client for obtaining a
  TLS certificate.

* `OpenResty`: This provides NGINX with embedded LuaJIT.

* `doh.lua`: An OpenResty module implementing DNS-over-HTTPS.

The DoH server is running on https://your.doh.server.name:443/doh

There is also a DNS-over-TLS server on port 853.


TLS certificates
----------------

The `dehydrated` configuration is in
`roles/doh101/files/dehydrated-dns.sh`. You can edit this to use a
different challenge mechanism instead of ACME DNS-01.

By default the TLS certificate is obtained from the Let's Encrypt
test/staging CA, in order to avoid accidentally using up your
production quotas. Delete the `CA="..."` line to use the production CA
instead of the staging CA.

If you do this, you should delete the contents of
`/var/lib/dehydrated` on the DoH VM; run `dehydrated -c` to create a
new CA account and certificate; and run `service openresty reload` to
use the new certificate.

After creating the production CA account, you should back up
`/var/lib/dehydrated` to avoid accidentally wasting your quota.


Testing
-------

`doh.pl` is a minimal DoH client.

Usage:

        ./doh.pl [-k] <DoH URL> <domain> [type [class]]

The `-k` option disables certificate validation. You will need
this when the server is using a test certificate.

Example:

        ./doh.pl -k https://your.doh.server.name/doh example.com NS


Meta
----

`doh101` was written by Tony Finch <dot@dotat.at> at the IETF 101
Hackathon in London, 17th - 18th March 2018.

If you have comments / questions / contributions, send them to me via
email or GitHub.

This repo is available from https://github.com/fanf2/doh101
and https://dotat.at/cgi/git/doh101.git

------------------------------------------------------------------------
