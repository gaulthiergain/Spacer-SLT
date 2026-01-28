#!/bin/bash
unikernels=("lib-nginx" "lib-dhcp" "lib-dns" "lib-ftp" "lib-weborf" "lib-haproxy" "lib-iperf3" "lib-scamper-uradargun" "lib-scamper-utnt" "lib-scamper-uspeedtrap" "lib-helloworld" "lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-zlib-perf" "lib-mandelbrot-perf" "lib-matrix-perf" "lib-lambda-perf" "lib-sqlite-perf" "lib-sqlite")

unikraft="$HOME/unikraft"
firecracker_bin=${1:-"firecracker_madvise"}
uk_type=${2:-"normal"}
use_aslr=${3:-"0"}
nb_instances=${4:-1}
suffix_aslr=""
ksm="ksm"

if [ "$use_aslr" == "1" ]; then
  suffix_aslr="_aslr"
fi

workdir_results="$HOME/unikraft/results/results_mem/results_${nb_instances}/${firecracker_bin}_${uk_type}${suffix_aslr}"
logfile="${workdir_results}/output.log"
errfile="${workdir_results}/err.log"
datafilerollups="${workdir_results}/data_rollups_${firecracker_bin}.csv"
datafile_cpu_usage="${workdir_results}/cpu_usage_${firecracker_bin}.csv"

sleep_ksm=30

init(){
  free && sync
  sudo sh -c "/bin/echo 3 > /proc/sys/vm/drop_caches" && sudo swapoff -a && sudo swapon -a
  free

  mkdir -p "${workdir_results}"
  echo "date,value " > "$datafilerollups"
  echo "time;cpu_usage(uksmd);vm_total_size;total_cpu_time" > "${datafile_cpu_usage}"

  echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
  if [ "$firecracker_bin" != "firecracker" ]; then
    echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
  fi

  cd "${workdir_results}"|| exit 1
  echo "" > "$logfile"
  kill -9 "$(pidof ${firecracker_bin})" 2> "$errfile"
}

run_benchmark(){

  index=1
  for _ in "${unikernels[@]}"; do
      tmux new-session -d -s "rtb$index"
      index=$((index + 1))
  done

  watch -n 1 "smap_rollup_parser -n ${firecracker_bin} -d ${datafilerollups}" 2>> "$errfile" >> "$logfile" &

  index=1
  for i in $(seq 1 $nb_instances); do
    for uk in "${unikernels[@]}"; do

      pt="$unikraft/apps/$uk" 
      if [ "$uk_type" == "size" ]; then
        pt="$unikraft/apps_size/$uk"
      fi
      echo "$uk" >> "$errfile"
      
      if [ "$uk_type" != "spacer" ]; then
        firecracker_bin="firecracker_madvise"
        tmux send-keys -t "rtb$index" "${firecracker_bin} --no-api --config-file $pt/uk_config${suffix_aslr}.json" C-m
      else
        tmux send-keys -t "rtb$index" "${firecracker_bin} --no-api --config-file $pt/uk_config_local_align${suffix_aslr}.json" C-m
      fi

      index=$((index + 1))

    done
    #sleep 0.1
  done

  ps -aux | grep -c "$firecracker_bin"

  sleep "$sleep_ksm"

  kill -9 "$(pgrep -f smap_rollup_parser)"
  killall "${firecracker_bin}"
  killall watch
  for i in $(seq 1 "$index"); do
      tmux kill-session -t "rtb$i"
  done
}

init

echo 1 | sudo tee "/sys/kernel/mm/$ksm/run"
echo 100 | sudo tee "/sys/kernel/mm/$ksm/pages_to_scan"
echo 20 | sudo tee "/sys/kernel/mm/$ksm/sleep_millisecs"
echo 0 | sudo tee "/sys/kernel/mm/$ksm/use_zero_pages"

run_benchmark
