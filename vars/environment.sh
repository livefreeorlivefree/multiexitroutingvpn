#!/bin/bash

BASE="192.168.0"
PING_HOST="bbc.co.uk"
DOWNLOAD_TEST_FILE="https://github.com/livefreeorlivefree/stuff/raw/master/.testfile"
TIMEOUT_VALUE=20 #seconds

SCRIPT_DIR="/sbin/mevr"
CONFIG_DIR="/etc/mevr" #could be etc tho
LOG_DIR="/var/log/mevr" #could be var/log/dudos/ tho


MARK_CONST=1024 #eh.

PERSIST_OPTS="--persist-local-ip"

### prog locations
ifconfig="/sbin/ifconfig"
ip="/sbin/ip"
iptables="/sbin/iptables"
openvpn="/usr/sbin/openvpn"
