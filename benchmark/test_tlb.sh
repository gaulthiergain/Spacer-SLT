#!/bin/bash

firecracker_bin=${1:-"firecracker_madvise_release"}
aslr=${2:-"1"}

suffix=""
uk_type=("size" "normal" "spacer" "spacer-slt")

for uk in "${uk_type[@]}"; do
    if [ "$uk" == "spacer-slt" ]; then
        firecracker_bin="firecracker_release"
    fi

    for i in $(seq 1 30); do
	./benchmark_tlb_flush.sh "$firecracker_bin" "$uk" "$aslr" "1" "$i"
    done
done

if [ "$aslr" == "1" ]; then
    suffix="_aslr"
fi

firecracker_bin="firecracker_madvise_release"
for uk in "${uk_type[@]}"; do
    if [ "$uk" == "spacer-slt" ]; then
        firecracker_bin="firecracker_release"
    fi
    echo "Results for $firecracker_bin with unikernel type: $uk"
    echo "----------------------------------------"
    for i in $(seq 1 40); do
        cat "results_tlb_flush/results_${i}/${firecracker_bin}_${uk}${suffix}/output.log"
    done
done
