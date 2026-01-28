#!/bin/bash
WORKSPACE_DIR="/home/gain/dev/unikraft_dynamic"
RESULTS_DIR="$WORKSPACE_DIR/results"
ALL_RESULTS_DIR="$WORKSPACE_DIR/all_results"

SCRIPTS_DIR="$WORKSPACE_DIR/scripts"
HELPER_DIR="$SCRIPTS_DIR/helpers"
SCRIPTS_PLOT_DIR="$SCRIPTS_DIR/plots"

POOL_DIR="$WORKSPACE_DIR/test_shared_lib/pool"
SHM_DIR="/dev/shm"

LOADER_DIR="$WORKSPACE_DIR/loaders/rust_userspace_loader"
CUSTOM_LOADER_DIR="$WORKSPACE_DIR/loaders/rust_custom_loader"
CUSTOM_LOADER_ASLR_DIR="$WORKSPACE_DIR/loaders/rust_custom_loader_aslr"
KSM_LOADER_DIR="$WORKSPACE_DIR/loaders/rust_ksm_loader"

PASSWORD="TODEFINE"

UKS=("apphelloworld-perf" "appnginx-perf" "appsqlite-perf" "appsqlite-test" "appmandelbrot-perf" "applambda-perf" "apppython-perf")
TMP_FILE="/tmp/tmp_file.log"

STATS="minor-faults,major-faults,cycles,instructions,cache-misses,cache-references,L1-dcache-load-misses,L1-dcache-loads,L1-dcache-prefetch-misses,L1-dcache-store-misses,L1-dcache-stores,L1-icache-load-misses,LLC-load-misses,LLC-loads,LLC-prefetch-misses,LLC-prefetches,LLC-store-misses,LLC-stores,branch-load-misses,branch-loads,dTLB-load-misses,dTLB-loads,dTLB-store-misses,dTLB-stores,iTLB-load-misses,iTLB-loads,node-load-misses,node-loads,node-prefetch-misses,node-prefetches,node-store-misses,node-stores"
CMD="perf stat -e $STATS"
#CMD="/usr/bin/time -v"

run_sudo_cmd(){
    echo "$PASSWORD" | sudo -S date > "/dev/null"
}   

die(){
    echo "$1" && exit 1
}

compile_loader() {
    echo "Compiling loader..."
    cd "$1" || die "Failed to change directory to $1"
    cargo build --release || die "Failed to compile loader"
    cd - || die "Failed to change directory to previous directory"
}

prepare_loader(){
    local binary="$1.dbg"
    local libs=("/lib/x86_64-linux-gnu/liblinuxuplat.so" "/lib/x86_64-linux-gnu/libukmusl.so" "/lib/x86_64-linux-gnu/libcontext.so" "/lib/x86_64-linux-gnu/libukcrypto.so" "/lib/x86_64-linux-gnu/libcompiler_rt.so")
    for lib in "${libs[@]}"; do
        execstack -q "$lib" > /tmp/execstack
        if grep -q "X" /tmp/execstack; then
            echo "Disabling execstack for $lib"
            sudo execstack -c "$lib" || die "Failed to disable execstack"
        fi
    done
    #cd - || die "Failed to change directory to previous directory"
}

run_loader(){
    local binary="$1.dbg"
    local core="$2"
    cd "$LOADER_DIR"  || die "Failed to change directory to $LOADER_DIR"
    if [ "$core" -ne 0 ]; then
        $CMD taskset -c "$core" target/release/loader "$binary" ""
    else
        $CMD target/release/loader "$binary" ""
    fi
}

prepare_custom_loader(){

    local binary="${1}_sym"

    rm -rf "${SHM_DIR}"/lib* &> /dev/null
    rm -rf "$POOL_DIR" &> /dev/null
    mkdir "$POOL_DIR"

    cd "$HELPER_DIR"||die "cannot go to $HELPER_DIR"
    python3 dump_sections.py --uk "${binary}" &> /tmp/custom_loader.log
    python3 lib_extractor.py --uk "${binary}" &>> /tmp/custom_loader.log
    python3 elf_minimizer.py --uk "${binary}" &>> /tmp/custom_loader.log
    cd "$POOL_DIR"|| die "cannot go to $POOL_DIR"

    if [ -f "initrd" ]; then
        mv "initrd" "${SHM_DIR}/libinitrd"
    fi

    objcopy -O binary --only-section=.eh_frame "${binary}" /tmp/lib.eh_frame
    objcopy -O binary --only-section=.eh_frame_hdr "${binary}" /tmp/lib.eh_frame_hdr
    cat "/tmp/lib.eh_frame" "/tmp/lib.eh_frame_hdr" > "/tmp/lib.uk_all0"
    
    objcopy -O binary --only-section=.uk_ctortab "${binary}" /tmp/lib.uk_ctortab
    objcopy -O binary --only-section=.uk_inittab "${binary}" /tmp/lib.uk_inittab
    objcopy -O binary --only-section=.uk_eventtab  "${binary}" /tmp/lib.uk_eventtab
    objcopy -O binary --only-section=.uk_posix_clonetab  "${binary}" /tmp/lib.uk_posix_clonetab
    objcopy -O binary --only-section=.uk_fs_list  "${binary}" /tmp/lib.uk_fs_list
    objcopy -O binary --only-section=.uk_thread_inittab  "${binary}" /tmp/lib.uk_thread_inittab
    cat "/tmp/lib.uk_ctortab" "/tmp/lib.uk_inittab" "/tmp/lib.uk_eventtab" "/tmp/lib.uk_posix_clonetab" "/tmp/lib.uk_fs_list" "/tmp/lib.uk_thread_inittab" > "/tmp/lib.uk_all1"

    objcopy -O binary --only-section=.tdata  "${binary}" /tmp/lib.tdata
    objcopy -O binary --only-section=.tbss  "${binary}" /tmp/lib.tbss
    cat "/tmp/lib.tdata" "/tmp/lib.tbss" > "/tmp/lib.uk_all2"

    for f in .*; do 
        if [ "$f" == "." ] || [ "$f" == ".." ]; then
            continue
        fi
        mv -- "$f" "${SHM_DIR}/lib$f" 2> "/dev/null"; 
    done
    mv "/tmp/lib.uk_all0" "${SHM_DIR}/lib.eh_frame"
    mv "/tmp/lib.uk_all1" "${SHM_DIR}/lib.uk_ctortab"
    mv "/tmp/lib.uk_all2" "${SHM_DIR}/lib.tdata"

    #cd - || die "Failed to change directory to previous directory"
}

