#!/bin/sh

wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.74.tar.xz
tar -Jxvf linux-5.15.74.tar.xz

curr_folder=$(dirname "$(realpath "$0")")

zcat /proc/config.gz > $curr_folder/linux-5.15.74/.config
cd $curr_folder/linux-5.15.74 &&\
patch -p1 < ../dksm-5.15.74.patch &&\
make olddefconfig
sudo cp $curr_folder/linux-custom.preset /etc/mkinitcpio.d
