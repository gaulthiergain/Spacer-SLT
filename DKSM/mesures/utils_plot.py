import os
import argparse

WORKDIR="../results/"
FIGDIR="../figs/"

COLORS = ['#fc8d59', '#fee090', '#e34a33', '#2166ac', '#b30000', '#777777', '#fdbb84']
COLORS_ASLR = ["#fdbf6f", "#a6cee3","#b2df8a","#fb9a99","#fb9a99","#a6cee3","#cab2d6","#6a3d9a","#ffff99","#b15928"]
COLORS_DEFAULT =['#ff7f0e', '#1f77b4', '#2ca02c' , '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf']
LABELS_ORDER = ['Spacer (ksm)', 'Spacer (dksm)']
LABELS_ORDER_ASLR = ['DCE (+uksm) [ASLR]', 'Default (+uksm) [ASLR]', 'Spacer (+uksm) [ASLR]','Spacer (shm) [ASLR]']
LINES_STYLE = ['-', '--', '-.', ':']
EXT=".pdf"

def str2bool(v):
    if isinstance(v, bool):
        return v
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')

def filter_label(k, newline="\n"):
    label=""
        
    if "size" in k:
        label = "DCE"
    elif "spacer" in k:
        label = "Spacer"
    elif "normal" in k:
        label = "Default"
    
    if "dksm" in k:
        label = "" + label + newline + " (dksm)"
    else:
        label = "" + label + newline + " (ksm)"
    
    if "aslr" in k:
        label += " [ASLR]"
    
    return label

class RootFolder():
    def __init__(self, workdir):
        self.workdir = workdir
        self.subfolders = list()

    def get_subfolders(self):

        for f in os.listdir(self.workdir):
            if os.path.isdir(os.path.join(self.workdir,f)):
                self.subfolders.append(SubFolder(os.path.join(self.workdir,f)))

class SubFolder():
    def __init__(self, workdir):
        self.workdir = workdir
        self.applications = dict()

#plt.rcParams.update({'font.size': 8})