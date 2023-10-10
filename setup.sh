#!/bin/sh
#Is there a better way to do this?
# Function to run a command silently
run_command_silently() {
    "$@" >/dev/null 2>&1
}

# Function to display a message and tick mark
display_message() {
    echo -n "$1"
}

# Function to display a tick mark
display_tick_mark() {
    echo " ✓"
}

# Check if a marker file exists
if [ -f "/docker_completed" ]; then
	

	#docker pull portainer/portainer-ce:latest
	#docker run -d -p 9000:9000 --name portainer --restart always -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce:latest
	
	# Copy configuration files
	display_message "copying etc"
	sudo cp -r /mnt/Public/htpc/backup/nginx /etc/
	#sudo cp -r /mnt/Public/htpc/backup/cockpit /etc/
	sudo cp -r /mnt/Public/htpc/backup/webmin /etc/
	display_tick_mark
	display_message "copying nextcloud appdata"
	sudo cp -r /mnt/Public/htpc/backup/nextcloud /var/www/html/
	display_tick_mark
	display_message	"copying compose"
	sudo cp -r /mnt/Public/htpc/compose /home/$USER/
	sudo chown -R $USER:$USER /home/$USER/compose
	sudo chmod -R 764 /home/$USER/compose
	display_tick_mark
	display_message "copying appdata"
	sudo cp -r /mnt/Public/htpc/backup/$USER/.config /home/$USER/
	display_tick_mark
	display_message "Permissions of appdata"
	sudo chown -R $USER:$USER /home/$USER/.config/appdata
	sudo chmod -R 764 /home/$USER/.config/appdata
	display_tick_mark
	display_message "Permissions of NC"
	run_command_silently sudo chown -R www-data:vboxsf /mnt/NC
	run_command_silently sudo chmod -R 764 /mnt/NC
	
	display_tick_mark
	display_message "ownership of nextcloud appdata"
	sudo chown -R www-data:www-data /var/www/html/nextcloud
	sudo chmod -R 764 /var/www/html/nextcloud
	cd /home/$USER/compose
	sudo docker-compose up -d --build
	(crontab -l 2>/dev/null ; echo "0 6 * * * docker exec -u www-data -it nextcloud ./occ preview:pre-generate") | crontab -
	sudo rm /docker_completed
	sudo touch /setup_completed
	echo "Press any key to restart (Automatically restarting in 10 seconds)..."
	read -r -n 1 -s -t 10
	sudo reboot
fi
if [ -f "/setup_completed" ]; then
	# Acme.sh obtain SSL certificates
	docker exec acme.sh --register-account --server zerossl --eab-kid qmVlA8audAEZX4N-NxrL7w --eab-hmac-key xZ1tV8qHmyxhra4DaTaaw18zqiNgu_Y3XI052ogxWAL2l836P9em4rTK8NglgrMvmgsU5-MKq57OmxtJ6CVcVQ
	docker exec acme.sh --issue --dns dns_dynv6 -d betahome.v6.rocks
	docker exec acme.sh --issue --dns dns_dynv6 -d mynextcloud.v6.rocks
	docker exec acme.sh --install-cert -d betahome.v6.rocks --cert-file /certs/betahome.v6.rocks/cert --key-file /certs/betahome.v6.rocks/key --fullchain-file /certs/betahome.v6.rocks/fullchain
	docker exec acme.sh --install-cert -d mynextcloud.v6.rocks --cert-file /certs/mynextcloud.v6.rocks/cert --key-file /certs/mynextcloud.v6.rocks/key --fullchain-file /certs/mynextcloud.v6.rocks/fullchain
	
	sudo systemctl restart nginx.service
	
	#Preview Generator Nextcloud
	docker exec -u www-data -it nextcloud ./occ config:system:set preview_max_x --value 2048
	docker exec -u www-data -it nextcloud ./occ config:system:set preview_max_y --value 2048
	docker exec -u www-data -it nextcloud ./occ config:system:set jpeg_quality --value 60
	docker exec -u www-data -it nextcloud ./occ config:app:set --value="64 256 1024"  previewgenerator squareSizes
	docker exec -u www-data -it nextcloud ./occ config:app:set --value="64 256 1024" previewgenerator widthSizes
	docker exec -u www-data -it nextcloud ./occ config:app:set --value="64 256 1024" previewgenerator heightSizes
	docker exec -u www-data -it nextcloud ./occ preview:generate-all
	docker exec -u www-data -it nextcloud ./occ memories:index
	docker exec -u www-data -it nextcloud ./occ recognize:download-models
	
	
	echo "Press any key to restart (Automatically restarting in 10 seconds)..."
	read -r -n 1 -s -t 10
	sudo rm /setup_completed
	exit

