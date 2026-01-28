#!/bin/bash
source "common.sh"

MEMORY_RESULTS_DIR="$WORKSPACE_DIR/all_results/memory"
UK="appmandelbrot-perf"
SLEEP=60
NB_INSTANCES=500

run_memory_custom_loader(){
    local uk="$1"
    local instances="$2"
    local binary="$WORKSPACE_DIR/apps/$uk/build/unikernel_linuxu-x86_64"

    prepare_custom_loader "$binary"

    cd "$CUSTOM_LOADER_DIR" || die "Failed to change directory to $CUSTOM_LOADER_DIR"
    addr=$(nm "${binary}_sym.dbg"|grep -w "_liblinuxuplat_start"|awk '{print $1}')
    for i in $(seq 1 "$instances"); do
        tmux new-session -d -s "rtb$i"
        tmux send-keys "target/release/custom_loader ${binary}_sym $addr '' &>> $MEMORY_RESULTS_DIR/$uk/custom_loader.log" C-m
    done

    ps -aux | grep -c "custom_loader"
    sleep ${SLEEP}
    ps -aux | grep -c "custom_loader"
    for i in $(seq 1 "$instances"); do
        tmux kill-session -t "rtb$i"
    done
    cd "-" || die "Failed to change directory to previous directory"
}

run_memory_ksm_loader(){

    local uk="$1"
    local instances="$2"
    local binary="$WORKSPACE_DIR/apps/$uk/build/unikernel_linuxu-x86_64"

    cd "$KSM_LOADER_DIR" || die "Failed to change directory to $KSM_LOADER_DIR"
    for i in $(seq 1 "$instances"); do
        tmux new-session -d -s "rtb$i"
        tmux send-keys "target/release/ksm_loader ${binary}_sym '' &>> $MEMORY_RESULTS_DIR/$uk/ksm_loader.log" C-m
    done

    ps -aux | grep -c "ksm_loader"
    sleep ${SLEEP}
    ps -aux | grep -c "ksm_loader"
    for i in $(seq 1 "$instances"); do
        tmux kill-session -t "rtb$i"
    done
    cd "-" || die "Failed to change directory to previous directory"
}

run_memory_dynamic_loader(){
    local uk="$1"
    local instances="$2"
    local binary="$WORKSPACE_DIR/apps/$uk/build/unikernel_linuxu-x86_64"

    cd "$LOADER_DIR" || die "Failed to change directory to $LOADER_DIR"
    for i in $(seq 1 "$instances"); do
        tmux new-session -d -s "rtb$i"
        tmux send-keys "target/release/loader ${binary}.dbg '' &>> $MEMORY_RESULTS_DIR/$uk/loader.log" C-m
    done

    ps -aux | grep -c "loader"
    sleep ${SLEEP}
    ps -aux | grep -c "loader"
    for i in $(seq 1 "$instances"); do
        tmux kill-session -t "rtb$i"
    done
    cd "-" || die "Failed to change directory to previous directory"
}

run_memory_benchmark(){
    local loader="$1"
    local instances="$2"
    local suffix="${3:-""}"
    local datafilerollups="/tmp/memory.csv"

    watch -n 1 "smap_rollup_parser -n ${loader} -d ${datafilerollups}" &> /dev/null &
    sleep 0.1

    mkdir -p "$MEMORY_RESULTS_DIR/$UK"

    if [ "$loader" == "custom_loader" ]; then
        run_memory_custom_loader "$UK" "$instances"
    elif [ "$loader" == "ksm_loader" ]; then
        run_memory_ksm_loader "$UK" "$instances"
    elif [ "$loader" == "loader" ]; then
        run_memory_dynamic_loader "$UK" "$instances"
    else
        die "Unknown loader"
    fi

    mv "${datafilerollups}" "${MEMORY_RESULTS_DIR}/$UK/${loader}${suffix}.csv"

    killall watch
    killall smap_rollup_parser 
    killall "${loader}"
}

run_memory_benchmark "custom_loader" $NB_INSTANCES
run_memory_benchmark "loader" $NB_INSTANCES

run_sudo_cmd && echo 0 | sudo tee /sys/kernel/mm/ksm/run
run_memory_benchmark "ksm_loader" $NB_INSTANCES

run_sudo_cmd && echo 1 | sudo tee /sys/kernel/mm/ksm/run
run_memory_benchmark "ksm_loader" $NB_INSTANCES "_ksm_on"