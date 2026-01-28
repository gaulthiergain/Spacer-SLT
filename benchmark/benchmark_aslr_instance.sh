#!/bin/bash

unikraft="$HOME/unikraft"
firecracker_bin=${1:-"firecracker_madvise"}
uk_type=${2:-"default"}
uk_original=${3:-"lib-haproxy-full"}
nb_instances=${4:-"1000"}
use_sleep=${5:-0}
use_perf=${6:-"0"}
uk_copy=${uk_original#*-}
PASSWORD="TO_DEFINE"
sleep_ksm=60

suffix_sleep=""
if [ ! "$use_sleep" == 0 ]; then
  suffix_sleep="_${use_sleep}sec"
fi

pool_dir="$HOME/dev/firecracker/pool_aslr"
shm_dir="/dev/shm"

ksm="ksm" #ksm
helper_path="$HOME/unikraft/aligner/helpers"
aslr_path="$PWD/aslr_instances_${uk_copy}"
logfile="output.log"
perffile="perf.log"
loggerfile="logger.log"
#var_folder="/var/tmp/${uk_copy}${nb_instances}"

function swap()         
{
    local TMPFILE=tmp.$$
    mv "$1" $TMPFILE && mv "$2" "$1" && mv $TMPFILE "$2"
}

die() {
    echo "Error: $1."
    exit 1
}

run_sudo_cmd(){
    echo "$PASSWORD" | sudo -S date > "/dev/null"
}

copy_shm() {
    cd "${pool_dir}" || die "Failed to cd to pool dir" 
    for f in .*; do cp -- "$f" "${shm_dir}/aslr_lib$f" 2> "/dev/null"; done
    cp "${pool_dir}/.uk_lib_arg__lib_param" "${shm_dir}/aslr_libuk_lib_arg__lib_param" 2> "/dev/null"
    cp "${pool_dir}/uk_lib_arg__lib_param" "${shm_dir}/aslr_libuk_lib_arg__lib_param" 2> "/dev/null"
}


subinit(){

    echo "init"
    workdir_results="/home/gain/unikraft/results/results_instances/${nb_instances}_${uk_original}${suffix_sleep}/${firecracker_bin}_${uk_type}_aslr"
    logfile="${workdir_results}/output.log"
    perffile="${workdir_results}/perf.log"
    loggerfile="${workdir_results}/logger.log"
    datafilerollups="${workdir_results}/data_rollups_${firecracker_bin}.csv"
    datafile_cpu_usage="${workdir_results}/cpu_usage_${firecracker_bin}.csv"
    data_swap_usage="${workdir_results}/swap_usage_${firecracker_bin}.csv"

    run_sudo_cmd;
    free && sync
    sudo sh -c "/bin/echo 3 > /proc/sys/vm/drop_caches" && sudo swapoff -a && sudo swapon -a
    free

    if [ "$firecracker_bin" == "firecracker" ]; then
        echo 1 | sudo tee "/sys/kernel/mm/$ksm/run"
        cd "$helper_path" || exit 1
        sudo rm -rf "${pool_dir}" ; mkdir "${pool_dir}"
        sudo rm /dev/shm/aslr_lib.* 2> /dev/null
        python3 lib_extractor.py --uk "$aslr_path/unikernel_kvmfc-x86_64_aslr_local_align1" &> /dev/null || die "Failed to extract uk"
        copy_shm "$aslr_path/unikernel_kvmfc-x86_64_aslr_local_align1"
	    sudo rm -rf "${pool_dir}"
    fi

    mkdir -p "${workdir_results}"
    echo "date,value " > "$datafilerollups"
    echo "time;cpu_usage(uksmd);vm_total_size;total_cpu_time" > "${datafile_cpu_usage}"
    echo "time;swap_used" > "${data_swap_usage}"

    echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
    if [ "$firecracker_bin" == "firecracker_madvise" ]; then
        echo 1 | sudo tee "/sys/kernel/mm/$ksm/run"
    fi

    cd "${workdir_results}"|| exit 1
    echo "" > "$logfile" "$loggerfile"
    if [ "$use_perf" == 1 ]; then
        echo "" > "$perffile"
    fi
    kill -9 "$(pidof ${firecracker_bin})" 2> "/dev/null"

    sudo nice -n 20 watch -n 1 "smap_rollup_parser -n ${firecracker_bin} -d ${datafilerollups}" &> "/dev/null"  &
}

run_benchmark(){

    firecracker_bin=${1:-"firecracker"}
    uk_type=${2:-"normal"}

    subinit

    suffix_uktype="normal"
    if [ "$uk_type" == "size" ]; then
        suffix_uktype="size"
    elif [ "$uk_type" == "spacer" ]; then
        suffix_uktype="local_align"
    fi
    
    cd "${aslr_path}" || exit 1
    for i in $(seq 1 $nb_instances); do
        ${firecracker_bin} --no-api --config-file "${aslr_path}/uk_config_${suffix_uktype}_aslr${i}.json" &> /dev/null &
    done    

    sleep 1
    pgrep firecracker|wc -l

    sleep "$sleep_ksm"
    while [ ! "$(pgrep firecracker| wc -l)" -eq 0 ]; do 
        sleep 1; 
        echo "wait $(pgrep firecracker| wc -l)"
    done

    if [ "$use_perf" == 1 ]; then
        for i in $(seq 1 $nb_instances); do
            cat "/tmp/remove_result$i" >> "$perffile"
            rm "/tmp/remove_result$i"
        done
    fi

    run_sudo_cmd
    sudo kill -9 "$(pgrep -f smap_rollup_parser)"
    sudo killall watch
    killall "${firecracker_bin}" &> "/dev/null"
    taskset -c 31 killall "${firecracker_bin}" &> "/dev/null"
}

run_benchmark "${firecracker_bin}" "${uk_type}"