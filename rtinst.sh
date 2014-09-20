#!/bin/bash

FULLREL=$(cat /etc/issue.net)
SERVERIP=$(ip a s eth0 | awk '/inet / {print$2}' | cut -d/ -f1)
RELNO=0
WEBPASS=''
PASS1=''
PASS2=''
cronline1="@reboot sleep 3; /usr/local/bin/rtcheck irssi rtorrent"
cronline2="*/10 * * * * /usr/local/bin/rtcheck irssi rtorrent"

if [ "$LOGNAME" = "root" ]
  then
    echo "Cannot run as root. Log into user account and run from there"
    exit
elif [ "$FULLREL" = "Ubuntu 14.04.1 LTS" ]
  then
    RELNO=14
elif [ "$FULLREL" = "Ubuntu 13.10" ]
  then
    RELNO=13
elif [ "$FULLREL" = "Ubuntu 12.04.4 LTS" ]
  then
    RELNO=12
elif [ "$FULLREL" = "Debian GNU/Linux 7" ]
  then
    RELNO=7
else
  echo "Unable to determine OS"
  exit
fi

# get password to be used to access rutorrent
while [ -z "$WEBPASS" ]
    do
   echo "Please enter password for rutorrent "
   stty -echo
   read PASS1
   stty echo
   echo "Please re-enter password "
   stty -echo
   read PASS2
   stty echo
   if [ "$PASS1" = "$PASS2" ]
     then
       WEBPASS="$PASS1"
     else
       echo "Entries do not match please try again"
   fi
  done

# prepare system
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get clean && sudo apt-get autoclean

sudo apt-get -y install autoconf build-essential ca-certificates comerr-dev curl cfv dtach htop irssi libcloog-ppl-dev libcppunit-dev libcurl3 libncurses5-dev libterm-readline-gnu-perl libsigc++-2.0-dev libperl-dev libtool libxml2-dev ncurses-base ncurses-term ntp patch pkg-config php5 php5-cli php5-dev php5-fpm php5-curl php5-geoip php5-mcrypt php5-xmlrpc pkg-config python-scgi screen subversion texinfo unrar-free unzip zlib1g-dev libcurl4-openssl-dev mediainfo

if [ $RELNO = 13 ]
  then
    sudo apt-get -y install php5-json
fi

# install ftp

if [ $RELNO = 12 ]
  then
    sudo apt-get -y install python-software-properties
    sudo add-apt-repository -y ppa:thefrontiergroup/vsftpd
    sudo apt-get update
fi

if [ $RELNO = 7 ]
  then
    echo "deb http://ftp.cyconet.org/debian wheezy-updates main non-free contrib" | sudo tee -a /etc/apt/sources.list.d/wheezy-updates.cyconet2.list > /dev/null
    sudo aptitude update
    sudo aptitude -o Aptitude::Cmdline::ignore-trust-violations=true -y install -t wheezy-updates debian-cyconet-archive-keyring vsftpd
  else
    sudo apt-get -y install vsftpd
fi



sudo perl -pi -e "s/anonymous_enable=YES/anonymous_enable=NO/g" /etc/vsftpd.conf
sudo perl -pi -e "s/#local_enable=YES/local_enable=YES/g" /etc/vsftpd.conf
sudo perl -pi -e "s/#write_enable=YES/write_enable=YES/g" /etc/vsftpd.conf
sudo perl -pi -e "s/#local_umask=022/local_umask=022/g" /etc/vsftpd.conf
sudo perl -pi -e "s/rsa_private_key_file/#rsa_private_key_file/g" /etc/vsftpd.conf
sudo perl -pi -e "s/rsa_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil\.pem/rsa_cert_file=\/etc\/ssl\/private\/vsftpd\.pem/g" /etc/vsftpd.conf

echo "chroot_local_user=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "allow_writeable_chroot=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "ssl_enable=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "allow_anon_ssl=NO" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "force_local_data_ssl=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "force_local_logins_ssl=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "ssl_sslv2=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "ssl_sslv3=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "ssl_tlsv1=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "require_ssl_reuse=NO" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "listen_port=43421" | sudo tee -a /etc/vsftpd.conf > /dev/null
echo "ssl_ciphers=HIGH" | sudo tee -a /etc/vsftpd.conf > /dev/null

