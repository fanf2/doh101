#!/bin/sh
K=roles/doh101/files/dehydrated-nsupdate.key
tsig-keygen "$@" >$K
cat $K
