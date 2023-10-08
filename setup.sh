#!/bin/bash

# Check if a marker file exists
if [ -f "/docker_completed" ]; then
	

	#docker pull portainer/portainer-ce:latest
	#docker run -d -p 9000:9000 --name portainer --restart always -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce:latest
	
	# Copy configuration files
	echo "copying etc"
	sudo cp -r /mnt/Public/htpc/backup/nginx /etc/
	#sudo cp -r /mnt/Public/htpc/backup/cockpit /etc/
	sudo cp -r /mnt/Public/htpc/backup/webmin /etc/
	echo "copying nextcloud appdata"
	sudo cp -r /mnt/Public/htpc/backup/nextcloud /var/www/html/
	echo "copying compose"
	sudo cp -r /mnt/Public/htpc/compose /home/$USER/
	echo "copying appdata"
	sudo cp -r /mnt/Public/htpc/backup/$USER/.config /home/$USER/
	echo "ownership of appdata"
	sudo chown -R $USER:$USER /home/$USER/.config/appdata
	sudo chmod -R 755 /home/$USER/.config/appdata
	echo "ownership of NC"
	sudo chown -R www-data:www-data /mnt/NC
	echo "ownership of nextcloud appdata"
	sudo chown -R www-data:www-data /var/www/html/nextcloud
	sudo chmod -R 755 /var/www/html/nextcloud
	cd /home/$USER/compose
	sudo docker-compose up -d --build
	(crontab -l 2>/dev/null ; echo "0 6 * * * docker exec -u www-data -it nextcloud ./occ preview:pre-generate") | crontab -
	sudo rm /docker_completed
	sudo touch /setup_completed
	read -n1 -p "Press any key to resume ..."
	echo
	# Reboot the server
	sudo reboot
fi
if [ -f "/setup_completed" ]; then
	# Acme.sh obtain SSL certificates
	docker exec acme.sh --register-account --server zerossl --eab-kid <eab_id> --eab-hmac-key <eab_key>
	docker exec acme.sh --issue --dns dns_dynv6 -d <domain>
	docker exec acme.sh --issue --dns dns_dynv6 -d <nextclouddomain>
	docker exec acme.sh --install-cert -d <domain> --cert-file /certs/<domain>/cert --key-file /certs/<domain>/key --fullchain-file /certs/<domain>/fullchain
	docker exec acme.sh --install-cert -d <nextclouddomain> --cert-file /certs/<nextclouddomain>/cert --key-file /certs/<nextclouddomain>/key --fullchain-file /certs/<nextclouddomain>/fullchain
	
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
	
	
	read -n1 -p "Press any key to resume ..."
	echo
	sudo rm /setup_completed
	sudo rm /etc/rc.local
	exit

fi


sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
echo "Upgrading"
sudo apt -qq update && sudo apt -qq -y upgrade
echo "Installing required packages"
sudo apt -qq -y install apt-transport-https ca-certificates curl software-properties-common wget bzip2
echo "Downloading Guest Addititions"
sudo wget -q https://download.virtualbox.org/virtualbox/7.0.10/VBoxGuestAdditions_7.0.10.iso -O /home/$USER/VBoxGuestAdditions.iso
echo "Installing Guest Addititions"
sudo mkdir /mnt/vb
sudo mount /home/$USER/VBoxGuestAdditions.iso /mnt/vb
sudo /mnt/vb/VBoxLinuxAdditions.run
sudo umount /mnt/vb
sudo rm /home/$USER/VBoxGuestAdditions_7.0.10.iso
sudo adduser $USER vboxsf
sudo rm -r /mnt/vb
sudo mkdir /mnt/Public
sudo mkdir /mnt/NC
sudo mkdir /mnt/ext
sudo sh -c 'printf "\nNC    /mnt/NC    vboxsf    defaults,uid=1000,gid=1000    0    0\n" >> /etc/fstab'
sudo sh -c 'printf "\nPublic    /mnt/Public    vboxsf    defaults,uid=1000,gid=1000    0    0\n" >> /etc/fstab'
sudo sh -c 'printf "\next    /mnt/ext    vboxsf    defaults,uid=1000,gid=1000    0    0\n" >> /etc/fstab'

sudo adduser $USER vboxsf

#webmin
echo "Setup webmin"
curl --insecure -s -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
sudo sh setup-repos.sh -f

# Docker
echo "Setup docker"
distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
curl -fsSL --insecure https://download.docker.com/linux/$distro/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$distro $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt -qq -y update && sudo apt -qq -y upgrade
apt-cache policy docker-ce


# Install packages
echo "Installing packages"
sudo apt install -qq -y git nginx unzip docker-ce webmin samba apt-transport-https ca-certificates apt-show-versions libapt-pkg-perl libauthen-pam-perl libio-pty-perl libnet-ssleay-perl libhtml-parser-perl

# Add user to group
sudo usermod -aG docker ${USER}
sudo usermod -aG sudo ${USER}

# Install Docker Compose
#su - ${USER}
sudo curl --insecure -s -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose

# Start Docker service
#sudo systemctl start docker

# Cockpit
#sudo systemctl enable --now cockpit.socket

#curl --insecure -L -O https://github.com/45Drives/cockpit-benchmark/releases/download/v2.1.0/cockpit-benchmark_2.1.0-2focal_all.deb
#curl --insecure -L -O https://github.com/45Drives/cockpit-navigator/releases/download/v0.5.10/cockpit-navigator_0.5.10-1focal_all.deb
#sudo dpkg -i cockpit-benchmark_2.1.0-2focal_all.deb
#sudo dpkg -i cockpit-navigator_0.5.10-1focal_all.deb
#sudo apt -f -y install
sudo apt -qq clean && sudo apt -qq -y autoremove

#sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
#sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv

sudo touch /docker_completed
read -n1 -p "Press any key to resume ..."
echo
# Reboot the server
sudo reboot

