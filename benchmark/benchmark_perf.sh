#!/bin/bash
ASLR="_aslr" #_aslr
APPS_DIR="$HOME/unikraft/apps"
RESULTS_DIR="$PWD/perf_diff_core_ksm${ASLR}"
PASSWORD="TODEFINE"
beforewait=1

run_sudo_cmd(){
    echo "$PASSWORD" | sudo -S date > "/dev/null"
}

run_experiment(){
    uk_type="$1"
    uk_perf="$2"
    use_ksm="$3"

    config="uk_config${ASLR}.json"
    fg_bin="firecracker_madvise"
    release="_release"
    ksm=0

    if [[ $use_ksm == "disable" ]]; then
        ksm=0
        run_sudo_cmd && echo 0 | sudo tee /sys/kernel/mm/ksm/run
    else
        ksm=1
        run_sudo_cmd && echo 1 | sudo tee /sys/kernel/mm/ksm/run
        sleep 1
    fi

    if [[ $uk_type == "spacer-slt" ]]; then
        ksm=0
        run_sudo_cmd && echo 0 | sudo tee /sys/kernel/mm/ksm/run
        config="uk_config_local_align${ASLR}.json"
        fg_bin="firecracker"
    else
        fg_bin="firecracker_madvise"
    fi
    
    if [[ $uk_type == "spacer" ]]; then
        config="uk_config_local_align${ASLR}.json"
    fi
    
    if [[ $uk_type == "dce" ]]; then
        APPS_DIR="$HOME/unikraft/apps_size"
        config="uk_config${ASLR}.json"
    else
        APPS_DIR="$HOME/unikraft/apps"
    fi

    echo "$uk_type - $APPS_DIR - $config - $fg_bin - $ksm"

    for ((i=1; i<=30; i++)); do
        echo "" > "/tmp/fclogs.fifo"

        unikernels=("lib-nginx" "lib-dhcp" "lib-dns" "lib-ftp" "lib-weborf" "lib-haproxy" "lib-iperf3" "lib-scamper-uradargun" "lib-scamper-utnt" "lib-scamper-uspeedtrap" "lib-helloworld" "lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-zlib-perf" "lib-mandelbrot-perf" "lib-matrix-perf" "lib-lambda-perf" "lib-sqlite-perf" "lib-sqlite")
        for uk in "${unikernels[@]}"; do
            taskset -c 0-30 "${fg_bin}${release}" --no-api --config-file "${APPS_DIR}/${uk}/${config}" &> /dev/null &
            sleep 0.01
        done
        sleep $beforewait

        taskset -c 31 perf stat -d -e cache-references,cache-misses,cycles,instructions,faults,minor-faults,major-faults,dTLB-load-misses,dTLB-loads,dTLB-store-misses,dTLB-stores,iTLB-load-misses,iTLB-loads ${fg_bin}${release} --boot-timer --no-api --config-file "${APPS_DIR}/${uk_perf}/${config}" --level "Debug" --log-path "/tmp/fclogs.fifo" > /tmp/remove.txt 2>> "${uk_type}${ASLR}.txt" 
        grep "seconds" /tmp/remove.txt >> "${uk_type}${ASLR}.txt"
        echo "$fg_bin --config-file ${APPS_DIR}/${uk_perf}/${config}" >> "${uk_type}${ASLR}_logger.txt"
        cat "/tmp/fclogs.fifo" >> "${uk_type}${ASLR}_logger.txt"

        killall "${fg_bin}${release}" &> "/dev/null" && sleep 2

    done

    sleep 0.5
}   

test(){
    uk_types=("dce" "default" "spacer" "spacer-slt")
    unikernels_perf=("lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-lambda-perf" "lib-mandelbrot-perf" "lib-matrix-perf" "lib-sqlite-perf" "lib-zlib-perf")

    local folder="$1"
    local use_ksm="$2"
    mkdir -p "$folder"

    grep -H '' /sys/kernel/mm/ksm/*

    for uk_type in "${uk_types[@]}"; do
        run_sudo_cmd 
        sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
        for uk_perf in "${unikernels_perf[@]}"; do
            run_experiment "$uk_type" "$uk_perf" "$use_ksm"
        done
    done
    mv *.txt "$folder" && mv "$folder" "${RESULTS_DIR}/"
}

benchmark(){
    rm -rf "$RESULTS_DIR" &> /dev/null
    mkdir -p "$RESULTS_DIR"
    #run_sudo_cmd && echo 100 | sudo tee /sys/kernel/mm/ksm/pages_to_scan
    #run_sudo_cmd && echo 0 | sudo tee /sys/kernel/mm/ksm/run
    #run_sudo_cmd && echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog
    #test "ksm_off" "disable"

    #sleep 1
    run_sudo_cmd && echo 1 | sudo tee /sys/kernel/mm/ksm/run
    run_sudo_cmd && echo 20 | sudo tee /sys/kernel/mm/ksm/sleep_millisecs
    run_sudo_cmd && echo 100 | sudo tee /sys/kernel/mm/ksm/pages_to_scan
    run_sudo_cmd && echo 256 | sudo tee /sys/kernel/mm/ksm/max_page_sharing
    run_sudo_cmd && echo 0 | sudo tee /sys/kernel/mm/ksm/use_zero_pages
    test "ksm_low" ""

    #sleep 1
    #run_sudo_cmd && echo 2 | sudo tee /sys/kernel/mm/ksm/sleep_millisecs
    #run_sudo_cmd && echo 20000 | sudo tee /sys/kernel/mm/ksm/pages_to_scan
    #run_sudo_cmd && echo 256 | sudo tee /sys/kernel/mm/ksm/max_page_sharing
    #run_sudo_cmd && echo 0 | sudo tee /sys/kernel/mm/ksm/use_zero_pages
    #test "ksm_high" ""
    
    run_sudo_cmd && echo 1 | sudo tee /proc/sys/kernel/nmi_watchdog
}

benchmark
