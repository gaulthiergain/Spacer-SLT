#!/bin/bash

curr_folder=$(dirname "$(realpath "$0")")
boot_folder=$curr_folder/boot
mods_folder=$curr_folder/mods

sudo cp mods/lib/modules/5.15.74 /lib/modules -r &&\
sudo sudo cp boot/vmlinuz /boot/vmlinuz-linux-custom &&\
sudo mkinitcpio -p linux-custom &&\
sudo depmod 5.15.74
sudo grub-mkconfig -o /boot/grub/grub.cfg
