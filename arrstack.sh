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
