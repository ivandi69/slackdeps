#!/bin/bash

./deps2temp.sh \
MINIMAL \
genpower \
vim \
parallel \
perl \
python \
python3 \
tcl \
ruby \
bind \
whois \
dhcp \
dnsmasq \
inetd \
tcp_wrappers \
postfix \
dovecot \
procmail \
fetchmail \
metamail \
mailx \
rpcbind \
nfs-utils \
yptools \
samba \
cifs-utils \
netatalk \
sshfs \
ntp \
net-snmp \
vsftpd \
mariadb \
httpd \
php \
freetype \
harfbuzz \
libICE \
libSM \
libX11 \
libXau \
libXdmcp \
libXext \
libXpm \
libXt \
libxcb \
cups \
ebtables \
nftables \
conntrack-tools \
ipset \
icmpinfo \
tcpdump \
ulogd \
openvpn \
stunnel \
iftop \
powertop \
sysstat \
acct \
lxc \
| grep -v CORE \
| grep -v MINIMAL \
| grep -v NETWORK-SCRIPTS \
| grep -v SLACKPKG \
| sort -u \
> server.template
