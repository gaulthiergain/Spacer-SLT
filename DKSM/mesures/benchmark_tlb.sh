#!/bin/bash
UNIKRAFT="/home/wansart/Projects/DKSM/workspace_emilien"
WORKDIR="${UNIKRAFT}/mesures"
RESULTDIR="${UNIKRAFT}/results/results_tlb"
KSM="ksm"
CPU_CORE=3

firecracker_bin=${1:-"firecracker"}
nb_runs=${2:-10}
use_aslr=${3:-"0"}

suffix_aslr=""

unikernels=("lib-nginx" "lib-dhcp" "lib-dns" "lib-sqlite" "lib-ntp" "lib-ftp" "lib-proxy" "lib-weborf" "lib-iperf3" "lib-scamper-uradargun" "lib-scamper-utnt" "lib-scamper-ubdrmap" "lib-scamper-uspeedtrap" "lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-hanoi-perf" "lib-sqlite-perf" "lib-lambda-perf" "lib-mandelbrot-perf" "lib-matrix-perf")
unikernels_perf=("lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-hanoi-perf" "lib-sqlite-perf" "lib-lambda-perf" "lib-mandelbrot-perf" "lib-matrix-perf")
uk_types=("size" "normal" "spacer")

run_sudo_cmd(){
    sudo -S date > "/dev/null" #hardcode your pass or use a variable
}

init(){
    killall "${firecracker_bin}" 2> /dev/null

    if [ "$use_aslr" == "1" ]; then
        suffix_aslr="_aslr"
    fi

    if [[ $firecracker_bin == "firecracker" ]]; then
        # RUN ONLY SPACER
        uk_types=("spacer")
    fi

    if [[ -d "/sys/kernel/mm/dksm" ]]; then
        KSM="d$KSM"
    fi
    cd "$WORKDIR" || exit
    run_sudo_cmd; ./script_clear_cache.sh
}


run_other_uk(){

    ksm_val="$1"
    uk_type="$2"
    bench_type="$3"
    subfolder="$4"
    errfile="/dev/null" #"${subfolder}/err.log"
    logfile="/dev/null" #"${subfolder}/output.log"

    for uk in "${unikernels[@]}"; do

        path_uk="${UNIKRAFT}/apps/$uk"

        # Run other uks
        if [ "$bench_type" == "same_core" ]; then
            echo "- [INFO] Running $uk on cpu3 (${uk_type})"
            if [ "$uk_type" != "spacer" ]; then
                taskset -c "${CPU_CORE}" ${firecracker_bin} --no-api --config-file "${path_uk}/uk_config${suffix_aslr}.json" 2>> "${errfile}" >> "${logfile}" &
            else
                taskset -c "${CPU_CORE}" ${firecracker_bin} --no-api --config-file "${path_uk}/uk_config_local_align${suffix_aslr}.json" 2>> "${errfile}" >> "${logfile}" &
            fi
        else
            echo "- [INFO] Running $uk on random core {0-4} (${uk_type})"
            if [ "$uk_type" != "spacer" ]; then
                taskset -c "0-4" ${firecracker_bin} --no-api --config-file "${path_uk}/uk_config${suffix_aslr}.json" 2>> "${errfile}" >> "${logfile}" &
            else
                taskset -c "0-4" ${firecracker_bin} --no-api --config-file "${path_uk}/uk_config_local_align${suffix_aslr}.json" 2>> "${errfile}" >> "${logfile}" &
            fi
        fi
        sleep 0.1
    done
}


run_perf_uk(){
    ksm_val="$1"
    uk_type="$2"
    bench_type="$3"
    stats="cache-misses,dTLB-loads,dTLB-load-misses,dTLB-stores,dTLB-store-misses,iTLB-load,iTLB-load-misses,cycles,instructions,alignment-faults,major-faults,minor-faults,faults,user_time,system_time,context-switches"
    for ukperf in "${unikernels_perf[@]}"; do

        # Use temporary folder for results
        subfolder="${RESULTDIR}/${firecracker_bin}/uksm_on_${bench_type}/"
        if [ "$ksm_val" == 0 ]; then
            subfolder="${RESULTDIR}/${firecracker_bin}/uksm_off_${bench_type}/"
        fi

        mkdir -p "${subfolder}"
        result_file="${subfolder}/${ukperf}_${uk_type}${suffix_aslr}"
        rm "${result_file}.txt" 2> /dev/null

        cd "${UNIKRAFT}/apps/$ukperf" || exit 1

        uk_config_file="uk_config_local_align${suffix_aslr}.json"
        if [ "$uk_type" != "spacer" ]; then
            uk_config_file="uk_config${suffix_aslr}.json"
        fi


        
        for i in $(seq 1 ${nb_runs}); do
            run_sudo_cmd;echo 0 | sudo tee "/sys/kernel/mm/"${KSM}"/run";echo 1 | sudo tee "/sys/kernel/mm/"${KSM}"/run"
            if [ ! "$bench_type" == "alone" ]; then
                run_other_uk "$ksm_val" "$uk_type" "$bench_type" "$subfolder"
            fi
            echo "RUN ${i}/${nb_runs}: ${ukperf} (${uk_type})"
            perf stat --cpu 3 -e "$stats" taskset -c 3 "${firecracker_bin}" --no-api --config-file "${uk_config_file}" > "/dev/null" 2>> "${result_file}.txt"
            sleep 1
            killall "${firecracker_bin}" 2> /dev/null
        done

        cd "${WORKDIR}" || exit 1
    done
    
}

run_uk(){

    bench_type="$1"
    errfile="${RESULTDIR}/${firecracker_bin}/err.log"
    
    rm "$errfile" 2> /dev/null
    mkdir -p "${RESULTDIR}/${firecracker_bin}/"
    
    killall "${firecracker_bin}" 2> /dev/null
    run_sudo_cmd; ./script_clear_cache.sh
    echo ""

    ksm_values=(1)

    for ksm_val in "${ksm_values[@]}"; do
        run_sudo_cmd; echo "${ksm_val}" | sudo tee /sys/kernel/mm/"${KSM}"/run
        
        for uk_type in "${uk_types[@]}"; do
            echo $uk_type
            run_perf_uk "$ksm_val" "$uk_type" "$bench_type"
        done
    done

    run_sudo_cmd; echo 0 | sudo tee /sys/kernel/mm/"${KSM}"/run
}

init

#run_uk "alone" #run without background unikernels
#run_uk "same_core" #run with background unikernels on same core
run_uk "different_cores" #run with background unikernels on different cores

killall "${firecracker_bin}" 2> /dev/null

#python3 "scripts_plots/script_perf.py"
