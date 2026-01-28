#!/usr/bin/python3
import sys
import argparse
import logging

from ukManager import UkManager
from utils import CustomFormatter, logger

WORKSPACE   = "/home/gain/unikraft/"
LIBS_NAME   = 'dict_libs.json'
LIBS_NAME_ASLR = 'dict_libs_aslr.json'

LOC_COUNTER = 0x10b000
#LOC_COUNTER = 0x200000 #for go
DCE_ALONE   = False
USE_SNAPSHOT= False #True when used with snapshot (run checker)
LINK        = True
AGGREGATE   = True
GROUP       = False
COPY_OBJS   = True
COMPACT     = True
USE_ID      = -1

UKS_INCLUDED = ["lib-helloworld", "lib-hanoi"]

def str2bool(v):
    if isinstance(v, bool):
        return v
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')

def main():

    parser = argparse.ArgumentParser(description='Aligner')
    parser.add_argument('-w', '--workspace',     help='Workspace Directory', type=str, default=WORKSPACE)
    parser.add_argument('-l', '--loc',           help='Location counter', type=int, default=LOC_COUNTER)
    parser.add_argument('-d', '--dce',           help='Apply DCE on standalone lib', type=str2bool, nargs='?', const=True, default=DCE_ALONE)
    parser.add_argument('-r', '--rel',           help='Relink with the new mapping', type=str2bool, nargs='?', const=True, default=LINK)
    parser.add_argument('-v', '--verbose',       help='Verbose', type=str2bool, nargs='?', const=True, default=True)
    parser.add_argument('-u', '--uks',           help='Unikernels to align as a list (-l uks1 uks2 ...)', nargs='+', default=UKS_INCLUDED)
    parser.add_argument('-g', '--group',         help='Group common libraries to an aggregated section', type=str2bool, nargs='?', const=True, default=GROUP)
    parser.add_argument('-o', '--copy_objs',     help="Copy object files to keep consistency", type=str2bool, nargs='?', const=True, default=COPY_OBJS)
    parser.add_argument('-c', '--compact',       help="Compact sections", type=str2bool, nargs='?', const=True, default=COMPACT)
    
    parser.add_argument('--aggregate',           help="Aggregate rodata with text in a common sections", type=int, default=AGGREGATE)
    parser.add_argument('--use-id',              help="Add id to app name (sqlite1, sqlite2)", type=int, default=USE_ID)
    parser.add_argument('--relink-only',         help="Relink only", type=str2bool, nargs='?', const=True, default=False)
    parser.add_argument('--aslr',                help="Use aslr (0: disabled - 1: fixed indirection table - 2: with ASLR support)", type=int, default=0)
    parser.add_argument('--aslr_map',            help="Use a map of rodata for aslr (increase the sharing)", type=str2bool, nargs='?', const=True, default=True)
    parser.add_argument('--aslr_same_mapping',   help='Use same mapping than normal uks (libs order)', type=str2bool, nargs='?', const=True, default=True)
    parser.add_argument('--usego',               help='usego', type=str2bool, nargs='?', const=True, default=False)
    parser.add_argument('--rewrite',             help='rewrite all sections', type=str2bool, nargs='?', const=True, default=False)
    parser.add_argument('--snapshot',            help='align for snapshoting', type=str2bool, nargs='?', const=True, default=USE_SNAPSHOT)
    args = parser.parse_args()
  
    if args.aslr == 1:
        args.aslr = 2
        args.loc += 0x1000
        args.group = False
        
    if args.snapshot:
        args.group = False

    if args.verbose:
        logger.setLevel(logging.DEBUG)
        ch = logging.StreamHandler()
        ch.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.ERROR)
        ch = logging.StreamHandler()
        ch.setLevel(logging.ERROR)

    # create console handler with a higher log level
    ch.setFormatter(CustomFormatter())
    logger.addHandler(ch)

    ukManager = UkManager(args)
    ukManager.process_folder()
    ukManager.process_maps()

    if ukManager.copy_objs:
        ukManager.copy_all_objs()
        
    if args.relink_only:
        ukManager.relink_only()
        sys.exit(0)

    ukManager.update_link_file()
    
    #if ukManager.aslr > 0:
    #    ukManager.binary_rewrite()

if __name__ == '__main__':
    main()
