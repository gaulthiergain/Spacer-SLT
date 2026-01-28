#!/usr/bin/python3
#TODO CHECK RODATA AND TEXT OF COMMON SECTIONS

import os
import json
import math
import sys
import diff_match_patch as dmp_module
import argparse

sys.path.insert(0,'..')

from capstone import *
from subprocess import run, PIPE
from uk_sharing_class import *
from collections import defaultdict
from elftools.elf.elffile import ELFFile
from utils import round_to_n
from aligner import WORKSPACE, UKS_INCLUDED

VERBOSE         = False
DIFF            = False
RENDER          = False
SAVE_TO_PAGE    = False
GET_SYMBOLS     = False
APPS_FOLDER     = "apps"
DETECT_RODATA_TEXT = False #change it to False for default

#SECTION_NAMES = ['.text.*', '.rodata', '.data', '.bss', '.uk_fs_list', '.uk_thread_inittab', 'vfs__param_arg', '.uk_lib_arg__lib_param', '.uk_ctortab', '.uk_inittab', '.uk_eventtab', 'netdev__param_arg']
#SECTION_NAMES = ['.text.*', '.rodata', '.data', '.uk_fs_list', '.uk_thread_inittab', 'vfs__param_arg', '.uk_lib_arg__lib_param', '.uk_ctortab', '.uk_inittab', '.uk_eventtab', 'netdev__param_arg']
SECTION_NAMES = ['.text.*']
#SECTION_NAMES = ['.rodata']
#SECTION_NAMES = ['.data']
#SECTION_NAMES = ['.uk_fs_list', '.uk_thread_inittab', 'vfs__param_arg', '.uk_lib_arg__lib_param', '.uk_ctortab', '.uk_inittab', '.uk_eventtab', 'netdev__param_arg']
#SECTION_NAMES = ['.bss']

is_aligned=False

def get_unikernels(workspace, included, use_aslr):
    
    print("SECTION_NAMES = {}".format(SECTION_NAMES))
    
    debug=".dbg"
    if use_aslr:
        use_aslr="_aslr"
        debug=""
    else:
        use_aslr=""
    
    print("\n-----[{}]-------".format(get_unikernels.__name__.upper()))
    
    unikernels = list()
    
    suffix=""
    if "size" not in APPS_FOLDER:
        # comment below for default
        #print("")
        suffix="_local_align"
        global is_aligned
        is_aligned=True

    for d in os.listdir(workspace):
        if d in included:
            if os.path.exists(os.path.join(workspace, d, "build", "libkvmfcplat.o")):
                path = os.path.join(workspace, d, "build", "unikernel_kvmfc-x86_64" + suffix +  use_aslr + debug)
            else:
                path = os.path.join(workspace, d, "build", "unikernel_kvmq-x86_64" + suffix + use_aslr + debug)
            print("- Analyse unikernel: {}".format(d))
            unikernels.append(Unikernel(path))

    return unikernels

def disassemble(uk, page):
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    #md.detail = True
    for i in md.disasm(page.content, page.start):
        page.instructions.append(Instruction(i.address, i.mnemonic, i.op_str, i.bytes))
    
    page.instructions_to_string(uk.map_symbols)

def compare_pages(a, b, size):
    for i in range(size):
        if a[i] != b[i]:
            return False
    return True

def process_symbols(uk, lines):
    for l in lines:
        group = l.split()
        if len(group) == 3:
            symbol = Symbol(int(group[0],16), group[2], group[1])
            uk.map_symbols[symbol.address].append(symbol)
        else:
            print("- [WARNING] Ignoring symbol {}".format(l))

def get_symbols(uk):
    p = run( ['nm', '--no-demangle',uk.name], stdout=PIPE, stderr=PIPE, universal_newlines=True)

    if p.returncode == 0 and len(p.stdout) > 0:
        process_symbols(uk, p.stdout.splitlines())
    elif len(p.stderr) > 0:
        print("- [WARNING] stderr:", p.stderr)
    else:
        print("- [ERROR] Failure to run NM")
        sys.exit(1)

