#!/bin/sh

# Get script directory from parameter or determine it locally
SCRIPT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

#includes
. "$SCRIPT_DIR/resources/config.sh"
. "$SCRIPT_DIR/resources/colors.sh"

#send a message
verbose "Installing Fail2ban"

#add the dependencies
apt-get install -y fail2ban rsyslog

#move the filters
cp "$SCRIPT_DIR/resources/fail2ban/freeswitch.conf" /etc/fail2ban/filter.d/freeswitch.conf
cp "$SCRIPT_DIR/resources/fail2ban/freeswitch-acl.conf" /etc/fail2ban/filter.d/freeswitch-acl.conf
cp "$SCRIPT_DIR/resources/fail2ban/sip-auth-failure.conf" /etc/fail2ban/filter.d/sip-auth-failure.conf
cp "$SCRIPT_DIR/resources/fail2ban/sip-auth-challenge.conf" /etc/fail2ban/filter.d/sip-auth-challenge.conf
cp "$SCRIPT_DIR/resources/fail2ban/auth-challenge-ip.conf" /etc/fail2ban/filter.d/auth-challenge-ip.conf
cp "$SCRIPT_DIR/resources/fail2ban/freeswitch-ip.conf" /etc/fail2ban/filter.d/freeswitch-ip.conf

cp "$SCRIPT_DIR/resources/fail2ban/jail.local" /etc/fail2ban/jail.local
cp "$SCRIPT_DIR/resources/fail2ban/fail2ban.local" /etc/fail2ban/fail2ban.local


#restart fail2ban
/usr/sbin/service fail2ban restart