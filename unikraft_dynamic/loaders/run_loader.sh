#!/bin/bash
source "common.sh"

prepare_benchmark(){
    local relro="$1"
    local ld_mode="$2"
    compile_loader "$LOADER_DIR" && compile_loader "$CUSTOM_LOADER_DIR"
    rm -rf "$RESULTS_DIR/run_loader" "$RESULTS_DIR/run_custom_loader"
    mkdir -p "$RESULTS_DIR/run_loader" "$RESULTS_DIR/run_custom_loader"
    cd "$SCRIPTS_DIR" || die "Failed to change directory to $SCRIPTS_DIR"
    run_sudo_cmd
    python3 parse_cmd.py --uk "${UKS[@]}" --relro "$relro" --ld_mode "$2"
}

benchmark(){
    local clear_cache="$1"
    local core="$2"
    for uk in "${UKS[@]}"; do
        UK="$WORKSPACE_DIR/apps/$uk/build/unikernel_linuxu-x86_64"

        prepare_loader "$UK"
        readelf -S --wide "${UK}_sym" >> "$TMP_FILE"
        for _ in {1..30}; do
            if [ "$clear_cache" -eq 1 ]; then
                run_sudo_cmd
                sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
            fi
            run_loader "$UK" "$core" &>> "$RESULTS_DIR/run_loader/$uk.log"
        done

        prepare_custom_loader "$UK"
        checksec --file="${UK}.dbg" >> "$TMP_FILE"
        for _ in {1..30}; do
            if [ "$clear_cache" -eq 1 ]; then
                run_sudo_cmd
                sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
            fi
            run_custom_loader "$UK" "$core" &>> "$RESULTS_DIR/run_custom_loader/$uk.log"
        done
    done
}

main_benchmark(){
    echo "" > "$TMP_FILE"
    CLEAR_CACHE=(0 1)
    USE_RELRO=(0 1)
    CORE=(0 31)
    ld_modes=("base" "common" "aggregated")
    for core in "${CORE[@]}"; do
        for cache in "${CLEAR_CACHE[@]}"; do
            for relro in "${USE_RELRO[@]}"; do
                for ld_mode in "${ld_modes[@]}"; do
                    echo "Running linker: $ld_mode (cache $cache) (relro: $relro)" >> "$TMP_FILE"
                    prepare_benchmark "$relro" "$ld_mode"
                    benchmark "$cache" "$core"
                    mv "$RESULTS_DIR" "${ALL_RESULTS_DIR}/${ld_mode}_relro${relro}_clear_cache${cache}_core${core}"
                done
            done
        done
    done
}

aligned_benchmark(){
    CLEAR_CACHE=(0 1)
    CORE=(0 31)
    for core in "${CORE[@]}"; do
        for cache in "${CLEAR_CACHE[@]}"; do

            compile_loader "$LOADER_DIR" && compile_loader "$CUSTOM_LOADER_DIR"
            rm -rf "$RESULTS_DIR/run_loader" "$RESULTS_DIR/run_custom_loader"
            mkdir -p "$RESULTS_DIR/run_loader" "$RESULTS_DIR/run_custom_loader"

            benchmark "$cache" "$core"
            
            mv "$RESULTS_DIR" "${ALL_RESULTS_DIR}/aligned_clear_cache${cache}_core${core}"
        done
    done
}

aslr_benchmark(){

    CLEAR_CACHE=(0 1)
    CORE=(0 31)
    REWRITE=(0 1)
    SHUFFLE=(0 1)

    compile_loader "$CUSTOM_LOADER_ASLR_DIR"
    
    for rewrite in "${REWRITE[@]}"; do
        for shuffle in "${SHUFFLE[@]}"; do
            cd "$SCRIPTS_DIR" || die "Failed to change directory to $SCRIPTS_DIR"
            ./run_aligner.sh 1 "$rewrite" "$shuffle"
            for core in "${CORE[@]}"; do
                for cache in "${CLEAR_CACHE[@]}"; do
                    local dir="${ALL_RESULTS_DIR}/aslr_clear_cache${cache}_core${core}_rewrite${rewrite}_shuffle${shuffle}"
                    mkdir -p "$dir"

                    for uk in "${UKS[@]}"; do
                        UK="$WORKSPACE_DIR/apps/$uk/build/unikernel_linuxu-x86_64"
                        prepare_custom_loader_aslr "$UK"
                        for _ in {1..30}; do
                            if [ "$cache" -eq 1 ]; then
                                run_sudo_cmd
                                sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
                            fi
                            run_custom_loader_aslr "$UK" "$core" &>> "${dir}/$uk.log"
                        done
                    done
                done
            done
        done
    done
}


test(){
    UKS=("apphelloworld-perf" "appsqlite-perf" "appmandelbrot-perf" "applambda-perf" "appnginx-perf")
    for uk in "${UKS[@]}"; do
        UK="$WORKSPACE_DIR/apps/$uk/build/unikernel_linuxu-x86_64"
        prepare_custom_loader_aslr "$UK"
    done
}

test

run_sudo_cmd && echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog

main_benchmark
aligned_benchmark
aslr_benchmark

run_sudo_cmd && echo 1 | sudo tee /proc/sys/kernel/nmi_watchdog
