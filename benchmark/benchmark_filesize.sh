#!/bin/bash
UNIKRAFT="$HOME/unikraft"
CSV_SIZE="$HOME/unikraft/results/results_size/csv_sizes.csv"

declare uktypes=("DCE" "DEFAULT" "SPACER" "SPACER_SHM" "DCE_ASLR" "DEFAULT_ASLR" "SPACER_ASLR" "SPACER_ASLR_SHM")
declare -A maptotalsize=( ["DCE"]=0 ["DEFAULT"]=0 ["SPACER"]=0 ["SPACER_SHM"]=0 ["DCE_ASLR"]=0 ["DEFAULT_ASLR"]=0 ["SPACER_ASLR"]=0 ["SPACER_ASLR_SHM"]=0)
declare -A shmsec=( ["DCE"]=0 ["DEFAULT"]=0 ["SPACER"]=0 ["SPACER_SHM"]=0 ["DCE_ASLR"]=0 ["DEFAULT_ASLR"]=0 ["SPACER_ASLR"]=0 ["SPACER_ASLR_SHM"]=0 )

function get_size() {
    KERNEL=$1
    suffix=""
    declare -A mapuktypes=( ["DCE"]=0 ["DEFAULT"]=0 ["SPACER"]=0 ["SPACER_SHM"]=0 ["DCE_ASLR"]=0 ["DEFAULT_ASLR"]=0 ["SPACER_ASLR"]=0 ["SPACER_ASLR_SHM"]=0)
    
    for key in "${!mapuktypes[@]}"; do

        appfolder="apps"
        if [[ $key == *"DCE"* ]]; then 
            appfolder="apps_size"
            suffix=""
        elif [[ $key == *"SPACER"* ]]; then 
            suffix="_local_align"
        else
            suffix=""
        fi

        if [[ $key == *"_ASLR"* ]]; then
            suffix="${suffix}_aslr"
        fi

        if [[ $key == *"_SHM"* ]]; then
            # Compute the minified elf file as well as the sec file
            cmd_sec=$(du -k "$UNIKRAFT/apps/$KERNEL/build/unikernel_kvmfc-x86_64${suffix}.sec"| cut -f1)
            shmsec[$key]=$(( shmsec[$key] + cmd_sec ))
            value=$(du -k "$UNIKRAFT/${appfolder}/$KERNEL/build/unikernel_kvmfc-x86_64${suffix}_update" 2> /dev/null)
            if [[ -z "$value" ]]; then 
                value=0
            else
                value=$(echo "$value"| cut -f1)
            fi 
            mapuktypes[$key]=$value
        else
            mapuktypes[$key]=$(du -k "$UNIKRAFT/${appfolder}/$KERNEL/build/unikernel_kvmfc-x86_64${suffix}"| cut -f1)
        fi
    done

    ukline="$KERNEL"
    for key in "${uktypes[@]}"; do
        ukline="${ukline};${mapuktypes[$key]}"
        maptotalsize[$key]=$(( maptotalsize[$key] + mapuktypes[$key] ))
    done

    echo "$ukline" >> "${CSV_SIZE}"
}

function get_total_size() {
    
    pool=$(du -k /home/gain/dev/firecracker/pool | cut -f1)
    pool_aslr=$(du -k /home/gain/dev/firecracker/pool_aslr | cut -f1)
    
    {
        echo ""
        echo "pool_size;0;0;0;$pool;0;0;0;$pool_aslr"
    } >> "${CSV_SIZE}"

    {
        echo "sec_files;0;0;0;${shmsec["SPACER_SHM"]};0;0;0;${shmsec["SPACER_ASLR_SHM"]}"
        echo "" 
    } >> "${CSV_SIZE}"

    ukline="total"
    for key in "${uktypes[@]}"; do 
        if [[ $key == "SPACER_SHM" ]]; then
            ukline="${ukline};$(( maptotalsize[$key] + pool + shmsec[$key] ))"
        elif [[ $key == "SPACER_ASLR_SHM" ]]; then
            ukline="${ukline};$(( maptotalsize[$key] + pool_aslr + shmsec[$key] ))"
        else
            ukline="${ukline};${maptotalsize[$key]}"
        fi
        
    done
    echo "$ukline" >> "${CSV_SIZE}"
}

rm "${CSV_SIZE}"
echo "NAME;DCE;DEFAULT;SPACER;SPACER_SHM;DCE_ASLR;DEFAULT_ASLR;SPACER_ASLR;SPACER_ASLR_SHM" >> "${CSV_SIZE}"

unikernels=("lib-nginx" "lib-dhcp" "lib-dns" "lib-ftp" "lib-weborf" "lib-haproxy" "lib-iperf3" "lib-scamper-uradargun" "lib-scamper-utnt" "lib-scamper-uspeedtrap" "lib-helloworld" "lib-helloworld-perf" "lib-nginx-perf" "lib-dns-perf" "lib-zlib-perf" "lib-mandelbrot-perf" "lib-matrix-perf" "lib-lambda-perf" "lib-sqlite-perf" "lib-sqlite")
for i in "${unikernels[@]}"; do 
    get_size "$i"
done
get_total_size
echo ""
echo "Filesize is written into ${CSV_SIZE}"