fi


#sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

display_message "Upgrading"
run_command_silently sudo apt -qq update 
run_command_silently sudo apt -qq -y upgrade
display_tick_mark
display_message "Installing required packages"
run_command_silently sudo apt -qq -y install apt-transport-https ca-certificates curl software-properties-common wget bzip2
display_tick_mark
display_message "Downloading Guest Addititions"
run_command_silently sudo wget -q https://download.virtualbox.org/virtualbox/7.0.10/VBoxGuestAdditions_7.0.10.iso -O /home/$USER/VBoxGuestAdditions.iso
display_tick_mark
display_message "Installing Guest Addititions"
sudo mkdir /mnt/vb
run_command_silently sudo mount /home/$USER/VBoxGuestAdditions.iso /mnt/vb
run_command_silently sudo /mnt/vb/VBoxLinuxAdditions.run
run_command_silently sudo umount /mnt/vb
sudo rm /home/$USER/VBoxGuestAdditions.iso
run_command_silently sudo adduser $USER vboxsf
sudo rm -r /mnt/vb
sudo mkdir -p /mnt/Public
sudo mkdir -p /mnt/NC
sudo mkdir -p /mnt/ext
sudo sh -c 'printf "\nNC    /mnt/NC    vboxsf    defaults,uid=1000,gid=1000    0    0\n" >> /etc/fstab'
sudo sh -c 'printf "\nPublic    /mnt/Public    vboxsf    defaults,uid=1000,gid=1000    0    0\n" >> /etc/fstab'
sudo sh -c 'printf "\next    /mnt/ext    vboxsf    defaults,uid=1000,gid=1000    0    0\n" >> /etc/fstab'

display_tick_mark
#webmin
display_message "Setup webmin"
run_command_silently curl --insecure -s -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
run_command_silently sudo sh setup-repos.sh -f
display_tick_mark
# Docker
display_message "Setup docker"
distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
run_command_silently curl -fsSL --insecure https://download.docker.com/linux/$distro/gpg -o docker-gpg.key
sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg docker-gpg.key
rm docker-gpg.key
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$distro $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
run_command_silently sudo apt -qq -y update
run_command_silently sudo apt -qq -y upgrade
run_command_silently apt-cache policy docker-ce
display_tick_mark

# Install packages
display_message "Installing packages"
run_command_silently sudo apt -qq -y install git nginx unzip docker-ce webmin samba apt-transport-https ca-certificates apt-show-versions libapt-pkg-perl libauthen-pam-perl libio-pty-perl libnet-ssleay-perl libhtml-parser-perl

display_message "Installing modules for webmin"
run_command_silently wget -q https://www.justindhoffman.com/sites/justindhoffman.com/files/nginx-0.10.wbm_.gz -O /home/$USER/nginx.wbm.gz
sudo /usr/share/webmin/install-module.pl /home/$USER/nginx.wbm.gz
sudo rm /home/$USER/nginx.wbm.gz
display_tick_mark

# Add user to group
sudo usermod -aG docker ${USER}
sudo usermod -aG sudo ${USER}
run_command_silently sudo adduser www-data vboxsf
display_tick_mark
display_message "Installing docker-compose"
# Install Docker Compose
#su - ${USER}
run_command_silently sudo curl --insecure -s -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
display_tick_mark
#display_message "Installing Cockpit"
# Start Docker service
#sudo systemctl start docker

# Cockpit
#sudo systemctl enable --now cockpit.socket

#curl --insecure -L -O https://github.com/45Drives/cockpit-benchmark/releases/download/v2.1.0/cockpit-benchmark_2.1.0-2focal_all.deb
#curl --insecure -L -O https://github.com/45Drives/cockpit-navigator/releases/download/v0.5.10/cockpit-navigator_0.5.10-1focal_all.deb
#sudo dpkg -i cockpit-benchmark_2.1.0-2focal_all.deb
#sudo dpkg -i cockpit-navigator_0.5.10-1focal_all.deb
#sudo apt -f -y install
#display_tick_mark
display_message "Cleaning up"
run_command_silently sudo apt -qq clean 
run_command_silently sudo apt -qq -y autoremove

#sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
#sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv

sudo touch /docker_completed
echo "Press any key to restart (Automatically restarting in 10 seconds)..."
read -r -n 1 -s -t 10
# Reboot the server
sudo reboot

