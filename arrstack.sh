datadir="/home/$USER/.config"
ARCH=$(dpkg --print-architecture)
app_guid="server"
echo "Installing requirements"
sudo apt -qq update
sudo rm -rf /usr/lib/python3.11/EXTERNALLY-MANAGED
sudo apt install -qq -y curl git sqlite3 python3-dev python3-pip python3-distutils chromium xvfb>/dev/null
for app in sonarr bazarr prowlarr radarr qbittorrent-nox glances tautulli flaresolverr
do
	echo "Instaling $app"
	app_bin=${app^}                # Binary Name of the app
	#sudo chown $app:server /var/log/$app
	case $app in
	flaresolverr)
		app_umask="002"
		app_port="8191"
		wget -nv 'https://github.com/FlareSolverr/FlareSolverr/releases/latest/download/flaresolverr_linux_x64.tar.gz'
		tar -xzf "${app}"*.tar.gz
		installdir="/opt"
		sudo mv "${app}" $installdir
		sudo chown $USER:$USER -R "${installdir}/${app}"
		sudo chmod 775 "${installdir}/${app}"
		rm $app*.tar.gz
		;;
    qbittorrent-nox)
        sudo apt install -qq -y $app>/dev/null
		app_umask="000"
		cmdargs="-d  --webui-port=8112 --configuration=\"$datadir/$app/\""
		installdir="/usr/bin"
        ;;
	tautulli)
		git clone https://github.com/Tautulli/Tautulli.git
		app_umask="002"
		installdir="/opt"
		cmdargs="--config /home/$USER/.config/tautulli/config.ini --datadir /home/$USER/.config/tautulli --quiet --nolaunch"
		sudo mv ${app^} $installdir
		sudo chown $USER:$USER -R "${installdir}/${app^}"
		sudo chmod 775 "${installdir}/${app^}"
		rm -rf ${app^}
		;;
	glances)
        sudo apt install -qq -y $app>/dev/null
		app_umask="000"
		GLANCES_VER=$(glances -V | awk '{print $2}' | tr -cd '[:digit:].' | sed 's/\(.*\)\..$/\1/')
		wget -nv https://github.com/nicolargo/glances/archive/refs/tags/v${GLANCES_VER}.tar.gz
		tar -xzf v${GLANCES_VER}.tar.gz
		sudo cp -r glances-${GLANCES_VER}/glances/outputs/static/public/ /usr/lib/python3/dist-packages/glances/outputs/static/
		rm v${GLANCES_VER}.tar.gz
		rm -rf glances-${GLANCES_VER}
		installdir="/usr/bin"
		cmdargs="-w"
        ;;
    prowlarr)
        app_port="9696"           # Default App Port; Modify config.xml after install if needed
        branch="master"          # {Update me if needed} branch to install
		app_umask="002"
		cmdargs="-nobrowser -data=$datadir/$app/"
		installdir="/opt"              # {Update me if needed} Install Location
		wget --content-disposition -nv 'http://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'
		tar -xzf "${app^}".*.tar.gz
		sudo mv "${app^}" $installdir
		sudo chown $USER:$USER -R "${installdir}/${app^}"
		sudo chmod 775 "${installdir}/${app^}"
		rm -rf "${app^}.*.tar.gz"
		rm "${app^}".*.tar.gz
        ;;
    radarr)
        app_port="7878"           # Default App Port; Modify config.xml after install if needed
		app_umask="002"
        branch="master"           # {Update me if needed} branch to install
		cmdargs="-nobrowser -data=$datadir/$app/"
		installdir="/opt"              # {Update me if needed} Install Location
		wget --content-disposition -nv 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'
		tar -xzf "${app^}".*.tar.gz
		sudo mv "${app^}" $installdir
		sudo chown $USER:$USER -R "${installdir}/${app^}"
		sudo chmod 775 "${installdir}/${app^}"
		rm -rf "${app^}.*.tar.gz"
		rm "${app^}".*.tar.gz
        ;;
	sonarr)
        app_port="8989"           # Default App Port; Modify config.xml after install if needed
		app_umask="002"
        branch="master"           # {Update me if needed} branch to install
		cmdargs="-nobrowser -data=$datadir/$app/"
		installdir="/opt"              # {Update me if needed} Install Location
		wget --content-disposition -nv 'https://services.sonarr.tv/v1/download/develop/latest?version=4&os=linux&arch=x64'
		tar -xzf "${app^}".*.tar.gz
		sudo mv "${app^}" $installdir
		sudo chown $USER:$USER -R "${installdir}/${app^}"
		sudo chmod 775 "${installdir}/${app^}"
		rm -rf "${app^}.*.tar.gz"
		rm "${app^}".*.tar.gz
        ;;
	bazarr)
        app_port="6767"           # Default App Port; Modify config.xml after install if needed
		app_umask="002"
        branch="master"           # {Update me if needed} branch to install
		cmdargs=" -c=$datadir/$app/"
		installdir="/opt"              # {Update me if needed} Install Location
		wget -nv 'https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip'
		sudo mkdir $installdir/$app
		sudo unzip -q $app.zip -d $installdir/$app
		sudo chown $USER:$USER -R "${installdir}/${app}"
		sudo chmod 775 "${installdir}/${app}"
		pip install -r ${installdir}/${app}/requirements.txt
		rm -rf "${app}.zip"
        ;;
	esac
if [ "$app" = "glances" ] || [ "$app" = "qbittorrent-nox" ]; then
	bindir=$installdir/$app
elif [ "$app" = "tautulli" ]; then
    bindir="/usr/bin/python3 $installdir/${app^}/${app^}.py" 
