#!/bin/bash
source "common.sh"
uktype=""
app=""
mode="aggregated"
core=0
relro=0
rewrite=0
shuffle=0
prepare=0
clear_cache=1

usage(){
    echo "Usage: $0 --uktype <run_loader|run_custom_loader|run_custom_aslr> --app <app_name> [--mode <base|common|aggregated>] [--core <core>] [--relro <0|1>] [--rewrite <0|1>] [--shuffle <0|1>] [--prepare-only <0|1>]"
    exit 1
}

run_exec(){
    local binary="$1"
    local core="$2"
    if [ "$clear_cache" -eq 1 ]; then
        run_sudo_cmd
        sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
    fi
    if [ "$core" -ne 0 ]; then
        $CMD taskset -c "$core" "$binary"
    else
        $CMD "$binary"
    fi
}

single_test_loader(){
    local uk_arg="$1"
    local UK="$WORKSPACE_DIR/apps/$uk_arg/build/unikernel_linuxu-x86_64.dbg"
    
    if [ "$prepare" -eq 1 ]; then
        cd "$SCRIPTS_DIR" || die "Failed to change directory to $SCRIPTS_DIR"
        run_sudo_cmd
        python3 parse_cmd.py --uk "$uk_arg" --relro "$relro" --ld_mode "$mode"
        exit 0
    fi 
    run_exec "$UK" "$core" #run_loader "$UK" "$core"
}

single_test_custom(){
    local uk_arg="$1"
    local UK="$WORKSPACE_DIR/apps/$uk_arg/build/unikernel_linuxu-x86_64_sym"

    if [ "$prepare" -eq 1 ]; then
        cd "$SCRIPTS_DIR" || die "Failed to change directory to $SCRIPTS_DIR"
        run_sudo_cmd
        python3 parse_cmd.py --uk "$uk_arg" --relro "$relro" --ld_mode "$mode"
        exit 0
    fi
    run_exec "$UK" "$core" #run_custom_loader "$UK" "$core"
}

single_test_custom_aslr(){
    local uk_arg="$1"
    local UK="$WORKSPACE_DIR/apps/$uk_arg/build/unikernel_linuxu-x86_64_sym_aslr"
    
    if [ "$prepare" -eq 1 ]; then
        cd "$SCRIPTS_DIR" || die "Failed to change directory to $SCRIPTS_DIR"
        ./run_aligner.sh 1 "$rewrite" "$shuffle"
        exit 0
    fi

    run_exec "$UK" "$core" #run_custom_loader_aslr "$UK" "$core"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --uktype)
      if [[ -n "$2" && "$2" != "--"* ]]; then
        uktype="$2"
        shift 2
      else
        echo "Error: --uktype requires a value."
        usage
      fi
      ;;
    --app)
      if [[ -n "$2" && "$2" != "--"* ]]; then
        app="$2"
        shift 2
      else
        echo "Error: --app requires a value."
        usage
      fi
      ;;
    --mode)
      if [[ -n "$2" && "$2" != "--"* ]]; then
        mode="$2"
        shift 2
      else
        echo "Error: --mode requires a value."
        usage
      fi
      ;;
    --core)
      if [[ -n "$2" && "$2" != "--"* ]]; then
        core="$2"
        shift 2
      else
        echo "Error: --core requires a value."
        usage
      fi
      ;;
    --relro)
        if [[ -n "$2" && "$2" != "--"* ]]; then
            relro="$2"
            shift 2
        else
            echo "Error: --relro requires a value."
            usage
        fi
        ;;
    --rewrite)
        if [[ -n "$2" && "$2" != "--"* ]]; then
            rewrite="$2"
            shift 2
        else
            echo "Error: --rewrite requires a value."
            usage
        fi
        ;;
    --shuffle)
        if [[ -n "$2" && "$2" != "--"* ]]; then
            shuffle="$2"
            shift 2
        else
            echo "Error: --shuffle requires a value."
            usage
        fi
        ;;
    --prepare-only)
        if [[ -n "$2" && "$2" != "--"* ]]; then
            prepare="$2"
            shift 2
        else
            echo "Error: --prepare requires a value."
            usage
        fi
        ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [ "$uktype" == "run_loader" ]; then
    single_test_loader "$app"
elif [ "$uktype" == "run_custom_loader" ]; then
    single_test_custom "$app"
elif [ "$uktype" == "run_custom_aslr" ]; then
    single_test_custom_aslr "$app"
fi