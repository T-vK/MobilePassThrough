#!/usr/bin/env bash

echo "Disabling sleep and force keeping the screen on..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
gsettings set org.gnome.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-display-battery 0
gsettings set org.gnome.desktop.session idle-delay 0

printf "%s" "Waiting for a device supporting big files with at least 60Gb of free storage to be mounted ..."
REQUIRED_DISK_SPACE=60 #Gigabytes
MBPT_BASE_PATH=""
while sleep 1; do
    printf "%c" "."
    devices="$(sudo df --output=avail,target -B 1G | sed 's/^ *//')"
    while IFS= read -r deviceLine; do
        availableSpace=$(echo "$deviceLine" | cut -d' ' -f1)
        mountpoint="$(echo "$deviceLine" | cut -d' ' -f2-)"
        if [[ $availableSpace -ge $REQUIRED_DISK_SPACE ]]; then
            if sudo fallocate -l "${REQUIRED_DISK_SPACE}G" "${mountpoint}/size_test.bin"; then
                sudo rm -f "${mountpoint}/_size_test.bin"
                MBPT_BASE_PATH="$(echo "${mountpoint}/mbpt" | tr -s '/')"
                break
            #else
            #    echo "Device mounted at '$mountpoint' doesn't support big files"
            fi
        fi
    done <<< "$devices"
    if [ "$MBPT_BASE_PATH" != "" ]; then
        break
    fi
done
printf "\n%s\n"  "Device found! Files will be stored under: $MBPT_BASE_PATH"
sudo mkdir -p "$MBPT_BASE_PATH"
sudo chown "$(logname):$(id -gn "$(logname)")" "$MBPT_BASE_PATH"
cd "$MBPT_BASE_PATH"

if [ ! -d "${MBPT_BASE_PATH}/MobilePassThrough" ]; then
    printf "%s" "Waiting for an Internet connection ..."
    while ! timeout 5 ping -c 1 -n github.com &> /dev/null; do
        printf "%c" "."
        sleep 1
    done
    printf "\n%s\n"  "Connected!"

    requiredDomains="github.com mirrors.fedoraproject.org fedorapeople.org developer.nvidia.com tb.rg-adguard.net software-download.microsoft.com download.microsoft.com chocolatey.org" # www.techpowerup.com

    for domain in $requiredDomains; do
        printf "%s" "Waiting for $domain to be available ..."
        while ! timeout 5 ping -c 1 -n $domain &> /dev/null; do
            printf "%c" "."
            sleep 1
        done
        printf "\n%s\n"  "$domain is available!"
    done

    if ! command -v git &> /dev/null; then
        echo "Installing git..."
        sudo dnf install -y git
    fi

    echo "Downloading the MobilePassThrough project..."
    git clone -b "unattended-win-install" https://github.com/T-vK/MobilePassThrough.git
    cd MobilePassThrough
    echo "Run MobilePassThrough compatibility check..."
    ./mbpt.sh check
    echo "Starting MobilePassThrough in auto mode..."
    ./mbpt.sh auto
else
    echo "Run MobilePassThrough compatibility check..."
    ./mbpt.sh check
    echo "Starting MobilePassThrough VM..."
    ./mbpt.sh start
fi
$SHELL
sleep infinity