#!/usr/bin/python3
import os
import re
import csv
import argparse
import statistics
import numpy as np 
import matplotlib.pyplot as plt
import datetime
from collections import defaultdict
from utils_plot import *
FOLDER="results_tlb/"
FILTER="different_cores/"
KEY="seconds time elapsed"

MERGE=True
KEEP_ONLY=["dns", "lambda", "matrix", "nginx", "hanoi", "sqlite"]
USE_ASLR=False

def filter_app(txtfile):
    app_name = txtfile.split("/")[-1].split("_")[0]
    if "aslr" in txtfile:
        return  app_name + "_aslr"
    return app_name

def process_file(txtfile, data, args, use_aslr=False):
    
    app = filter_app(txtfile)
    label = filter_label(txtfile, "")
    
    if not use_aslr and "_aslr" in txtfile:
        return
    
    if use_aslr and "aslr" not in txtfile:
        return
    
    if "firecracker" not in txtfile: 
        txtfile = txtfile.replace("uksm_on_different_cores", "uksm_off_different_cores")
    print(txtfile)
    
    if args.datakey == "faults":
        data[app + " " + label] = read_txt_regex(txtfile, args)
    else:
        data[app + " " + label] = read_txt(txtfile, args)

def listdirs(rootdir, data, args, use_aslr=False):
    for it in os.scandir(rootdir):
        if it.is_dir():
            listdirs(it, data, args, use_aslr)
        if args.filter in it.path:
            process_file(it.path, data, args, use_aslr)
            
def get_suffix_label(datakey):
    
    label='Number of {} '.format(datakey)
    suffix="_{}".format(datakey.replace("-", "_"))
    if "time" in datakey:
        label='Total execution time [s]'
        suffix="_elapsed_time"
    elif "VMM" in datakey:
        label='Restore time [us]'
    elif "TLB" in datakey:
        label='Number of TLB misses'
    
    return (suffix,label)

def barplot(ax, data, n_bars, bar_width, colors, single_width, args, use_log=False, legend=True, label=None):
    
    bars = []
    std_error = 0
    for i, (name, values) in enumerate(data.items()):
        x_offset = (i - n_bars / 2) * bar_width + bar_width / 2
        
        if args.yerr:
            std_error = np.std(values, ddof=1) / np.sqrt(len(values))

        for x, y in enumerate(values):
            if std_error == 0:
                bar = ax.bar(x + x_offset, y, width=bar_width * single_width, color=colors[i % len(colors)], zorder=3, log=use_log, capsize=2)
            else:
                bar = ax.bar(x + x_offset, y, width=bar_width * single_width, color=colors[i % len(colors)], yerr=std_error, zorder=3, log=use_log, capsize=2)
            
        bars.append(bar[0])
    
    if legend:
        ax.legend(bars, ','.join(data.keys()).replace("[ASLR]", "").split(","), fontsize=7, ncol=2)
    
    if label != None:
        ax.set_title(label, fontsize=10)

def save_plot(fig, all_apps, args, is_double=False):
    
    custom_apps=["dns", "hanoi", "computePi", "matrix", "nginx", "sqlite"]
    
    suffix, label = get_suffix_label(args.datakey)
    plt.xticks(np.arange(len(custom_apps)), custom_apps) #, rotation='-45')
    plt.xticks(fontsize=9)
    
    if is_double:
        fig.text(0.04, 0.5, label, va='center', rotation='vertical')
        suffix += "_double"
    else:
        plt.ylabel(label)
        plt.xlabel("Unikernels")
        plt.grid(color='#95a5a6', linestyle='--', linewidth=1, axis='y', alpha=0.7, zorder=0)
    
    if "snapshot" in args.workdir:
        suffix += "_snapshot"
    
    filename = os.path.join(args.result, args.filter.replace("/", "") + suffix + ".pdf")
    filename = filename.replace(" ", "_").lower()
    if EXT == ".pdf":
        plt.savefig(filename, bbox_inches='tight')
    else:
        plt.savefig(filename, dpi=200)
    plt.gcf().autofmt_xdate()
    
    print("Save plot in " + filename)
    if args.crop:
        os.system("pdfcrop {} {}".format(filename, filename))
    plt.clf()
    
