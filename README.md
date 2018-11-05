doh101: DNS-over-HTTPS using OpenResty, from the IETF 101 Hackathon
===================================================================

[OpenResty](https://openresty.org/) is a distribution of NGINX which
includes LuaJIT and a lot of web application support libraries.

This repository contains [Ansible](https://www.ansible.com) roles
that set up an OpenResty server and configures it to support
[DNS-over-TLS (DoT)](https://tools.ietf.org/html/rfc7858) and
[DNS-over-HTTPS (DoH)](https://tools.ietf.org/html/rfc8484).


Components
----------

There are two Ansible roles:

* `basics`: this is to support `doh101` in demo mode; it installs:

    * BIND: This provides the resolver used by the DoH proxy.

    * `dehydrated`: This is an ACME / Let's Encrypt client for
      obtaining a TLS certificate.

	* A default error page for DoH requests that lack a `?dns=`
	  parameter

* `doh101`: the main implementation, intended to be usable in
  (experimental) production; it installs:

    * OpenResty: This provides NGINX with embedded LuaJIT.

    * `doh.lua`: An OpenResty module implementing DNS-over-HTTPS.

The DoH server is running on port 443 at the URI template
`https://your.doh.server.name/{?dns}`

The DoT server is on port 853.


Back-end DNS server
-------------------

The `doh101` role acts as a front-end proxy to a back-end DNS-over-TCP
(Do53) server. It is designed to run on the same host as a recursive
server which has different BIND views on different IP addresses. (For
example, in my production setup I have a main RPZ filtered view and a
raw unfiltered view.)

In order to make the DoT and DoH views consistent with the Do53 views,
the back-end IP address that `doh101` connects to on port 53 is the
same as the front-end IP address that the client connected to on port
443 or 853.

This can be changed in `nginx.conf`:

  * for DoT, replace `$server_addr` in the `proxy_pass` directives;

  * for DoH, replace `$server_addr` in the `set $resolver` directive.


Demo mode setup
---------------

The roles should work on Debian or Ubuntu.

You need to edit `inventory.yml` to change `your.doh.server.name` to
your VM's actual name.

The DNS zone containing your DoH server hostname must support dynamic
DNS updates, for the ACME DNS-01 TLS certificate challenge (see
below). You can create a TSIG key with `./keygen.sh <keyname>` which
you will need to install on your DNS server, or if you have an
existing TSIG key, copy it to
`roles/basics/files/dehydrated-nsupdate.key`.

You might also need to edit `ansible.cfg` if your VM does not allow
root login over `ssh`.


TLS certificates
----------------

The `dehydrated` configuration is in
`roles/basics/files/dehydrated-dns.sh`. You can edit this to use a
different challenge mechanism instead of ACME DNS-01. Please let me
know if you do this!

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


DoH error handling
------------------

`doh101` returns DNS 'not implemented' (RCODE = 4) if the OPCODE is
not 0 (standard query) or if the query type is a meta-type (between
128 and 254 inclusive).

It returns DNS 'format error' (RCODE = 1) if it cannot parse the query
name and type from the DNS request.

It returns an HTTP 400 "bad request" error if it cannot get a bare
minimum DNS request from the HTTP body.

It returns an HTTP 415 "unsupported media type" error if a POST
request does not have Content-Type `application/dns-message`.

There is one special case which allows you to customize the response
that misdirected web browsers will get when they accidentally hit the
DoH endpoint. If the request is GET and there is no `?dns=` URL
parameter, `doh.lua` does an NGINX internal redirect to the named
location `@doh_no_dns`. The `nginx.conf` is set up to turn this into a
400 error with the response body from the file `doh_no_dns.html`. If
you are using the `doh101` role by itself, you will need to install
your own version of this file.


Cross-origin resource sharing
-----------------------------

In order to allow `doh101` to be used as a service by in-browser
JavaScript apps, it sets CORS headers including
`Access-Control-Allow-Origin: '*'`.

DoH POST requests require a `Content-Type:` header field which is not
permitted for simple requests, so browsers send a preflight OPTIONS
request to check that the POST is permitted. The preflight OPTIONS
response from `doh101` allows the POST request to go ahead.

DoH GET requests count as "simple requests" from the point of view of
CORS, so they do not require any special support on the server.
However, because the query string is usually logged by the web server,
DoH GET requests have somewhat worse privacy properties than POST
requests, which justifies the extra CORS complexity for POST.


Testing
-------

`doh.pl` is a minimal DNS-over-HTTPS client and
`dot.pl` is a minimal DNS-over-TLS client.

Usage:

        ./doh.pl [-k] <DoH URL> <domain> [type [class]]

        ./dot.pl [-k] <DoT server> <domain> [type [class]]

The `-k` option disables certificate validation. You will need
this when the server is using a test certificate.

Examples:

        ./doh.pl -k https://your.doh.server.name/ example.com NS

        ./dot.pl -k your.doh.server.name example.com NS


TODO
----

The `doh.lua` proxy is currently a bare minimum proof of concept. It
uses a short TCP connection to the DNS resolver for each HTTPS request.

It would be much better to use one or more persistent shared TCP
connection(s) to the resolver, and multiplex requests from HTTPS onto
them. Let me know if you are an NGINX / OpenResty expert who would
like to help!


Meta
----

`doh101` was initially created by Tony Finch <dot@dotat.at> <fanf2@cam.ac.uk>
at the IETF 101 Hackathon in London, 17th - 18th March 2018,
and subsequently revised for use at the University of Cambridge.

If you have comments / questions / contributions, send them to me via
email or GitHub.

This repo is available from https://github.com/fanf2/doh101
and https://dotat.at/cgi/git/doh101.git

You may do anything with this. It has no warranty.
<https://creativecommons.org/publicdomain/zero/1.0/>

------------------------------------------------------------------------
