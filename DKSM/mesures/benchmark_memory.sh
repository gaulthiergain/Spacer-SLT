#!/bin/bash

unikernels=("lib-nginx" "lib-dhcp" "lib-dns" "lib-sqlite" "lib-ntp" "lib-ftp" "lib-proxy" "lib-weborf" "lib-iperf3" "lib-scamper-uradargun" "lib-scamper-utnt" "lib-scamper-ubdrmap" "lib-scamper-uspeedtrap" "lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-hanoi-perf" "lib-sqlite-perf" "lib-mandelbrot-perf" "lib-lambda-perf" "lib-matrix-perf")

unikraft="/home/wansart/Projects/DKSM/workspace_emilien"
firecracker_bin=${1:-"firecracker"}
uk_type=${2:-"normal"}
#uk_type=${2:-"spacer"}
use_aslr=${3:-"0"}
nb_instances=${4:-10}
suffix_aslr=""
ksm="ksm"

if [ "$use_aslr" == "1" ]; then
  suffix_aslr="_aslr"
fi

if [[ -d "/sys/kernel/mm/dksm" ]]; then
  ksm="d$ksm"
fi

workdir_results="/home/wansart/Projects/DKSM/workspace_emilien/results/results_mem/results_${nb_instances}/${firecracker_bin}_${uk_type}${suffix_aslr}"
logfile="${workdir_results}/output.log"
errfile="${workdir_results}/err.log"
datafilerollups="${workdir_results}/data_rollups_${firecracker_bin}.csv"
datafile_cpu_usage="${workdir_results}/cpu_usage_${firecracker_bin}.csv"

sleep_ksm=60

init(){
  free && sync
  sudo sh -c "/bin/echo 3 > /proc/sys/vm/drop_caches" && sudo swapoff -a && sudo swapon -a && echo never | sudo tee "/sys/kernel/mm/transparent_hugepage/enabled"
  free

  mkdir -p "${workdir_results}"
  echo "date,value " > "$datafilerollups"
  echo "time;cpu_usage(uksmd);vm_total_size;total_cpu_time" > "${datafile_cpu_usage}"

  echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
  echo 1 | sudo tee "/sys/kernel/mm/$ksm/run"

  cd "${workdir_results}"|| exit 1
  echo "" > "$logfile"
  kill -9 "$(pidof ${firecracker_bin})" 2> "$errfile"
}

run_benchmark(){
  watch -n 1 "smap_rollup_parser -n ${firecracker_bin} -d ${datafilerollups}" 2>> "$errfile" >> "$logfile" &
  watch -n 0.5 "cpu_monitor -d ${datafile_cpu_usage}" &> "/dev/null" &

  for i in $(seq 1 $nb_instances); do
    echo "iteration $i:"
    for uk in "${unikernels[@]}"; do

      echo "running $unikraft/apps/$uk ..."
      cd "$unikraft/apps/$uk" || exit 1
      echo "$uk" >> "$errfile"

      if [ "$uk_type" == "normal" ]; then
        ${firecracker_bin} --no-api --config-file "uk_config${suffix_aslr}.json" 2>> "$errfile" >> "$logfile" &
      else
        ${firecracker_bin} --no-api --config-file "uk_config_local_align${suffix_aslr}.json" 2>> "$errfile" >> "$logfile" &
      fi
    done
  done

  ps -aux | grep -c "$firecracker_bin"

  sleep "$sleep_ksm"

  kill -9 "$(pgrep -f smap_rollup_parser)"
  killall "${firecracker_bin}"
  killall watch
}

init
run_benchmark