elif [ "$app" = "bazarr" ]; then
    bindir="/usr/bin/python3 $installdir/${app}/${app}.py" 
elif [ "$app" = "flaresolverr" ]; then
	bindir="${installdir}/${app}/${app}"
else
	bindir=${installdir}/${app^}/$app_bin
fi
sudo cat <<EOF | sudo tee /etc/systemd/system/"$app".service >/dev/null
[Unit]
Description=${app^} Daemon
After=syslog.target network.target
[Service]
User=$USER
Group=$USER
UMask=$app_umask
Type=simple
ExecStart=$bindir $cmdargs
TimeoutStopSec=20
KillMode=process
Restart=on-failure
RestartSec=5
StartLimitInterval=90
StartLimitBurst=3
[Install]
WantedBy=multi-user.target
EOF
# Start the App
echo "Service file created. Attempting to start the app"
sudo systemctl -q daemon-reload
sudo systemctl enable --now -q "$app".service
sudo systemctl restart "$app".service

done

#Organizr
echo "Installing organizr"
sudo apt install -qq -y openssl sqlite3 php8.2-mysql php8.2-sqlite3 php8.2-xml php8.2-zip php8.2-curl php8.2-fpm php8.2-zip php8.2-curl php8.2-xml php8.2-xmlrpc
sudo git clone https://github.com/causefx/Organizr /var/www/organizr
sudo chown -R www-data:www-data /var/www/organizr
sudo crontab -u www-data -l 2>/dev/null | { cat; echo "* * * * * php /var/www/organizr/cron.php"; } | sudo crontab -u www-data -
sudo crontab -u www-data -l 2>/dev/null | { cat; echo "* * * * * curl -XGET -sL "https://192.168.0.111/cron.php""; } | sudo crontab -u www-data -


#Homepage
echo "Installing homepage"
git clone https://github.com/gethomepage/homepage.git
sudo mv homepage /opt
sudo apt install nodejs npm
sudo chown -R $USER:$USER /opt/homepage 
cd /opt/homepage
npm install
npm run build
sudo npm install pm2 -g
config_file="/opt/homepage/homepage.config.js"

# Check if the config file already exists
if [ -f "$config_file" ]; then
  echo "homepage.config.js already exists."
else
  cat <<EOT >> "$config_file"
  module.exports = {
  apps: [
    {
      name: 'homepage',
      script: 'node',
      args: '/opt/homepage/node_modules/.bin/next start',
      cwd: '/opt/homepage',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
    },
  ],
};
EOT

  echo "homepage.config.js created successfully."
fi
pm2 start homepage.config.js
echo "Follow the instructions"
pm2 startup
echo "Copy configs to /opt/homepage/config"

#Overseerr
git clone https://github.com/sct/overseerr
sudo mv overseerr /opt/
chown -R $USER:$USER /opt/overseerr
cd /opt/overseerr
npm install -g yarn
CYPRESS_INSTALL_BINARY=0 yarn install --frozen-lockfile --network-timeout 1000000
yarn build
yarn install --production --ignore-scripts --prefer-offline
sudo npm install pm2 -g
config_file="/opt/overseerr/overseerr.config.js"

# Check if the config file already exists
if [ -f "$config_file" ]; then
  echo "overseerr.config.js already exists."
else
  cat <<EOT >> "$config_file"
  module.exports = {
  apps: [
    {
      name: 'Overseerr',
      script: 'yarn',
      args: 'start',
      env: {
        NODE_ENV: 'production',
      },
      autorestart: true,
      watch: false,
    },
  ],
};
EOT

  echo "overseerr.config.js created successfully."
fi
pm2 start overseerr.config.js

echo "Copy configs to /opt/overseerr/config"

#Speedtest tracker
sudo apt install -y curl git mariadb-server npm composer php8.2-common php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-opcache php8.2-readline php8.2-xml php8.2-sqlite3 php8.2-zip php8.2-mbstring php8.2-gd php8.2-curl
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt install -y --no-install-recommends speedtest 
git clone https://github.com/alexjustesen/speedtest-tracker
sudo mv speedtest-tracker /var/www
cd /var/www/speedtest-tracker
composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev --no-cache --no-ansi 

npm install
npm run build
sudo service mariadb restart
sudo service php8.2-fpm restart
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
CREATE DATABASE speedtest_tracker;
GRANT ALL ON speedtest_tracker.* TO 'speedtest_tracker'@'localhost' IDENTIFIED BY '1234';
FLUSH PRIVILEGES;
\q
MYSQL_SCRIPT

cp .env.example .env
sudo sed -i 's/DB_USERNAME=.*/DB_USERNAME=speedtest_tracker/' .env
sudo sed -i 's/DB_PASSWORD=.*/DB_PASSWORD=1234/' .env
composer update
/usr/bin/php artisan key:generate
/usr/bin/php artisan migrate --force --no-ansi 
/usr/bin/php artisan optimize:clear --no-ansi 
/usr/bin/php artisan optimize --no-ansi 

sudo find /var/www/speedtest-tracker -type d -exec chmod 755 {} \;
sudo find /var/www/speedtest-tracker -type f -exec chmod 644 {} \;
sudo chown -R www-data:www-data /var/www/speedtest-tracker
sudo cat <<EOF | sudo tee /etc/systemd/system/speedtest-tracker.service >/dev/null
[Unit]
Description=speedtest tracker

[Service]
User=www-data
Group=www-data
ExecStart=/usr/bin/php /var/www/speedtest-tracker/artisan queue:work --daemon
Restart=always
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
echo "Service file created. Attempting to start the app"
sudo systemctl -q daemon-reload
sudo systemctl enable --now -q speedtest-tracker.service
sudo systemctl restart speedtest-tracker.service
