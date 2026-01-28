#!/bin/bash

curr_folder=$(dirname "$(realpath "$0")")
boot_folder=$curr_folder/boot
mods_folder=$curr_folder/mods

mkdir $boot_folder -p
mkdir $mods_folder -p
export INSTALL_PATH=$boot_folder
export INSTALL_MOD_PATH=$mods_folder
cd linux-5.15.74 &&\
make -j$(nproc) &&\
make modules_install -j$(nproc) &&\
make install -j$(nproc)
