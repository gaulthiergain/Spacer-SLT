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

x1 = []
y1 = []
x2 = []
y2 = []
  
with open('dksm_output.csv','r') as csvfile:
    plots = csv.reader(csvfile, delimiter = '\t')
      
    for row in plots:
        x1.append(row[0])
        y1.append(float(row[1]))

with open('ksm_output.csv','r') as csvfile:
    plots = csv.reader(csvfile, delimiter = '\t')
      
    for row in plots:
        x2.append(row[0])
        y2.append(float(row[1]))


fig, ax = plt.subplots()
ax.xaxis.set_ticks(range(0, len(x1), 11))
fig.set_size_inches(5.4, 2.25)
plt.plot(x1, y1, label = "DKSM", linestyle='--')
plt.grid(color='#95a5a6', linestyle='--', linewidth=1, alpha=0.7, zorder=0)
plt.legend(fontsize=8, loc='best', ncol=2)

plt.plot(x2, y2, label = "KSM")
plt.xlabel("Number of pages")
plt.ylabel("Execution time (s)")
plt.legend(fontsize=8, loc='best', ncol=2)
plt.savefig("time_overhead.pdf", bbox_inches='tight')