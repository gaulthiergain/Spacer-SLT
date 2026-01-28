#!/usr/bin/python3

from elftools.elf.elffile import ELFFile
import argparse
import json
import sys

sys.path.insert(0,'..')
from aligner import str2bool, LIBS_NAME, LIBS_NAME_ASLR
from collections import defaultdict

UK      = "/home/gain/unikraft/apps/lib-hanoi/build/unikernel_kvmfc-x86_64_local_align"
LIB_KEY = "sections"

verbose=False

def printv(*args, **kwargs):
    if verbose:
        print(*args, **kwargs)

def write_json(uk_path, data):
    
    uk_path = uk_path + ".json"
    with open(uk_path, "w") as json_out:
        _ = json.dump(dict(data), json_out) #, indent=2
    
    printv("Written {}".format(uk_path))
    
def process_file_minimal(ukpath, data):
    
    data_libs = defaultdict(list)
    with open(LIBS_NAME, "r") as json_in:
        data_dict = json.load(json_in)
        for label in ["common_to_all", "common_to_subset", "not_common"]:
            for k in data_dict[label]:
                data_libs[label].append(k["name"])
    
    with open(ukpath, 'rb') as f:
        elffile = ELFFile(f)
        for i, section in enumerate(elffile.iter_sections()):
            
            if section == None or section.name == None:
                continue
            
            if ".data" in section.name:
                continue
            
            if section.name in data_libs["not_common"] or section.name in data_libs["common_to_subset"]:
                sec = {'name': section.name, 'size': hex(section['sh_size']), 'vma': hex(section['sh_addr'])}
                printv("Write (min) section: " + section.name)
                data[LIB_KEY].append(sec)
        
            if i > 0 and section['sh_addr'] == 0:
                break
    ukpath = ukpath + "_minimal"
    return ukpath
            

def process_file(ukpath, data, excluded):
    
    data_libs = defaultdict(list)
    if "aslr" in ukpath:
        with open(LIBS_NAME_ASLR, "r") as json_in:
            data_libs = json.load(json_in)
    
    with open(ukpath, 'rb') as f:
        elffile = ELFFile(f)
        for i, section in enumerate(elffile.iter_sections()):
            sec = {'name': section.name, 'size': hex(section['sh_size']), 'vma': hex(section['sh_addr'])}
            
            if ".ind" in section.name or len(section.name) == 0 or section.name in excluded or section.name in data_libs["not_common"]:
                #print("[SKIP]: " + section.name)
                continue
            
            
            if section['sh_addr'] % 0x1000 != 0:
                continue
            
            if i > 0 and section['sh_addr'] == 0:
                break
            
            printv("Write section: " + section.name)
            data[LIB_KEY].append(sec)
    return ukpath

def main():
    
    global verbose
    parser = argparse.ArgumentParser(description='Generate json from unikernel')
    parser.add_argument('-k', '--uk',  help='Unikernel', type=str, default=UK)
    parser.add_argument('-i', '--ignore', help='Sections to ignore as a list (-i sec1 sec2 ...)', nargs='+')
    parser.add_argument('-v', '--verbose', help='Verbose mode', type=str2bool, nargs='?', const=True, default=True)
    parser.add_argument('-m', '--minimal', help='Use minimal config for snapshoting', type=str2bool, nargs='?', const=True, default=False)
    args = parser.parse_args()
    
    ukpath = args.uk.replace(".dbg", "")
    
    verbose = args.verbose
    excluded = [ ".bss", ".tbss", ".intrstack"]
    if args.ignore and len(args.ignore) > 0:
        excluded = excluded + args.ignore

    data = {LIB_KEY : list()}
    
    if args.minimal and "aslr" in args.uk:
        print("Cannot use minimal and aslr at the same time")
        return
    
    printv("---" * 30)
    if args.minimal:
        ukpath = process_file_minimal(ukpath, data)
    else:
        ukpath = process_file(ukpath, data, excluded)
    write_json(ukpath, data)
    printv("---" * 30)

if __name__ == '__main__':
    main()