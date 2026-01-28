#!/usr/bin/python3

from elftools.elf.elffile import ELFFile
import argparse
import hashlib
import math
import os

LIBS_DIR = "/home/gain/dev/firecracker/pool"
UK      = "/home/gain/unikraft/apps/lib-hanoi/build/unikernel_kvmfc-x86_64_local_align"

def opener(path, flags):
    return os.open(path, flags, 0o764)

def round_to_n(x, base):
    if base == 0:
        return 0
    return base * math.ceil(x/base)

class ukSections:
    def __init__(self, name):
        self.name = name
        self.all_names = [name]
        self.xbytes = bytearray()

def process_file(uk_name, pool_dir, use_aslr, excluded):
    
    with open(uk_name, 'rb') as f:
        elffile = ELFFile(f)

        for _, section in enumerate(elffile.iter_sections()):

            if ".ind" in section.name or ".data" in section.name:
                print("[WARNING] Ignore: " +  section.name)
   
            elif section.name not in excluded and section["sh_addr"] > 0:
                data_sec = section.data()
                filename = os.path.join(pool_dir, section.name)
                if not os.path.exists(filename):
                    print("[INFO] Write library: " +  filename)
                    with open(filename, "wb") as f:
                        f.write(data_sec)
                else:
                    print("[WARNING] library: " +  section.name + " already exists.")

def main():
    
    parser = argparse.ArgumentParser(description='Extract libs')
    parser.add_argument('-k', '--uk',  help='Unikernel', type=str, default=UK)
    parser.add_argument('-d', '--dir',  help='Directory', type=str, default=LIBS_DIR)
    parser.add_argument('-i', '--ignore', help='Sections to ignore as a list (-i sec1 sec2 ...)', nargs='+')
    args = parser.parse_args()
    
    excluded = [".data", ".bss", ".tbss", ".intrstack"]
    if args.ignore and len(args.ignore) > 0:
        excluded = excluded + args.ignore

    if "aslr" in args.uk:
        args.dir +="_aslr"
        process_file(args.uk, args.dir, True, excluded)
    else:
        process_file(args.uk, args.dir, False, excluded)

if __name__ == '__main__':
    main()