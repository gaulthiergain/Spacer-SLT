#!/bin/bash
use_aslr=${1:-"0"}
current="$PWD"
suffix_aslr=""

cd "$HOME/unikraft/aligner" || exit 1
rm -f $HOME/dev/firecracker/pool/* &> /dev/null
rm -f /dev/shm/* &> /dev/null
if [ $use_aslr -eq 1 ]; then
    suffix_aslr="_aslr"
    ./runner.sh --use_aslr --extractor &> /dev/null
else
    ./runner.sh --extractor  &> /dev/null
fi
cd "$current" || exit 1
cp /dev/shm/* $HOME/dev/firecracker/pool/

uks=("lib-nginx-perf" "lib-sqlite" "lib-helloworld-minimal")
workdir_results="$HOME/unikraft/results/results_each_lib/"

mkdir -p "$workdir_results"

for uk in "${uks[@]}"; do
    logfile="${workdir_results}/output_${uk}${suffix_aslr}.log"
    echo "" > "$logfile"
    for _ in $(eval echo "{1..30}"); do
        sleep 0.5
        if [ $use_aslr -eq 1 ]; then
            rm -f /dev/shm/aslr_lib.text.* &> /dev/null
        else
            rm -f /dev/shm/lib.text.* &> /dev/null
        fi
        
        if [ "$uk" == "lib-sqlite" ]; then
            echo ".quit"|firecracker_release --no-api --config-file "$HOME/unikraft/apps/${uk}/uk_config_local_align${suffix_aslr}.json" &>> "$logfile"
        else
            firecracker_release --no-api --config-file "$HOME/unikraft/apps/${uk}/uk_config_local_align${suffix_aslr}.json" &>> "$logfile"
        fi
    done
done