def extract_data(data, i, ax, total_width, single_width, args, label1, label2, colors, legend=True):
    data_short, data_long = defaultdict(list), defaultdict(list)
    for key, value in data.items():
        for v in value:
            if v < 4:
                data_short[key].append(v)
            else:
                data_long[key].append(v)
                
    print("Short-lived: {}".format(len(data_short)))
    print("Long-lived: {}".format(len(data_long)))
    
    n_bars = len(data)
    bar_width = total_width / n_bars
    
                
    barplot(ax[i][0], data_short, n_bars, bar_width, colors, single_width, args, True, legend, label1)
    ax[i][0].grid(color='#95a5a6', linestyle='--', linewidth=1, axis='y', alpha=0.7, zorder=0)
    barplot(ax[i][1], data_long, n_bars, bar_width, colors , single_width, args, False, legend, label2)
    ax[i][1].grid(color='#95a5a6', linestyle='--', linewidth=1, axis='y', alpha=0.7, zorder=0)
    
    
def quad_plot(data, data_aslr, all_apps, args, total_width=0.8, single_width=1, legend=True):
    
    fig, ax = plt.subplots(2, 2)
    fig.set_size_inches(6.4, 3.95)
    
    extract_data(data, 0, ax, total_width, single_width, args, "Short-lived", "Long-lived", COLORS_DEFAULT)
    extract_data(data_aslr, 1, ax, total_width, single_width, args, "", "", COLORS)
    
    suffix, label = get_suffix_label(args.datakey)

    
    filename = os.path.join(args.result, args.filter.replace("/", "") + suffix + ".pdf")
    if EXT == ".pdf":
        plt.savefig(filename, bbox_inches='tight')
    else:
        plt.savefig(filename, dpi=200)
    plt.gcf().autofmt_xdate()
    print("Save plot in " + filename)
    if args.crop:
        os.system("pdfcrop {} {}".format(filename, filename))
    plt.clf()
    
    return
    
    

def double_plot(data, data_aslr, all_apps, args, total_width=0.8, single_width=1, legend=True):
    
    fig, ax = plt.subplots(2, sharex=True)
    fig.set_size_inches(6.4, 3.95)

    n_bars = len(data)
    bar_width = total_width / n_bars
    
    use_log = False
    if "TLB" in args.datakey or "instructions" in args.datakey or "cycles" in args.datakey or "time" in args.datakey or "user" in args.datakey or "sys" in args.datakey:
        use_log = True
    
    barplot(ax[0], data, n_bars, bar_width, COLORS_DEFAULT, single_width, args, use_log, legend, "Vanilla")
    ax[0].grid(color='#95a5a6', linestyle='--', linewidth=1, axis='y', alpha=0.7, zorder=0)
    barplot(ax[1], data_aslr, n_bars, bar_width, COLORS , single_width, args, use_log, legend, "ASLR")
    ax[1].grid(color='#95a5a6', linestyle='--', linewidth=1, axis='y', alpha=0.7, zorder=0)
    save_plot(fig, all_apps, args, True)
    

def plot(data, all_apps, args, colors, total_width=0.8, single_width=1, legend=True):
    
    fig, ax = plt.subplots()
    fig.set_size_inches(6.4, 2.95)
    if colors is None:
         colors = plt.rcParams['axes.prop_cycle'].by_key()['color']

    n_bars = len(data)
    bar_width = total_width / n_bars

    use_log = False
    if "TLB" in args.datakey or "time" in args.datakey or "user" in args.datakey or "sys" in args.datakey:
        use_log = True
    
    barplot(ax, data, n_bars, bar_width, colors, single_width, args, use_log, legend)
    save_plot(fig, all_apps, args)

def read_txt_regex(filepath, args):
    
    lst_mean = list()
    f_regex= r"([0-9]+)\s+" + "{}".format(args.datakey)
    with open(filepath, 'r') as f:
        content = f.read()
        content = content.replace(",", "")
        matches = re.findall(f_regex, content)
        for match in matches:
           lst_mean.insert(0,float(match))
    
    return lst_mean
                
def read_txt(filepath, args):

    lst_mean = list()
    with open(filepath) as file:
        for line in file:
            line = line.strip()
            if args.datakey in line:
                word = line.split(args.datakey)[0].replace(",","")
                if "seconds" in args.datakey:
                    lst_mean.insert(0,float(word))
                elif "user" in args.datakey or "sys" in args.datakey:
                    print(float(word.split(" ")[0])/1000)
                    lst_mean.insert(0,float(word.split(" ")[0])/1000)
                elif "VMM" in args.datakey:
                    f_regex= r"VMM action took ([0-9]+) us"
                    match = re.search(f_regex, line)
                    lst_mean.insert(0,int(match[1]))
                elif "resident set size" in args.datakey:
                    f_regex= r"Maximum resident set size \(kbytes\):\s([0-9]+)"
                    match = re.search(f_regex, line)
                    lst_mean.insert(0,int(match[1]))
                elif "CPU" in args.datakey:
                    f_regex= r"Percent of CPU this job got:\s([0-9]+)%"
                    match = re.search(f_regex, line)
                    lst_mean.insert(0,int(match[1]))
                else:
                    lst_mean.insert(0,int(word))
    
    return lst_mean