def process_file_aslr_dce(uk):

    with open(uk.name, 'rb') as f:
        elffile = ELFFile(f)

        for segment in elffile.iter_segments():
            uk.segments.append(Segment(segment['p_vaddr'], segment['p_offset'], segment['p_memsz']))

        first = None
        last = None
        for section in elffile.iter_sections():

            uk_sect = Section(section.name , section['sh_addr'], section['sh_offset'], section['sh_size'], section['sh_addralign'])
            if section.name == '.text':
                # Add it to the beginning before other ".text" sections
                uk.sections.insert(1, uk_sect)
            elif len(section.name) == 0:
                ## Empty section
                uk.sections.insert(0, uk_sect)
            elif uk_sect.start == 0:
                ## No loadable section (ignore)
                continue
            elif section.name.startswith(".text.") and first==None:
                first = uk_sect
                continue
            elif section.name.startswith(".text."):
                last = uk_sect
                continue
            else:
                uk.sections.append(uk_sect)             

            uk.map_addr_section[section['sh_addr']] = uk_sect
        
        uk_sect = Section(".text.code" , first.start, first.offset, last.start-first.start+last.size, first.alignment)
        uk.sections.append(uk_sect)
        uk.map_addr_section[section['sh_addr']] = uk_sect
            
def process_file(uk):

    with open(uk.name, 'rb') as f:
        elffile = ELFFile(f)

        for segment in elffile.iter_segments():
            uk.segments.append(Segment(segment['p_vaddr'], segment['p_offset'], segment['p_memsz']))

        for section in elffile.iter_sections():

            uk_sect = Section(section.name , section['sh_addr'], section['sh_offset'], section['sh_size'], section['sh_addralign'], uk.name)
            if section.name == '.text':
                # Add it to the beginning before other ".text" sections
                uk.sections.insert(1, uk_sect)
            elif len(section.name) == 0:
                ## Empty section
                uk.sections.insert(0, uk_sect)
            elif uk_sect.start == 0:
                ## No loadable section (ignore)
                continue
            else:
                uk.sections.append(uk_sect)

            uk.map_addr_section[section['sh_addr']] = uk_sect

def page_to_file(s, i, page, args, path):

    name = path + s.name.replace(".", "") + "_page_" + str(i)
    if args.verbose:
        print("- Save page {} into file {}.bin-txt".format(page.number, name))

    with open((name + ".bin"), "wb") as f:
        f.write(page.content)

    with open((name + ".txt"), "w") as f:
        f.write(page.instructions_string)

def process_pages(uk, args, path):

    for s in uk.sections:
        if s.name in args.list:
            #print(s.name)
            for i, p in enumerate(range(0, len(s.data), PAGE_SIZE)):
                page = Page("", i, s.start+p, PAGE_SIZE, uk.shortname, s.name, s.data[p:p+PAGE_SIZE])
                disassemble(uk, page)
                s.pages.append(page)
                if args.pages:
                    page_to_file(s, i, page, args, path)
                
            if args.verbose:
                    print("- #Pages: {} ".format(len(s.pages)))

def process_common_text(elffile, s, maps_json_rodata):
    
    old_data = elffile.get_section_by_name(s.name).data()
    all_libs = maps_json_rodata["text.rodata.common"]
    
    text_bt = bytearray()
    rodata_bt = bytearray()
    
    old_text_offset = 0
    
    for lib in all_libs.split(";"):
        label = lib
        text_size = maps_json_rodata[label + ".o(.text)"]
        rodata_size = maps_json_rodata[label + ".o(.rodata)"]
        
        new_text_offset = old_text_offset+text_size
        text_bt += old_data[old_text_offset:new_text_offset]
        rodata_bt += old_data[new_text_offset:new_text_offset+rodata_size]
        
        #print("Lib: {}".format(label))
        #print("Size text_bt: {} - Addr: {}".format(hex(text_size), hex(s.start+text_size)))
        #print("Size rodata_bt: {} - Addr: {}".format(hex(rodata_size), hex(s.start+text_size+rodata_size)))
        
        #print("- [{}] Start: 0x{:02x} (size: 0x{:02x}/0x{:02x}) End: 0x{:02x} (roundup: 0x{:02x})".format(s.name, s.start, len(s.data), s.size, s.start+s.size, round_to_n(s.start+s.size, PAGE_SIZE)))
        #print("\tlen data: 0x{:x}".format(len(s.data)))
    
    uksect_text = Section(".text.common", s.start+len(text_bt), -1, len(text_bt), s.alignment, s.uk_name)
    uksect_text.data = text_bt
    uksect_rodata = Section(".rodata.common", s.start+len(text_bt)+len(rodata_bt), -1, len(rodata_bt), s.alignment, s.uk_name)
    uksect_rodata.data = rodata_bt
    
    return uksect_text, uksect_rodata

