#!/bin/sh
dehydrated -c | logger --tag dehydrated --priority cron.info
