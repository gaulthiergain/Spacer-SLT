#!/usr/bin/python3
import os
import csv
import argparse
import matplotlib.pyplot as plt
import datetime
from utils_plot import *
import statistics
FOLDER="results_snapshot/"
USE_ASLR=False

def filter_data(args, data):
    
    filtered_data = dict()
    for k,v in data.items():
        
        (x,y) = v
        x = [(a - x[0]).total_seconds() for a in x] #Duration
        
        md = statistics.mean(y)
        medi = statistics.median(y)
        print(k, end=" - mean: ")
        print(md, end=" - median: ")
        print(medi, end=" - max: ")
        print(max(y), end=" #: ")
        print(len(y))
        
        label = filter_label(k, "")
        
        if y[0] != 0:
            y[0] = 0
        
        filtered_data[label] = (x,y)
    
    return filtered_data

def save_plot(fig, args, is_double=False):
    plt.xticks()
    plt.xlabel('Time (s)')

    if is_double:
        fig.text(0.04, 0.5, 'Memory (MB)', va='center', rotation='vertical')
    else:
        plt.ylabel('Memory (MB)')
        plt.grid(color='#95a5a6', linestyle='--', linewidth=1, alpha=0.7, zorder=0)
        plt.legend()
    
    filename = os.path.join(args.result, '_'.join(args.workdir.split("/")[-3:-1]) + EXT)
    
    if EXT == ".pdf":
        plt.savefig(filename, bbox_inches='tight')
    else:
        plt.savefig(filename, dpi=200)
    plt.gcf().autofmt_xdate()
    print("Save plot in " + filename)
    if args.crop:
        os.system("pdfcrop {} {}".format(filename, filename))
    plt.clf()
    
def plot_double(args, data):
    fig, ax = plt.subplots(2, sharex=True)
    fig.set_size_inches(6.4, 3.5)
    for i, k in enumerate(LABELS_ORDER):
        (x,y) = data[k]
        ax[0].plot(x, y, label = k, linestyle = LINES_STYLE[i], zorder=3, color=COLORS_DEFAULT[i]) #color = 'b',  marker = 'o',label = "Memory usage", marker = 'x', markevery=5,)
        ax[0].grid(color='#95a5a6', linestyle='--', linewidth=1, alpha=0.7, zorder=0)
        ax[0].legend(fontsize=8, loc='best', ncol=2)
        ax[0].set_title("Vanilla", fontsize=10)
    
    for i, k in enumerate(LABELS_ORDER_ASLR):
        if k not in data:
            continue
        (x,y) = data[k]
        ax[1].plot(x, y, label = k.replace("[ASLR]", ""), linestyle = LINES_STYLE[i], zorder=3, color=COLORS_ASLR[i])
        ax[1].grid(color='#95a5a6', linestyle='--', linewidth=1, alpha=0.7, zorder=0)
        #ax[1].legend(fontsize=8, loc='lower right', ncol=2)
        ax[1].set_title("ASLR", fontsize=10)
        
    save_plot(fig, args, True)
    
def plot(args, data):

    fig, ax = plt.subplots()
    fig.set_size_inches(5.4, 2.25)
    for i, k in enumerate(LABELS_ORDER):
        (x,y) = data[k]
        plt.plot(x, y, label = k, linestyle = LINES_STYLE[i], color=COLORS_DEFAULT[i]) #color = 'b',  marker = 'o',label = "Memory usage", marker = 'x', markevery=5,)
    save_plot(fig, args)

    
def get_files(folder, data, args):

        for f in os.listdir(folder.workdir):
            
            if os.path.isdir(os.path.join(folder.workdir,f)):
                print("Ignore directory " + f)
                continue
            else:
                if "data_rollups" in f:
                    app_name = folder.workdir.split("/")[-2] + "_" + folder.workdir.split("/")[-1]
                    if not args.use_aslr and "_aslr" in app_name:
                        continue
                    data[app_name] = process_csv(os.path.join(folder.workdir,f), args)

def process_csv(filename, args):
    x = []
    y = []
  
    with open(filename,'r') as csvfile:
        lines = csv.reader(csvfile, delimiter=',')
        for i, row in enumerate(lines):
            if i == 0:
                continue
            s = datetime.datetime.strptime(row[0], "%Y-%m-%dT%H:%M:%S.0Z")
            
            x.append(s)
            y.append(int(row[1])/1024)
    if args.stop:
        x = x[:args.stop]
        y = y[:args.stop]
        
    return (x,y)
    
def main():
    parser = argparse.ArgumentParser(description='Plot memory usage (memory apps)')
    parser.add_argument('-w', '--workdir',   help='Path to workdir to analyse', type=str, default=os.path.join(WORKDIR, FOLDER))
    parser.add_argument('-r', '--result',    help='Path to folder to put png plot', type=str, default=os.path.join(FIGDIR, "mem_usage"))
    parser.add_argument('-u', '--use_aslr',  help='Use aslr', type=str2bool, nargs='?', const=True, default=USE_ASLR)
    parser.add_argument('--stop', help='Stop after x seconds', type=int)
    parser.add_argument('--ext', help='Extension (default .pdf)', type=str, default=EXT)
    parser.add_argument('--crop', help='Crop the pdf', type=str, default=True)
    args = parser.parse_args()
    
    data = dict()
    rootFolder = RootFolder(args.workdir)
    rootFolder.get_subfolders()
    
    for folder in rootFolder.subfolders:
        get_files(folder, data, args)
    
    data = filter_data(args, data)
    if args.use_aslr:
        plot_double(args, data)
    else:
        plot(args, data)
    
if __name__== "__main__":
    main()  

  
