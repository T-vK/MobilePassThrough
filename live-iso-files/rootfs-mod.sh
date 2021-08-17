#!/usr/bin/env bash

mkdir -p /etc/skel/.config/autostart/
cp /dev/shm/tmp/get-mbpt.sh /etc/skel/
cp /dev/shm/tmp/mbpt.desktop /etc/skel/.config/autostart/
cp /dev/shm/tmp/mbpt.desktop /usr/share/applications/