sudo openssl req -x509 -nodes -days 365 -subj /CN=$SERVERIP -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem

sudo service vsftpd restart


# install rtorrent
cd ~
mkdir source
cd source
svn co https://svn.code.sf.net/p/xmlrpc-c/code/stable xmlrpc
curl http://libtorrent.rakshasa.no/downloads/libtorrent-0.13.4.tar.gz | tar xz
curl http://libtorrent.rakshasa.no/downloads/rtorrent-0.9.4.tar.gz | tar xz

cd xmlrpc
./configure --prefix=/usr --enable-libxml2-backend --disable-libwww-client --disable-wininet-client --disable-abyss-server --disable-cgi-server
make
sudo make install

cd ../libtorrent-0.13.4
./autogen.sh
./configure --prefix=/usr
make -j2
sudo make install

cd ../rtorrent-0.9.4
./autogen.sh
./configure --prefix=/usr --with-xmlrpc-c
make -j2
sudo make install
sudo ldconfig

cd ~ && mkdir rtorrent && cd rtorrent
mkdir .session downloads watch

cd ~
wget --no-check-certificate https://raw.githubusercontent.com/arakasi72/rtinst/master/.rtorrent.rc
perl -pi -e "s/<user name>/$LOGNAME/g" ~/.rtorrent.rc

# install rutorrent
cd ~
wget --no-check-certificate https://raw.githubusercontent.com/arakasi72/rtinst/master/ru.config
wget --no-check-certificate https://raw.githubusercontent.com/arakasi72/rtinst/master/ru.ini
sudo mkdir /var/www && cd /var/www

sudo mkdir svn
sudo svn checkout http://rutorrent.googlecode.com/svn/trunk/rutorrent
sudo svn checkout http://rutorrent.googlecode.com/svn/trunk/plugins
sudo rm -r rutorrent/plugins
sudo mv plugins rutorrent

sudo chown www-data:www-data /var/www
sudo chown -R www-data:www-data rutorrent
sudo chmod -R 755 rutorrent

sudo rm rutorrent/conf/config.php
sudo mv ~/ru.config /var/www/rutorrent/conf/config.php

cd rutorrent/plugins
sudo mkdir conf
sudo mv ~/ru.ini conf/plugins.ini

if [ $RELNO = 14 ]
  then
    sudo apt-add-repository -y ppa:jon-severinsson/ffmpeg
    sudo apt-get update
fi
sudo apt-get -y install ffmpeg

# install nginx
sudo apt-get -y install nginx-full apache2-utils
sudo htpasswd -c -b /var/www/rutorrent/.htpasswd $LOGNAME $WEBPASS

sudo openssl req -x509 -nodes -days 365 -subj /CN=$SERVERIP -newkey rsa:2048 -keyout /etc/ssl/ruweb.key -out /etc/ssl/ruweb.crt

sudo perl -pi -e "s/user www-data;/user www-data www-data;/g" /etc/nginx/nginx.conf
sudo perl -pi -e "s/worker_processes 4;/worker_processes 1;/g" /etc/nginx/nginx.conf
sudo perl -pi -e "s/pid \/run\/nginx\.pid;/pid \/var\/run\/nginx\.pid;/g" /etc/nginx/nginx.conf
sudo perl -pi -e "s/# server_tokens off;/server_tokens off;/g" /etc/nginx/nginx.conf
sudo perl -pi -e "s/access_log \/var\/log\/nginx\/access\.log;/access_log off;/g" /etc/nginx/nginx.conf
sudo perl -pi -e "s/error\.log;/error\.log crit;/g" /etc/nginx/nginx.conf