run_custom_loader(){
    local binary="${1}_sym"
    local core="$2"
    cd "$CUSTOM_LOADER_DIR" || die "Failed to change directory to $CUSTOM_LOADER_DIR"
    addr=$(nm "$binary.dbg"|grep -w "_liblinuxuplat_start"|awk '{print $1}')
    if [ "$core" -ne 0 ]; then
        $CMD taskset -c "$core" target/release/custom_loader "$binary" "$addr" ""
    else
        $CMD target/release/custom_loader "$binary" "$addr" ""
    fi
}


prepare_custom_loader_aslr(){
    local binary="${1}_sym_aslr"
    local pool_dir="${POOL_DIR}_aslr"

    #rm -rf "${SHM_DIR}"/aslr* &> /dev/null
    rm -rf "$pool_dir" &> /dev/null
    mkdir "$pool_dir"

    cd "$HELPER_DIR"||die "cannot go to $HELPER_DIR"
    python3 dump_sections.py --uk "${binary}" &> /tmp/custom_loader.log
    python3 lib_extractor.py --uk "${binary}" &>> /tmp/custom_loader.log
    python3 elf_minimizer.py --uk "${binary}" &>> /tmp/custom_loader.log
    cd "$pool_dir"|| die "cannot go to $pool_dir"

    if [ -f "initrd" ]; then
        mv "initrd" "${SHM_DIR}/aslrinitrd"
    fi

    objcopy -O binary --only-section=.uk_ctortab "${binary}" /tmp/lib.uk_ctortab
    objcopy -O binary --only-section=.uk_inittab "${binary}" /tmp/lib.uk_inittab
    objcopy -O binary --only-section=.uk_eventtab  "${binary}" /tmp/lib.uk_eventtab
    objcopy -O binary --only-section=.uk_posix_clonetab  "${binary}" /tmp/lib.uk_posix_clonetab
    objcopy -O binary --only-section=.uk_fs_list  "${binary}" /tmp/lib.uk_fs_list
    objcopy -O binary --only-section=.uk_thread_inittab  "${binary}" /tmp/lib.uk_thread_inittab
    cat "/tmp/lib.uk_ctortab" "/tmp/lib.uk_inittab" "/tmp/lib.uk_eventtab" "/tmp/lib.uk_posix_clonetab" "/tmp/lib.uk_fs_list" "/tmp/lib.uk_thread_inittab" > "/tmp/lib.uk_all1"

    objcopy -O binary --only-section=.tdata  "${binary}" /tmp/lib.tdata
    objcopy -O binary --only-section=.tbss  "${binary}" /tmp/lib.tbss
    cat "/tmp/lib.tdata" "/tmp/lib.tbss" > "/tmp/lib.uk_all2"

    for f in .*; do 
        if [ "$f" == "." ] || [ "$f" == ".." ]; then
            continue
        fi
        mv -- "$f" "${SHM_DIR}/aslr$f" 2> "/dev/null"; 
    done
    mv "/tmp/lib.uk_all1" "${SHM_DIR}/aslr.uk_ctortab"
    mv "/tmp/lib.uk_all2" "${SHM_DIR}/aslr.tdata"
}

run_custom_loader_aslr(){
    local binary="${1}_sym_aslr"
    local core="$2"
    cd "$CUSTOM_LOADER_ASLR_DIR" || die "Failed to change directory to $CUSTOM_LOADER_ASLR_DIR"
    addr=$(nm "${binary}.dbg"|grep -w "_liblinuxuplat_start"|awk '{print $1}')
    if [ "$core" -ne 0 ]; then
        $CMD taskset -c "$core" target/release/custom_loader_aslr "$binary" "$addr" ""
    else
        $CMD target/release/custom_loader_aslr "$binary" "$addr" ""
    fi
}
