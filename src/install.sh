#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ./resources/config.sh
. ./resources/colors.sh

# removes the cd img from the /etc/apt/sources.list file (not needed after base install)
sed -i '/cdrom:/d' /etc/apt/sources.list

#Update to latest packages
verbose "Update installed packages"
apt-get update && apt-get upgrade -y

#Add dependencies
apt-get install -y wget
apt-get install -y lsb-release
apt-get install -y systemd
apt-get install -y systemd-sysv
apt-get install -y ca-certificates
apt-get install -y dialog
apt-get install -y nano
apt-get install -y net-tools
apt-get install -y gpg
apt-get install -y git
apt-get install -y curl
apt-get install -y build-essential
apt-get install -y autoconf
apt-get install -y automake
apt-get install -y libtool
apt-get install -y pkg-config
apt-get install -y libssl-dev
apt-get install -y zlib1g-dev
apt-get install -y libcurl4-openssl-dev

#SNMP
apt-get install -y snmpd
echo "rocommunity public" > /etc/snmp/snmpd.conf
service snmpd restart


#IPTables
resources/iptables.sh

#sngrep
resources/sngrep.sh

#Fail2ban
resources/fail2ban.sh

#FreeSWITCH
resources/switch.sh

#Drachtio Server
resources/drachtio.sh