def process_rodata_in_text_aslr(elffile, s, maps_json_rodata, args):
    l=["liblwip", "libkvmvirtio","libukargparse","libukdebug","libnewlibm","libkvmvirtionet","libnewlibc","libvfscore","libuktimeconv","libuklibparam","libkvmfcplat", "libsqlite"]
    lib=s.name.split(".")[-1]
    if lib in l:
        
        if s.name.startswith(".text"):
            s.data = elffile.get_section_by_name(s.name).data()
        elif s.name.startswith(".rodata"):
            s.data = elffile.get_section_by_name(s.name).data()
            if '.rodata' in args.list and s.name not in args.list:
                args.list.insert(0, s.name)
    else:
        return process_rodata_in_text(elffile, s, maps_json_rodata, args)

def process_rodata_in_text(elffile, s, maps_json_rodata, args):
    
    label = s.name.split(".text.rodata.")[1]

    #print(s.name.split(".text.rodata.")[1]+ ".o(.text)")
    text_size = maps_json_rodata[label + ".o(.text)"]
    rodata_size = maps_json_rodata[label + ".o(.rodata)"]
    
    s.data = elffile.get_section_by_name(s.name).data()
    #print("- [{}] Start: 0x{:02x} (size: 0x{:02x}/0x{:02x}) End: 0x{:02x} (roundup: 0x{:02x})".format(s.name, s.start, len(s.data), s.size, s.start+s.size, round_to_n(s.start+s.size, PAGE_SIZE)))
    #print("\tSize: {} - Addr: {}".format(hex(text_size), hex(s.start+text_size)))
    #print("\tSize: {} - Addr: {}".format(hex(rodata_size), hex(s.start+s.size-rodata_size)))
    #print("\tlen data: 0x{:x}".format(len(s.data)))
    
    # Trim to get only text
    
    rodata = s.data[text_size:]
    
    #s.name = ".text." + label
    s.data = s.data[0:text_size]
    s.size = text_size
    
    if rodata_size > 0:
        #print("\tMARKER:" + str(s.data[-1]))
        uksect = Section(".rodata." + label , s.start+text_size, s.offset+text_size, rodata_size, s.alignment, s.uk_name)
        uksect.data = rodata
        return uksect

    return None

def process_data_sections(uk, all_text_section, maps_json_rodata, args):

    if args.verbose:
        print("\n-----[{}]-------".format(process_data_sections.__name__.upper()))
    addresses = list()
    new_sect = list()
    with open(uk.name, 'rb') as f:
        elffile = ELFFile(f)

        common_sect_index = -1
        for i, s in enumerate(uk.sections):

            if all_text_section and s.name.startswith(".text"):
                args.list.insert(0, s.name )

            if is_aligned and args.rodata_in_text and (".text." in s.name or "rodata" in s.name):
                
                if "text.rodata.common" in s.name:

                    text_sec, rodata_sect = process_common_text(elffile, s, maps_json_rodata)
                    new_sect.append(text_sec)
                    new_sect.append(rodata_sect)
                    addresses.append((text_sec.start, text_sec.size))
                    addresses.append((rodata_sect.start, rodata_sect.size))
                    if ".rodata" in args.list and rodata_sect.name not in args.list:
                        args.list.insert(0, rodata_sect.name)
                    if ".text.*" in args.list and text_sec.name not in args.list:
                        args.list.insert(0, text_sec.name)
                    common_sect_index = i
                else:
                    rodata_sect = None
                    if args.aslr:
                        rodata_sect = process_rodata_in_text_aslr(elffile, s, maps_json_rodata, args)
                    else:
                        rodata_sect = process_rodata_in_text(elffile, s, maps_json_rodata, args)
                    addresses.append((s.start, s.size))
                
                    if rodata_sect:
                        addresses.append((rodata_sect.start, rodata_sect.size))
                        new_sect.append(rodata_sect)
                        if '.rodata' in args.list:
                            args.list.insert(0, rodata_sect.name)

            elif s.name in args.list:
                s.data = elffile.get_section_by_name(s.name).data()
                
                # Add to list for minimize
                addresses.append((s.start, s.size))

                if args.verbose:
                    print("- [{}] Start: 0x{:02x} (size: 0x{:02x}/0x{:02x}) End: 0x{:02x} (roundup: 0x{:02x})".format(s.name, s.start, len(s.data), s.size, s.start+s.size, round_to_n(s.start+s.size, PAGE_SIZE)))

    if common_sect_index != -1:
        uk.sections.pop(common_sect_index)
    
    if len(new_sect) > 0:
        uk.sections.extend(new_sect)

    return addresses

