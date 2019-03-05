### Script for turning a Intel Hades Canyon running Ubuntu 18.04.1
### into a kiosk that runs Google Chrome in single KIOSK_URL
 
KIOSK_URL=http://spaceify.net/games/g/showroomducks/screen.html?id=showroomducks

#Setup firewall, allow all outgoing traffic. Accept only incoming ssh

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable

sudo apt-get install -y software-properties-common

sudo add-apt-repository 'deb http://dl.google.com/linux/chrome/deb/ stable main'
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo add-apt-repository -y universe
sudo apt-get update
sudo apt-get install -y --no-install-recommends xorg openbox google-chrome-stable pulseaudio unclutter 


#Update kernel and install graphics drivers

#!/bin/sh
# Update Ubuntu 18.04 to add Vega M (Hades Canyon) graphics support
# Caution: this is a bit risky.  It hasn't bricked anything for me, but then, I play an expert on tv.
# Ideally you'd read this, understand it, and run each step by hand, carefully.
# But it worked first try for me as is.
set -ex
mkdir -p tmp
cd tmp
# New mesa (ca. 18.1.5) and friends
sudo add-apt-repository -y ppa:ubuntu-x-swat/updates
sudo apt dist-upgrade -y       # pulls new mesa from above ppa

# New linux kernel (preview of 4.19)
#wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19-rc2/linux-headers-4.19.0-041900rc2_4.19.0-041900rc2.201809022230_all.deb
#wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19-rc2/linux-headers-4.19.0-041900rc2-generic_4.19.0-041900rc2.201809022230_amd64.deb
#wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19-rc2/linux-image-unsigned-4.19.0-041900rc2-generic_4.19.0-041900rc2.201809022230_amd64.deb
#wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19-rc2/linux-modules-4.19.0-041900rc2-generic_4.19.0-041900rc2.201809022230_amd64.deb


wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.26/linux-headers-4.19.26-041926_4.19.26-041926.201902270533_all.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.26/linux-headers-4.19.26-041926-generic_4.19.26-041926.201902270533_amd64.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.26/linux-image-unsigned-4.19.26-041926-generic_4.19.26-041926.201902270533_amd64.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.26/linux-modules-4.19.26-041926-generic_4.19.26-041926.201902270533_amd64.deb

sudo dpkg -i linux-*.deb
# New linux-firmware (will be released as 1.175 or something like that)
wget -m -np https://people.freedesktop.org/~agd5f/radeon_ucode/vegam/
sudo cp people.freedesktop.org/~agd5f/radeon_ucode/vegam/*.bin /lib/firmware/amdgpu
sudo /usr/sbin/update-initramfs -u -k all
cd ..
rm -rf tmp

# Allow x11 to run as a non-root user

sudo apt-get install -y xserver-xorg-legacy

sudo tee /etc/X11/Xwrapper.config << EOL
allowed_users=anybody
needs_root_rights=yes
EOL

# Make kiosk start upon bootup

sudo useradd --create-home --shell /bin/bash kiosk

#create file /home/kiosk/kioskx11.sh with the following content

sudo tee /home/kiosk/kioskx11.sh << EOL
#!/bin/bash

unclutter -idle 0.001 -root
xset -dpms
xset s off
openbox-session &

while true; do
  rm -rf ~/.{config,cache}/google-chrome/
  google-chrome --kiosk --no-first-run  '$KIOSK_URL'
done
EOL

sudo chown kiosk:kiosk /home/kiosk/kioskx11.sh
sudo chmod u+x /home/kiosk/kioskx11.sh

#create file /home/kiosk/runkiosk.sh with the following content

sudo tee /home/kiosk/runkiosk.sh << EOL
/usr/bin/startx /etc/X11/Xsession ./kioskx11.sh
EOL

sudo chown kiosk:kiosk /home/kiosk/runkiosk.sh
sudo chmod u+x /home/kiosk/runkiosk.sh

#create file /etc/systemd/system/kiosk.service with the following content

sudo tee /etc/systemd/system/kiosk.service << EOL
[Unit]
Description=Kiosk

[Service]
User=kiosk
Group=kiosk
Type=simple
WorkingDirectory=/home/kiosk
Environment=HOME=/home/kiosk

ExecStart=/bin/bash /home/kiosk/runkiosk.sh 
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl enable /etc/systemd/system/kiosk.service

#Enable automatic security updates

sudo apt-get install -y unattended-upgrades

# only append, do not everwrite!

sudo bash -c 'cat >> /etc/apt/apt.conf.d/50unattended-upgrades << EOL
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:38";
EOL'

sudo tee /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists "7";
APT::Periodic::Download-Upgradeable-Packages "7";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "7";
EOL

sudo reboot
