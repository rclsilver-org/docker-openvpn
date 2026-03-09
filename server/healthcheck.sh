#!/usr/bin/env bash

set -e

# Check if supervisord is running
supervisorctl status openvpn | grep -q RUNNING

# Check if tun0 interface exists
ip addr show tun0 > /dev/null 2>&1

exit 0
