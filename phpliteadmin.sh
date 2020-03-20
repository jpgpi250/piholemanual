#!/bin/bash

file=phpLiteAdmin_v1-9-8-2.zip
mkdir -p phpLiteAdmin
cd phpLiteAdmin
wget https://bitbucket.org/phpliteadmin/public/downloads/$file
unzip $file

file=phpliteadmin.php
sudo mv /home/pi/phpLiteAdmin/$file /var/www/html/$file
source=phpliteadmin.config.sample.php
target=phpliteadmin.config.php
sudo mv /home/pi/phpLiteAdmin/$source /var/www/html/$target

sudo sed -i "/$directory = '.';/c\$directory = '/etc/pihole';" /var/www/html/$target
sudo sed -i '/$subdirectories = false;/c\$subdirectories = true;' /var/www/html/$target

sudo apt-get -y install php-mbstring
sudo service lighttpd stop
sudo service lighttpd start
