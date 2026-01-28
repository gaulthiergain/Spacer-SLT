#!/bin/bash
unikraft="$HOME/unikraft"

firecracker_bin=${1:-"firecracker_madvise"}
uk_type=${2:-"normal"}
uk=${3:-"lib-go"}
nb_instances=${4:-"128"}
sleep_ksm=30

PASSWORD="TO_DEFINE"
app_folder="apps"
suffix_spacer=""
ksm="ksm"

workdir_results="$HOME/unikraft/results/results_instances/${nb_instances}_${uk}/${firecracker_bin}_${uk_type}"
datafilerollups="${workdir_results}/data_rollups_${firecracker_bin}.csv"

run_sudo_cmd(){
    echo "$PASSWORD" | sudo -S date > "/dev/null"
}

init(){

  echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"

  if [ "$uk_type" == "size" ]; then
    app_folder="apps_size"
  else
    app_folder="apps"
  fi

  if [ "$uk_type" != "spacer" ]; then
      firecracker_bin="firecracker_madvise"
      suffix_spacer=""
  else
      suffix_spacer="_local_align"
  fi

  run_sudo_cmd;
  free && sync
  sudo sh -c "/bin/echo 3 > /proc/sys/vm/drop_caches" && sudo swapoff -a && sudo swapon -a
  free
  
  mkdir -p "${workdir_results}"
  echo "date,value " > "$datafilerollups"
  rm "/dev/shm/"tmp_* "/tmp/info" "/dev/shm/libs" 2> "/dev/null"

  echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
  if [ "$firecracker_bin" == "firecracker_madvise" ]; then
    echo 1 | sudo tee "/sys/kernel/mm/$ksm/run"
  fi
  sleep 1
  
  kill -9 "$(pidof ${firecracker_bin})" &> "/dev/null"
}

run_benchmark_perf(){

  taskset -c 31 sudo nice -n -20 watch -n 1 "smap_rollup_parser -n ${firecracker_bin} -d ${datafilerollups}" &> "/dev/null"  &

  cd "$unikraft/${app_folder}/${uk}" || exit 1

  for _ in $(seq 1 $nb_instances); do
      ${firecracker_bin} --no-api --config-file "uk_config${suffix_spacer}.json" &> "/dev/null" &
  done

  sleep 1
  pgrep firecracker|wc -l

  sleep "$sleep_ksm"
  while [ ! "$(pgrep firecracker| wc -l)" -eq 0 ]; do 
      sleep 1; 
      echo "wait $(pgrep firecracker| wc -l)"
  done
  
  sudo kill -9 "$(pgrep -f smap_rollup_parser)"
  sudo killall watch
  killall "${firecracker_bin}" &> "/dev/null"
  rm "/dev/shm/"tmp_* "/tmp/info" "/dev/shm/libs" 2> "/dev/null"
}

init
run_benchmark_perf