def process_stats(same_pages, unikernels, args):
    
    #print("\n-----[{}]-------".format(process_stats.__name__.upper()))
    total_pages = 0
    for uk in unikernels:
        for s in uk.sections:
            if s.name in args.list:
                for i, p in enumerate(s.pages):
                    #if args.verbose:
                    #    print("  Page {}: 0x{:02x} - 0x{:02x} [#0: {}] ({}:{})".format(p.number, p.start, p.end, p.zeroes, uk.shortname, s.name))
                    if p.hash in same_pages:
                        m = same_pages[p.hash]
                        same = compare_pages(m[0].content, p.content, PAGE_SIZE)
                        if same:
                            same_pages[p.hash].append(p)
                        else:
                            print("- [WARNING] False positive " + str(i))
                    else:
                        same_pages[p.hash].append(p)
                    
                    total_pages += 1
    return total_pages

def process_diff(workdir, map_same_pages, args):

    print("\n-----[{}]-------".format(process_diff.__name__.upper()))
    map_distinct_pages = defaultdict(list) # used when two pages of a same section are different
    for _,v in map_same_pages.items():
        if len(v) == 1:
            map_distinct_pages[v[0].sect_name+str(v[0].number)].append(v[0])
    
    path = os.path.join(workdir, DIFF_FOLDER)
    if not os.path.exists(path):
        os.makedirs(path)

    index = 1
    for k,v in map_distinct_pages.items():
        print("{} - {}".format(index, k))
        index = index+1
        
        if len(v) > 1:

            if args.verbose:
                print("- Compare {} between {} instances".format(k, len(v)))

            dmp = dmp_module.diff_match_patch()
            diff = dmp.diff_main(v[0].instructions_string, v[1].instructions_string)
            html = dmp.diff_prettyHtml(diff)

            current_function = ""
            if args.render:
                body = ""
                for h in html.split("<br>"):
                    if "== " in h:
                        current_function = (h + "<br>").replace(";", "")
                    if "del" in h or "ins" in h:
                        body += current_function.replace("&para", "<br>")
                        body += h.replace("&para", "<br>").replace(";", "")
                        current_function = ""
                html = body
            else:
                html = html.replace("&para", "").replace(";", "")

            with open(("{}{}_page_{}_{}.html".format(path, k.replace(".", ""), v[0].number, v[1].number)), "w") as f:
                f.write(html)