def write_to_file(args, data, prefix_aslr=""):
    filename = os.path.join(args.workdir, "merged", "merge_{}_{}{}.csv".format(args.filter.replace("/", ""), args.datakey.replace(" ", "_"), prefix_aslr))
    print("File written to: " + filename)
    with open(filename, 'w') as f:
        for k,v in sorted(data.items()):
            f.write(k + ";")
            f.write(str(statistics.mean(v)) + ";")
            f.write(str(statistics.median(v)) + ";")
            f.write(str(statistics.stdev(v)) + ";")
            f.write(str(len(v)) + "\n")

def read_filter_data(args, apps_keep, prefix_aslr=""):
    
    all_apps = list()
    data = defaultdict(list)
    filename = os.path.join(args.workdir, "merged", "merge_{}_{}{}.csv".format(args.filter.replace("/", ""), args.datakey.replace(" ", "_"), prefix_aslr))
    
    print("File read from: " + filename)
    with open(filename, 'r') as f:
        #read line by line
        for line in f:
            label, mean, median, variance, occurences = line.strip("\n").split(";")
            
            app_name, label = label.split(" ", 1)

            app_name = app_name.replace("lib-", "").replace("-perf", "")
            if app_name not in apps_keep:
                continue
            
            if app_name not in all_apps:
                all_apps.append(app_name)
            data[label].append(float(mean))

    return (all_apps, data)

def main():
    parser = argparse.ArgumentParser(description='Plot memory usage (instances)')
    parser.add_argument('-w', '--workdir',  help='Path to json workdir to analyse', type=str, default=os.path.join(WORKDIR, FOLDER))
    parser.add_argument('-f', '--filter',  help='Filter to analyse experience type', type=str, default=FILTER)
    parser.add_argument('-r', '--result',   help='Path to folder to put png plot', type=str, default=FIGDIR)
    parser.add_argument('-d', '--datakey', help='Data key to plot', type=str, default=KEY)
    parser.add_argument('-p', '--plot',      help='Plot',type=str2bool, nargs='?', const=True, default=True)
    parser.add_argument('-m', '--merge',     help='Merge', type=str2bool, nargs='?', const=True, default=MERGE)
    
    parser.add_argument('--use_aslr', help='Skip aslr lines', type=str2bool, nargs='?', const=True, default=USE_ASLR)
    parser.add_argument('--yerr', help='Use error bars', type=str2bool, nargs='?', const=True, default=False)
    parser.add_argument('--crop', help='Crop the pdf', type=str2bool, nargs='?', const=True, default=True)
    args = parser.parse_args()
    
    data=dict()
    data_aslr=dict()
    
    if "time" in args.datakey:
        args.datakey = "seconds time elapsed"
        
    if "rss" in args.datakey:
        args.datakey = "Maximum resident set size"
        args.workdir = args.workdir.replace("results_tlb", "results_perf")
        
    if "cpu" in args.datakey:
        args.datakey = "Percent of CPU this job got"
        args.workdir = args.workdir.replace("results_tlb", "results_perf")
    
    apps_keep = list()
    for k in KEEP_ONLY:
        apps_keep.append(k)
        apps_keep.append(k + "_aslr")
    
    if args.merge:
        listdirs(args.workdir, data, args)
        write_to_file(args, data)
        
        if args.use_aslr:
            listdirs(args.workdir, data_aslr, args, True)
            write_to_file(args, data_aslr, "_aslr")
       
        #for k,v in sorted(data.items()):
        #   print("{}; {}".format(k, v))
    if args.plot:
        all_apps, data = read_filter_data(args, apps_keep)
        if args.use_aslr:
            all_apps_aslr, data_aslr = read_filter_data(args, apps_keep, "_aslr")
            double_plot(data, data_aslr, all_apps, args)
        else:
            plot(data, all_apps, args, COLORS)
        
    
if __name__== "__main__":
    main()  

  