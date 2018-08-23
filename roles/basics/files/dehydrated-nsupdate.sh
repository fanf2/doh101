#!/bin/bash

set -e
set -u
set -o pipefail

update() {
        printf '%s _acme-challenge.%s. 3 IN TXT "%s"\nsend\n' "$@" |
		nsupdate -k /etc/dehydrated/nsupdate.key
	sleep 3
}

case "$1" in
"deploy_challenge")
	update add "$2" "$4"
        ;;
"clean_challenge")
	update del "$2" "$4"
        ;;
"deploy_cert")
	service openresty status &&
	service openresty reload
        ;;
"unchanged_cert")
        # do nothing for now
        ;;
"startup_hook")
        # do nothing for now
        ;;
"exit_hook")
        # do nothing for now
        ;;
esac

exit 0
