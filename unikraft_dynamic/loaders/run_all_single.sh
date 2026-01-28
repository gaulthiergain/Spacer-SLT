#!/bin/bash
source "common.sh"

ALL_RESULTS_DIR="$WORKSPACE_DIR/all_results_process"

core=(0 31)
uk_types=("run_loader" "run_custom_loader")

init(){
    rm -rf "$ALL_RESULTS_DIR/dyn" "$ALL_RESULTS_DIR/aslr"
}

run_benchmark(){
    local relro_modes=(0 1)
    local ld_modes=("base" "common" "aggregated")
    for core in "${core[@]}"; do
        for relro in "${relro_modes[@]}"; do
            for ld_mode in "${ld_modes[@]}"; do
                for uk_type in "${uk_types[@]}"; do
                    f="${ALL_RESULTS_DIR}/dyn/${ld_mode}_relro${relro}_core${core}/${uk_type}"
                    mkdir -p "$f"|| die "Failed to create directory $f"
                    for uk in "${UKS[@]}"; do
                        echo "Running $uk_type: $uk (core $core) (relro: $relro) (ld_mode: $ld_mode)"
                        ./run_single.sh --uktype "$uk_type" --app "$uk" --mode "$ld_mode" --relro "$relro" --prepare-only 1 &> /dev/null || die "Failed to prepare benchmark"
                        for _ in {1..30}; do
                            ./run_single.sh --uktype "$uk_type" --app "$uk" --mode "$ld_mode" --relro "$relro" &>> "$f/$uk.log"
                        done
                    done
                done
            done
        done
    done
}

run_benchmark_aslr(){
    local rewrites_mode=(0 1)
    local shuffles_mode=(0 1)
    for core in "${core[@]}"; do
        for rewrite in "${rewrites_mode[@]}"; do
            for shuffle in "${shuffles_mode[@]}"; do
                f="${ALL_RESULTS_DIR}/aslr/core${core}_rewrite${rewrite}_shuffle${shuffle}"
                mkdir -p "$f"|| die "Failed to create directory $f"
                ./run_single.sh --uktype "run_custom_aslr" --app "stubbed" --rewrite "$rewrite" --shuffle "$shuffle" --prepare-only 1 &> /dev/null || die "Failed to prepare benchmark"
                for uk in "${UKS[@]}"; do
                    echo "Running run_custom_aslr: $uk (core $core) (rewrite: $rewrite) (shuffle: $shuffle)"
                    for _ in {1..30}; do
                        ./run_single.sh --uktype "run_custom_aslr" --app "$uk" --rewrite "$rewrite" --shuffle "$shuffle" &>> "$f/$uk.log"
                    done
                done
            done
        done
    done
}

init
run_benchmark
run_benchmark_aslr
