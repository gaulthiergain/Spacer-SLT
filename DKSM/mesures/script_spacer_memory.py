import numpy as np
import matplotlib.pyplot as plt
import csv

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

x = []
y1 = []
y2 = []
  
with open('mem_normal.csv','r') as csvfile:
    plots = csv.reader(csvfile, delimiter = '\t')
      
    for row in plots:
        x.append(row[0])
        y1.append(float(row[1])/1024)

with open('mem_spacer_ksm.csv','r') as csvfile:
    plots = csv.reader(csvfile, delimiter = '\t')
      
    for row in plots:
        y2.append(float(row[1])/1024)


barWidth = 0.4

x1 = [float(x) - barWidth/2 for x in x]
x2 = [float(x) + barWidth/2 for x in x]

fig, ax = plt.subplots()
fig.set_size_inches(8.26, 4.13)
plt.bar(x1, y1, label = "Default", width = barWidth)
plt.bar(x2, y2, label = "Spacer (ksm)", width = barWidth)
plt.xlabel("Number of duplicates")
plt.ylabel("Memory (MB)")
plt.xticks(range(1, len(x) + 1))
plt.legend(fontsize=8, loc='best', ncol=2)
plt.savefig("memory_usage.pdf", bbox_inches='tight')