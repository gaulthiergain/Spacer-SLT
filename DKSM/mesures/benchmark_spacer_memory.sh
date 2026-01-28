#!/bin/bash
unikernels=("lib-nginx" "lib-dhcp" "lib-dns" "lib-sqlite" "lib-ntp" "lib-ftp" "lib-proxy" "lib-weborf" "lib-iperf3" "lib-scamper-uradargun" "lib-scamper-utnt" "lib-scamper-ubdrmap" "lib-scamper-uspeedtrap" "lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-hanoi-perf" "lib-sqlite-perf" "lib-mandelbrot-perf" "lib-lambda-perf" "lib-matrix-perf")

unikraft="/home/wansart/Projects/DKSM/workspace_emilien"
firecracker_bin=${1:-"firecracker"}
uk_type=${2:-"spacer"}
#uk_type=${2:-"normal"}
use_ksm=${3:-"0"}
nb_instances=${4:-10}
ksm="ksm"

if [[ -d "/sys/kernel/mm/dksm" ]]; then
  ksm="d$ksm"
fi

output_file="$(dirname "$(realpath "$0")")/mem.csv"
sleep_ksm=20

init(){
  free && sync
  sudo sh -c "/bin/echo 3 > /proc/sys/vm/drop_caches" && sudo swapoff -a && sudo swapon -a && echo never | sudo tee "/sys/kernel/mm/transparent_hugepage/enabled"
  free

  echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
  if [ "$use_ksm" == "1" ]; then
    echo 1 | sudo tee "/sys/kernel/mm/$ksm/run"
  fi

  rm $output_file
}

run_benchmark(){
  for i in $(seq 1 $nb_instances); do

    echo "iteration $i:"
    for uk in "${unikernels[@]}"; do

      echo "running $unikraft/apps/$uk ..."
      cd "$unikraft/apps/$uk" || exit 1

      if [ "$uk_type" == "normal" ]; then
        ${firecracker_bin} --no-api --config-file "uk_config.json" 2>>/dev/null >> /dev/null &
      else
        ${firecracker_bin} --no-api --config-file "uk_config_local_align.json" 2>> /dev/null >> /dev/null &
      fi
    done

    sleep "$sleep_ksm"
    echo -e -n "$i\t" >> $output_file
    smap_rollup_parser -v -n "${firecracker_bin}" | tail -n 1 | awk '{print $2}' >> $output_file
  done

  sleep 1
  killall "${firecracker_bin}"
}

init
run_benchmark
