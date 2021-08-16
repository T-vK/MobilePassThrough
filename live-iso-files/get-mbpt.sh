#!/usr/bin/env bash

echo "Disabling sleep and force keeping the screen on..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
gsettings set org.gnome.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-display-battery 0
gsettings set org.gnome.desktop.session idle-delay 0

printf "%s" "Waiting for an Internet connection ..."
while ! timeout 0.2 ping -c 1 -n github.com &> /dev/null
do
    printf "%c" "."
    sleep 1
done
printf "\n%s\n"  "Connected!"

if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo dnf install -y git
fi

echo "Downloading the MobilePassThrough project..."
sudo mkdir /run/initramfs/live/mbpt
sudo chown liveuser:liveuser /run/initramfs/live/mbpt
cd /run/initramfs/live/mbpt
git clone -b "unattended-win-install" https://github.com/T-vK/MobilePassThrough.git
cd MobilePassThrough
echo "Starting MobilePassThrough in auto mode..."
./mbpt.sh auto
$SHELL
sleep infinity