if [ $RELNO = 14 ] | [ $RELNO = 13 ]
  then
    sudo cp /usr/share/nginx/html/* /var/www
fi

if [ $RELNO = 12 ] | [ $RELNO = 7 ]
  then
    sudo cp /usr/share/nginx/www/* /var/www
fi

sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.old
cd ~
wget --no-check-certificate https://raw.githubusercontent.com/arakasi72/rtinst/master/nginxsite
sudo mv ~/nginxsite /etc/nginx/sites-available/default
sudo perl -pi -e "s/<Server IP>/$SERVERIP/g" /etc/nginx/sites-available/default

if [ $RELNO = 12 ]
  then
    sudo perl -pi -e "s/fastcgi_pass unix\:\/var\/run\/php5-fpm\.sock/fastcgi_pass 127\.0\.0\.1\:9000/g" /etc/nginx/sites-available/default
fi

sudo service nginx restart && sudo service php5-fpm restart

# install autodl-irssi
sudo apt-get -y install git libarchive-zip-perl libnet-ssleay-perl libhtml-parser-perl libxml-libxml-perl libjson-perl libjson-xs-perl libxml-libxslt-perl libxml-libxml-perl libjson-rpc-perl libarchive-zip-perl
mkdir -p ~/.irssi/scripts/autorun
cd ~/.irssi/scripts
wget --no-check-certificate -O autodl-irssi.zip http://update.autodl-community.com/autodl-irssi-community.zip
unzip -o autodl-irssi.zip
rm autodl-irssi.zip
cp autodl-irssi.pl autorun/
mkdir -p ~/.autodl
touch ~/.autodl/autodl.cfg && touch ~/.autodl/autodl2.cfg

cd /var/www/rutorrent/plugins
sudo git clone https://github.com/autodl-community/autodl-rutorrent.git autodl-irssi
sudo touch autodl-irssi/conf.php

sudo chown -R www-data:www-data autodl-irssi

echo "<?php" | sudo tee -a /var/www/rutorrent/plugins/autodl-irssi/conf.php > /dev/null
echo | sudo tee -a /var/www/rutorrent/plugins/autodl-irssi/conf.php > /dev/null
echo "\$autodlPort = 38800;" | sudo tee -a /var/www/rutorrent/plugins/autodl-irssi/conf.php > /dev/null
echo "\$autodlPassword = \"fab7Rxtpp\";" | sudo tee -a /var/www/rutorrent/plugins/autodl-irssi/conf.php > /dev/null
echo | sudo tee -a /var/www/rutorrent/plugins/autodl-irssi/conf.php > /dev/null
echo "?>" | sudo tee -a /var/www/rutorrent/plugins/autodl-irssi/conf.php > /dev/null

cd ~/.autodl
echo "[options]" | sudo tee -a autodl2.cfg > /dev/null
echo "gui-server-port = 38800" | sudo tee -a autodl2.cfg > /dev/null
echo "gui-server-password = fab7Rxtpp" | sudo tee -a autodl2.cfg > /dev/null

sudo perl -pi -e "s/if \(\\$\.browser\.msie\)/if \(navigator\.appName \=\= \'Microsoft Internet Explorer\' \&\& navigator\.userAgent\.match\(\/msie 6\/i\)\)/g" /var/www/rutorrent/plugins/autodl-irssi/AutodlFilesDownloader.js

# install rtorrent and irssi start, stop, restart script
cd ~
wget --no-check-certificate https://raw.githubusercontent.com/arakasi72/rtinst/master/rt
wget --no-check-certificate https://raw.githubusercontent.com/arakasi72/rtinst/master/rtcheck
sudo mv rt /usr/local/bin/rt
sudo mv rtcheck /usr/local/bin/rtcheck
sudo chmod 755 /usr/local/bin/rt
sudo chmod 755 /usr/local/bin/rtcheck

/usr/local/bin/rt start
/usr/local/bin/rt -i start

(crontab -u $LOGNAME -l; echo "$cronline1" ) | crontab -u $LOGNAME -
(crontab -u $LOGNAME -l; echo "$cronline2" ) | crontab -u $LOGNAME -
echo
echo "crontab entries made. rtorrent and irssi will start on boot for $LOGNAME"
echo
echo "rutorrent can be accessed at https://$SERVERIP/rutorrent"
echo
echo "ftp client should be set to explicit ftp over tls using port  43421"
