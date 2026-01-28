#!/bin/bash
unikernels=("lib-nginx" "lib-dhcp" "lib-dns" "lib-ftp" "lib-weborf" "lib-haproxy" "lib-iperf3" "lib-scamper-uradargun" "lib-scamper-utnt" "lib-scamper-uspeedtrap" "lib-helloworld" "lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-zlib-perf" "lib-mandelbrot-perf" "lib-matrix-perf" "lib-lambda-perf" "lib-sqlite-perf" "lib-sqlite")

PASSWORD="TODEFINE"
unikraft="/$HOME/unikraft"
firecracker_bin=${1:-"firecracker_madvise_release"}
uk_type=${2:-"normal"}
use_aslr=${3:-"0"}
nb_instances=${4:-1}
iteration=${5:-1}
suffix_aslr=""
ksm="ksm" #ksm

if [ "$use_aslr" == "1" ]; then
  suffix_aslr="_aslr"
fi

workdir_results="$PWD/results_tlb_flush/results_${iteration}/${firecracker_bin}_${uk_type}${suffix_aslr}"
logfile="${workdir_results}/output.log"
errfile="${workdir_results}/err.log"
datafile_trace="${workdir_results}/trace.dat"

sleep_ksm=60

run_sudo_cmd(){
    echo "$PASSWORD" | sudo -S date > "/dev/null"
}


ksm_quiet_mode(){
    # echo 10 -> 20
    # echo 1000 -> 100
    run_sudo_cmd && echo 20 | sudo tee /sys/kernel/mm/ksm/sleep_millisecs
    run_sudo_cmd && echo 100 | sudo tee /sys/kernel/mm/ksm/pages_to_scan
    run_sudo_cmd && echo 256 | sudo tee /sys/kernel/mm/ksm/max_page_sharing
    run_sudo_cmd && echo 0 | sudo tee /sys/kernel/mm/ksm/use_zero_pages
}

init(){
  run_sudo_cmd
  free && sync
  sudo sh -c "/bin/echo 3 > /proc/sys/vm/drop_caches" && sudo swapoff -a && sudo swapon -a
  free
  #rm -rf "${workdir_results}" 2> /dev/null
  mkdir -p "${workdir_results}"

  
  run_sudo_cmd && echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
  if [ "$firecracker_bin" == "firecracker_madvise_release" ]; then
      ksm_quiet_mode
      run_sudo_cmd && echo 1 | sudo tee "/sys/kernel/mm/$ksm/run"
  else
      run_sudo_cmd && echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
  fi


  cd "${workdir_results}"|| exit 1
  echo "" > "$logfile"
  echo "" 2> "$errfile"
  rm "$datafile_trace" 2> /dev/null
}

run_benchmark(){
  current=$PWD
  array=()
  sudo trace-cmd record -p function -l flush_tlb_all -l flush_tlb_one_user -l flush_tlb_mm_range -l flush_tlb_kernel_range -l flush_tlb_one_kernel -l flush_tlb_local &
  sleep 3

  for i in $(seq 1 $nb_instances); do
    echo "iteration $i:"
    for uk in "${unikernels[@]}"; do

      if [ "$uk_type" == "size" ]; then
        #echo "running $unikraft/apps_size/$uk ..."
        cd "$unikraft/apps_size/$uk" || exit 1
      else
        #echo "running $unikraft/apps/$uk ..."
        cd "$unikraft/apps/$uk" || exit 1
      fi
      echo "$uk" >> "$errfile"

      if [ "$uk_type" == "local_align" ] || [ "$uk_type" == "spacer-slt" ] || [ "$uk_type" == "spacer" ]; then
        ${firecracker_bin} --no-api --config-file "uk_config_local_align${suffix_aslr}.json" 2>> "$errfile" > "/dev/null" &
      else
        firecracker_bin="firecracker_madvise_release"
        ${firecracker_bin} --no-api --config-file "uk_config${suffix_aslr}.json" 2>> "$errfile" > "/dev/null" &
      fi
      pid=$!
      array+=("${pid}")

      sleep 0.1
    done
  done

  ps -aux | grep -c "$firecracker_bin"

  ps -aux | grep "firecracker" > "$current/ps.txt"
  echo "${array[@]}" >> "$current/ps.txt"

  sleep "$sleep_ksm"

  run_sudo_cmd
  sudo kill -2 $(pidof trace-cmd)
  killall "${firecracker_bin}"
  
  sleep 10
  echo "$current"
  sudo chown -R $USER "$current/trace.dat"
  cd "$current" || exit 1

  ksmd=$(trace-cmd report|grep "ksm"|wc -l)
  vcpu=$(trace-cmd report|grep "vcpu"|wc -l)
  fire=$(trace-cmd report|grep "fire"|wc -l)
  echo "$ksmd;$vcpu;$fire" > "$logfile"
}

init
run_benchmark
run_sudo_cmd && echo 0 | sudo tee "/sys/kernel/mm/$ksm/run"