def display_stats(map_same_pages, totalPages, args, totalZeroes):

    reduction = list()
    print("-----[{}]-------".format(display_stats.__name__.upper()))
    pages_sharing = 0
    pages_shared = 0
    total_frames = 0
    
    for k,v in map_same_pages.items():
        if len(v) > 1:
            pages_shared += 1
            total_frames += 1
            pages_sharing += len(v)
            reduction.append(len(v))
            #if args.verbose:
            #    print("   {}: {} -> 1".format(k[0:10], len(v)))
        else:
            total_frames += 1
            p = v[0]
            if args.verbose:
                print("   {}: {} -> Page {}: 0x{:02x}  - 0x{:02x}  [{}] ({}:{})".format(k[0:10], len(v), p.number, p.start, p.end, p.zeroes, p.uk_name, p.sect_name))
    
    print("- TOTAL PAGES: %d" % totalPages)
    print("- TOTAL PAGES SHARED: %d" % pages_shared)
    print("- TOTAL PAGES SHARING: %d" % pages_sharing)
    print("- TOTAL ZEROES PAGES: {}".format(totalZeroes))
    print("- TOTAL NO-ZEROES PAGES: {}".format(totalPages-totalZeroes))
    print("- SHARING: %.2f/100 (%d/%d)" % ((pages_sharing/totalPages) * 100, pages_sharing, totalPages))
    print("- TOTAL FRAMES: {}".format(total_frames))
    print("- TOTAL MB: {}".format((total_frames * PAGE_SIZE)/(1024*1024)))
    return reduction
def main():
    
    parser = argparse.ArgumentParser()
    parser.add_argument('-w', '--workspace',help='Workspace directory', type=str, default=WORKSPACE)
    parser.add_argument('-l','--list',      help='Sections names to consider as a list (-l sect1 sect2 ...)', nargs='+', default=SECTION_NAMES)
    parser.add_argument('-p','--pages',     help='Save pages to bin file', default=SAVE_TO_PAGE)
    parser.add_argument('-m','--minimize',  help='Minimize the size (remove leading zero to binary file)', default=False)
    parser.add_argument('-u', '--uks',      help='Unikernels to align as a list (-l uks1 uks2 ...)', nargs='+', default=UKS_INCLUDED)
    parser.add_argument('-s','--stats',     help='Stats on pages sharing', default=True)
    parser.add_argument('-v','--verbose',   help='verbose mode', default=VERBOSE)
    parser.add_argument('-d','--diff',      help='Perform diff between pages', default=DIFF)
    parser.add_argument('-r','--render',    help='view diff only in html', default=RENDER)
    parser.add_argument('-g','--get_symbols',    help='view diff only in html', default=GET_SYMBOLS)
    parser.add_argument('-a', '--aslr',     help="Use aslr (0: disabled - 1: enabled)", type=int, default=0)
    parser.add_argument('--rodata_in_text',   help="Detect rodata in text", default=DETECT_RODATA_TEXT)
    args = parser.parse_args()
    
    if args.uks != UKS_INCLUDED:
        unikernels = get_unikernels(os.path.join(args.workspace, APPS_FOLDER), args.uks, args.aslr)
        
        #unikernels=list()
        #for u in args.uks:
        #    unikernels.append(Unikernel(u))
    else:
        unikernels = get_unikernels(os.path.join(args.workspace, APPS_FOLDER), args.uks, args.aslr)

    # Create pages folder
    if args.pages and not os.path.exists(os.path.join(args.workspace,PAGE_FOLDER)):
        os.makedirs(os.path.join(args.workspace,PAGE_FOLDER))

    #filter '.text.*' in 
    all_text_section = False
    if '.text.*' in args.list:
        all_text_section = True
    
    maps_json_rodata = dict()    
    if args.rodata_in_text:
        with open("rodata_text_size.json", "r") as f:
            maps_json_rodata = json.load(f)
    
    for uk in unikernels:

        if args.get_symbols:
            get_symbols(uk)

        # Get the full folder path name for exporting pages
        path = os.path.join(args.workspace,PAGE_FOLDER, uk.shortname) + os.sep
        if args.pages and not os.path.exists(path):
            os.makedirs(path)
        
        # Process the elf file
        process_file(uk)
        
        addresses = process_data_sections(uk, all_text_section, maps_json_rodata, args)

        process_pages(uk, args, path)
    
    map_same_pages = defaultdict(list)    
    total_pages = process_stats(map_same_pages, unikernels, args)
    if args.diff:
        process_diff(args.workspace, map_same_pages, args)
    
    if args.stats:
        display_stats(map_same_pages, total_pages, args, 0)
    
if __name__ == "__main__":
    main()