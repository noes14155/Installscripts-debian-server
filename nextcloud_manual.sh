#!/bin/bash


# Install MariaDB
sudo apt update
sudo apt install -y mariadb-server
# Secure the installation
sudo mysql_secure_installation <<EOF

y
1234
1234
y
y
y
y
EOF

# Create the Nextcloud database and user
sudo mysql -u root -p1234 <<MYSQL_SCRIPT
CREATE DATABASE nextcloud;
GRANT ALL ON nextcloud.* TO 'nextcloud'@'localhost' IDENTIFIED BY 'polio14155';
FLUSH PRIVILEGES;
\q
MYSQL_SCRIPT

#Install prerequisites
sudo apt install -qq -y unzip wget php8.2 php8.2-common php8.2-fpm php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-bz2 php8.2-intl php8.2-ldap php8.2-imap php8.2-bcmath php8.2-gmp php8.2-imagick
#Install redis and apcu
sudo apt install -qq -y php8.2-apcu redis-server php8.2-redis
#Install support for media
sudo apt install -qq -y ffmpeg exiftool libmagickcore-6.q16-6-extra ghostscript
#Download nextcloud
wget https://download.nextcloud.com/server/releases/latest.zip
sudo unzip -q latest.zip -d /var/www
sudo chown www-data:www-data /var/www/nextcloud -R
rm latest.zip
# Modify php.ini
sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/fpm/php.ini
sudo bash -c "grep -qF 'apc.enable_cli = 1' /etc/php/8.2/cli/php.ini || echo 'apc.enable_cli = 1' >> /etc/php/8.2/cli/php.ini"
# Modify www.conf
sudo sed -i '/^;\?env\[PATH\].*/s/^;//' /etc/php/8.2/fpm/pool.d/www.conf
sudo sed -i '/^;\?env\[TMP\].*/s/^;//' /etc/php/8.2/fpm/pool.d/www.conf
# Restart PHP-FPM service
sudo systemctl restart php8.2-fpm
#Configure imagick
sudo cp /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml.bak
sudo sed -i "s/rights\=\"none\" pattern\=\"PS\"/rights\=\"read\|write\" pattern\=\"PS\"/" /etc/ImageMagick-6/policy.xml
sudo sed -i "s/rights\=\"none\" pattern\=\"EPI\"/rights\=\"read\|write\" pattern\=\"EPI\"/" /etc/ImageMagick-6/policy.xml
sudo sed -i "s/rights\=\"none\" pattern\=\"PDF\"/rights\=\"read\|write\" pattern\=\"PDF\"/" /etc/ImageMagick-6/policy.xml
sudo sed -i "s/rights\=\"none\" pattern\=\"XPS\"/rights\=\"read\|write\" pattern\=\"XPS\"/" /etc/ImageMagick-6/policy.xml
(crontab -l 2>/dev/null ; echo "*/5  *  *  *  * php -f /var/www/nextcloud/cron.php") | crontab -
(crontab -l 2>/dev/null ; echo "*/10 *  *  *  * php /var/www/nextcloud/occ preview:pre-generate") | crontab -
