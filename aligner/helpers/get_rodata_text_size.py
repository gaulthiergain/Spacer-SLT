import os
import sys
import json
import argparse

sys.path.insert(0,'..')
from aligner import WORKSPACE, UKS_INCLUDED, str2bool

def process_lds(linker, map_size):

    with open(linker, 'r') as f:
        lines = f.readlines()
    
    is_in_common_libs = False
    for line in lines:
        
        if "text.rodata.common" in line:
            is_in_common_libs = True
            map_size["text.rodata.common"] = ""
        
        if "}" in line and is_in_common_libs:
            is_in_common_libs = False

        if "(.rodata" in line or "(.text" in line:
            l = line.split()
            appname = l[0].replace(";", "").replace(".*","")
            size=-1
            if len(l) == 4:
                size = l[2]
            elif len(l) == 8:
                size = l[4]
            else:
                continue
            if appname in map_size and map_size[appname] != int(size,16):
                print("Error: Different size for {} in the same linker file".format(appname))
                print("Size1: {} Size2: {}".format(map_size[appname], int(size,16)))
                
            if is_in_common_libs and "(.text" in line:
                map_size["text.rodata.common"] += appname.replace(".o(.text)", "") + ";"
            
            map_size[appname] = int(size,16)
    
def main():
    
    parser = argparse.ArgumentParser()
    parser.add_argument('-w', '--workspace',help='Workspace directory', type=str, default=WORKSPACE)
    parser.add_argument('-u', '--uks',      help='Unikernels to align as a list (-l uks1 uks2 ...)', nargs='+', default=UKS_INCLUDED)
    args = parser.parse_args()
    
    map_size=dict()

    for uk in args.uks:
        process_lds(os.path.join(WORKSPACE, "apps", uk, "build/libkvmfcplat/link64_out.lds"), map_size)
    
    if "text.rodata.common" in map_size:
        map_size["text.rodata.common"] = map_size["text.rodata.common"][:-1]
    
    # Make a json dump into a file with beautiful formatting
    with open(os.path.join(WORKSPACE, "aligner", "helpers", "rodata_text_size.json"), 'w') as f:
        json.dump(map_size, f, indent=4)
    

if __name__ == "__main__":
    main()
