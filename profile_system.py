# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Luca Valente <luca.valente@unibo.it>

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import math


def cdc(f_ratio):
    return 1 + 4*f_ratio + 4 + f_ratio

def spm(beta,rw,lemma):
    ax_beta = beta + 1
    spm_ctrl = 5
    if(lemma==3):
        return spm_ctrl + rw + ax_beta
    if(lemma==4):
        return ax_beta

def xbar(n_masters,lemma):
    if(lemma==3):
        return 2 + n_masters - 1
    if(lemma==4):
        return n_masters - 1

def main_mem(beta,er,hm):
    f_ratio = 2
    ax_beta = beta + 1
    if(hm):
        return 6 + ax_beta
    else:
        llc_time = 2 + 6 + ax_beta
        cdc_read = 1 + 4*f_ratio + 4 + f_ratio
        cdc_write = (1 + 4*f_ratio)
        llc_len = 8
        fe_ctrl = 5 + rw
        single_read =  fe_ctrl + cdc_read + 17*f_ratio + llc_len*f_ratio*2
        single_write =  fe_ctrl + cdc_write + 17*f_ratio + llc_len*f_ratio*2
        if(er):
            return llc_time + math.ceil(ax_beta / llc_len) * single_read
        else:
            return llc_time + math.ceil(ax_beta / llc_len) * ( single_read +  single_write )
        

def c_isolation(which_mem,beta,rw,hm,er):
    lemma = 3
    if(which_mem == "SPM"):
        return cdc(1) + xbar(2,lemma) + spm(beta,rw,lemma)
    elif(which_mem == "Hyper"):
        return cdc(1) + xbar(2,lemma) + main_mem(beta,er,hm)


def max_intf(which_mem,beta,rw,hm,er,lemma):
    if(which_mem == "SPM"):
        return xbar(2,lemma) + spm(beta,rw,lemma)
    elif(which_mem == "Hyper"):
        lemma = 3
        return xbar(2,lemma) + main_mem(beta,er,hm)

betas_to_plot = [ 8 , 16 , 32, 48 , 64, 128, 192, 256 ]
beta_intf = 16

targets = [ "LLC MISS REF", "LLC MISS EV" , "LLC HIT" , "SPM READ", "SPM WRITE"]
chi_to_test = [3, 4, 5, 8]

isolation = np.zeros( [len(betas_to_plot),len(targets)])
interference = np.zeros( [len(betas_to_plot),len(targets),len(chi_to_test)])


data_iso = pd.read_csv("traces_rw_1-4-7.dat", delimiter=',', sep='\n')
data_iso['TOT'] = data_iso['ACC'] + data_iso['CHAN'] 
data_3 = pd.read_csv("traces_rw_0-3-%d.dat" %(beta_intf-1), delimiter=',', sep='\n')
data_3['TOT'] = data_3['ACC'] + data_3['CHAN'] 
data_4 = pd.read_csv("traces_rw_0-4-%d.dat" %(beta_intf-1), delimiter=',', sep='\n')
data_4['TOT'] = data_4['ACC'] + data_4['CHAN'] 
data_5 = pd.read_csv("traces_rw_0-5-%d.dat" %(beta_intf-1), delimiter=',', sep='\n')
data_5['TOT'] = data_5['ACC'] + data_5['CHAN'] 
data_8 = pd.read_csv("traces_rw_0-8-%d.dat" %(beta_intf-1), delimiter=',', sep='\n')
data_8['TOT'] = data_8['ACC'] + data_8['CHAN'] 

m_isolation = np.zeros( [len(betas_to_plot),len(targets)])
m_interference = np.zeros( [len(chi_to_test),len(targets)])

for i, x in enumerate(targets):
    if("SPM" in x) :
        if("READ" in x) :
            data_temp = data_iso[(data_iso['AX_ID']>=0) & (data_iso['AX_ID']<=111)]
            m_isolation[:,3] = data_temp["TOT"].to_numpy()
            data_temp = data_3[(data_3['AX_ID']>=0) & (data_3['AX_ID']<=111)]
            m_interference[0,3] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_4[(data_4['AX_ID']>=0) & (data_4['AX_ID']<=111)]
            m_interference[1,3] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_5[(data_5['AX_ID']>=0) & (data_5['AX_ID']<=111)]
            m_interference[2,3] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_8[(data_8['AX_ID']>=0) & (data_8['AX_ID']<=111)]
            m_interference[3,3] = np.amax(data_temp["TOT"].to_numpy())
        if("WRITE" in x) :
            data_temp = data_iso[(data_iso['AX_ID']>=1000) & (data_iso['AX_ID']<=1111)]
            m_isolation[:,4] = data_temp["TOT"].to_numpy()
            data_temp = data_3[(data_3['AX_ID']>=1000) & (data_3['AX_ID']<=1111)]
            m_interference[0,4] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_4[(data_4['AX_ID']>=1000) & (data_4['AX_ID']<=1111)]
            m_interference[1,4] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_5[(data_5['AX_ID']>=1000) & (data_5['AX_ID']<=1111)]
            m_interference[2,4] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_8[(data_8['AX_ID']>=1000) & (data_8['AX_ID']<=1111)]
            m_interference[3,4] = np.amax(data_temp["TOT"].to_numpy())
    elif("LLC" in x) :
        if("MISS" in x):
            if("REF" in x):
                data_temp = data_iso[(data_iso['AX_ID']>=100000) & (data_iso['AX_ID']<=100111)]
                m_isolation[:,0] = data_temp["TOT"].to_numpy()
                data_temp = data_3[(data_3['AX_ID']>=100000) & (data_3['AX_ID']<=100111)]
                m_interference[0,0] = np.amax(data_temp["TOT"].to_numpy())
                data_temp = data_4[(data_4['AX_ID']>=100000) & (data_4['AX_ID']<=100111)]
                m_interference[1,0] = np.amax(data_temp["TOT"].to_numpy())
                data_temp = data_5[(data_5['AX_ID']>=100000) & (data_5['AX_ID']<=100111)]
                m_interference[2,0] = np.amax(data_temp["TOT"].to_numpy())
                data_temp = data_8[(data_8['AX_ID']>=100000) & (data_8['AX_ID']<=100111)]
                m_interference[3,0] = np.amax(data_temp["TOT"].to_numpy())
            if("EV" in x):
                data_temp = data_iso[(data_iso['AX_ID']>=1010000) & (data_iso['AX_ID']<=1010111)]
                m_isolation[:,1] = data_temp["TOT"].to_numpy()
                data_temp = data_3[(data_3['AX_ID']>=1010000) & (data_3['AX_ID']<=1010111)]
                m_interference[0,1] = np.amax(data_temp["TOT"].to_numpy())
                data_temp = data_4[(data_4['AX_ID']>=1010000) & (data_4['AX_ID']<=1010111)]
                m_interference[1,1] = np.amax(data_temp["TOT"].to_numpy())
                data_temp = data_5[(data_5['AX_ID']>=1010000) & (data_5['AX_ID']<=1010111)]
                m_interference[2,1] = np.amax(data_temp["TOT"].to_numpy())
                data_temp = data_8[(data_8['AX_ID']>=1010000) & (data_8['AX_ID']<=1010111)]
                m_interference[3,1] = np.amax(data_temp["TOT"].to_numpy())
        if("HIT" in x):
            data_temp = data_iso[(data_iso['AX_ID']>=110000) & (data_iso['AX_ID']<=110111)]
            m_isolation[:,2] = data_temp["TOT"].to_numpy()
            data_temp = data_3[(data_3['AX_ID']>=1000000) & (data_3['AX_ID']<=1000111)]
            m_interference[0,2] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_4[(data_4['AX_ID']>=1000000) & (data_4['AX_ID']<=1000111)]
            m_interference[1,2] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_5[(data_5['AX_ID']>=1000000) & (data_5['AX_ID']<=1000111)]
            m_interference[2,2] = np.amax(data_temp["TOT"].to_numpy())
            data_temp = data_8[(data_8['AX_ID']>=1000000) & (data_8['AX_ID']<=1000111)]
            m_interference[3,2] = np.amax(data_temp["TOT"].to_numpy())
                
            
    
for i, x in enumerate(targets):
    which_mem = "SPM"
    max_out = 4
    rwintf = 0
    if("LLC" in x):
        rwintf = 1
        which_mem = "Hyper"
        rw = 0
        if("MISS" in x):
            hm = 0
            if("EV" in x):
                er = 0
            else:
                er = 1
        else:
            hm = 1
            er = 0
            rwintf = 1
    else:
        er = 0
        if("WRITE" in x):
            rw = 0
        else:
            rw = 1
        hm = 0
    for j, y in enumerate(betas_to_plot):
        isolation[j,i] = c_isolation(which_mem,y-1,rw,hm,er)
        lemma = 4
        for k, z in enumerate(chi_to_test):
            prex = min(z,max_out+1)
            prex_oc = prex + 1
            if(which_mem=="SPM"):
                interference[j,i,k] = max_intf(which_mem,y-1,rw,hm,er,lemma)*prex + max_intf(which_mem,y-1,(rw-1),hm,er,lemma)*prex_oc*rwintf + c_isolation(which_mem,y-1,rw,hm,er)
            else:
                lemma = 3
                interference[j,i,k] = max_intf(which_mem,y-1,rw,hm,er,lemma)*prex + max_intf(which_mem,y-1,(rw-1),hm,er,lemma)*prex_oc*rwintf + c_isolation(which_mem,y-1,rw,hm,er)

figure, ax = plt.subplots(1,5)

barWidth = 0.25
b1 = np.arange(len(betas_to_plot))
b2 = [x+barWidth for x in b1]

myft = 8
fsize = 10

bar1 = ax[0].bar(b1,m_isolation[:,0],color = '#574B60', width = barWidth, ec="k", hatch='', label ='Ref')
ax[0].bar(b1,isolation[:,0]-m_isolation[:,0],bottom=m_isolation[:,0],color = 'white', width = barWidth, ec="k", hatch='', label ='Ref - UB')
bar2 = ax[0].bar(b2,m_isolation[:,1],color = '#D3D0CB', width = barWidth, ec="k", hatch='//', label ='Evict + Ref')
ax[0].bar(b2,isolation[:,1]-m_isolation[:,1],bottom=m_isolation[:,1],color = 'white', width = barWidth, ec="k", hatch='//', label ='Evict + Ref - UB')

i = 0
for rect in bar1:
    height = isolation[i,0]*1.05
    x = (isolation[i,0]-m_isolation[i,0]) * 100 / m_isolation[i,0]
    ax[0].text(rect.get_x() , height, '%.1f%%'%(x), ha='center', va='bottom',rotation=90,fontsize=fsize)
    i = i +1

i = 0
for rect in bar2:
    height = isolation[i,1]*1.05
    x = (isolation[i,1]-m_isolation[i,1]) * 100 / m_isolation[i,1]
    ax[0].text(rect.get_x() , height, '%.1f%%'%(x), ha='left', va='bottom',rotation=90,fontsize=fsize)
    i = i +1

ax[0].set_title("Isolation System Level \n R/W LLC MISS + Hyper")
ax[0].set_xticks(b2)
ax[0].set_xticklabels(betas_to_plot)
ax[0].set_xlabel("Burst Length")
ax[0].set_ylabel("Number of cycles")
ax[0].legend(loc='upper left',fontsize = myft)
ax[0].set_ylim(0,7250)

bar1 = ax[1].bar(b1,m_isolation[:,2],color = '#574B60', width = barWidth, ec="k", hatch='', label ='R/W HIT - UB')
ax[1].bar(b1,isolation[:,2]-m_isolation[:,2],bottom=m_isolation[:,2],color = 'white', width = barWidth, ec="k", hatch='', label ='R/W HIT - UB')

i = 0
for rect in bar1:
    height = isolation[i,2]*1.025
    x = (isolation[i,2]-m_isolation[i,2]) * 100 / m_isolation[i,2]
    ax[1].text(rect.get_x() , height, '%.1f%%'%(x), ha='center', va='bottom',rotation=90,fontsize=fsize)
    i = i +1

ax[1].set_title("Isolation System Level \n LLC HIT")
ax[1].set_xticks(b1)
ax[1].set_xticklabels(betas_to_plot)
ax[1].set_xlabel("Burst Length")
ax[1].legend(fontsize = myft)

bar1 = ax[2].bar(b1,m_isolation[:,3],color = '#574B60', width = barWidth, ec="k", hatch='', label ='R - UB')
ax[2].bar(b1,isolation[:,3]-m_isolation[:,3],bottom=m_isolation[:,3],color = 'white', width = barWidth, ec="k", hatch='', label ='R - UB')
bar2 = ax[2].bar(b2,m_isolation[:,4],color = '#D3D0CB', width = barWidth, ec="k", hatch='//', label ='W - UB')
ax[2].bar(b2,isolation[:,4]-m_isolation[:,4],bottom=m_isolation[:,4],color = 'white', width = barWidth, ec="k", hatch='//', label ='W - UB')
ax[2].set_ylim(0,350)

i = 0
for rect in bar1:
    height = isolation[i,3]*1.025
    x = (isolation[i,3]-m_isolation[i,3]) * 100 / m_isolation[i,3]
    ax[2].text(rect.get_x() , height, '%.1f%%'%(x), ha='center', va='bottom',rotation=90,fontsize=fsize)
    i = i +1

i = 0
for rect in bar2:
    height = isolation[i,4]*1.025
    x = (isolation[i,4]-m_isolation[i,4]) * 100 / m_isolation[i,4]
    ax[2].text(rect.get_x() , height, '%.1f%%'%(x), ha='left', va='bottom',rotation=90,fontsize=fsize)
    i = i +1

ax[2].set_title("Isolation System Level \n SPM")
ax[2].set_xticks(b1)
ax[2].set_xticklabels(betas_to_plot)
ax[2].set_xlabel("Burst Length")
ax[2].legend(fontsize = myft)

barWidth = 0.25
b1 = np.arange(len(chi_to_test))
b2 = [x+barWidth for x in b1]

index_beta = betas_to_plot.index(beta_intf)

bar1 = ax[3].bar(b1,m_interference[:,0],color = '#574B60', width = barWidth, ec="k", hatch='', label ='Ref')
ax[3].bar(b1,interference[index_beta,0,:]-m_interference[:,0],bottom=m_interference[:,0],color = 'white', width = barWidth, ec="k", hatch='', label ='Ref - UB')
bar2 = ax[3].bar(b2,m_interference[:,1],color = '#D3D0CB', width = barWidth, ec="k", hatch='//', label ='Evict + Ref')
ax[3].bar(b2,interference[index_beta,1,:]-m_interference[:,1],bottom=m_interference[:,1],color = 'white', width = barWidth, ec="k", hatch='//', label ='Evict + Ref - UB')

ax[3].set_title("Interference System Level \n R/W LLC MISS + Hyper," +r" $\chi=4$, $\beta =$ %d"%(beta_intf))
ax[3].set_xticks(b1)
ax[3].set_xticklabels(chi_to_test)
ax[3].set_xlabel(r"$\phi$")
ax[3].legend(fontsize = myft)

i = 0
for rect in bar1:
    height = interference[index_beta,0,i]*1.025
    x = (interference[index_beta,0,i]-m_interference[i,0]) * 100 / m_interference[i,0]
    ax[3].text(rect.get_x() , height, '%.1f%%'%(x), ha='left', va='bottom',rotation=90,fontsize=fsize)
    i = i +1

i = 0
for rect in bar2:
    height = interference[index_beta,1,i]*1.025
    x = (interference[index_beta,1,i]-m_interference[i,1]) * 100 / m_interference[i,1]
    ax[3].text(rect.get_x() , height, '%.1f%%'%(x), ha='left', va='bottom',rotation=90,fontsize=fsize)
    i = i +1

ax[3].set_ylim(0,interference[index_beta,1,-1]*1.25)

bar1 = ax[4].bar(b1,m_interference[:,3],color = '#574B60', width = barWidth, ec="k", hatch='', label ='R')
ax[4].bar(b1,interference[index_beta,3,:]-m_interference[:,4],bottom=m_interference[:,3],color = 'white', width = barWidth, ec="k", hatch='', label ='R - UB')
bar2 = ax[4].bar(b2,m_interference[:,4],color = '#D3D0CB', width = barWidth, ec="k", hatch='//', label ='W')
ax[4].bar(b2,interference[index_beta,4,:]-m_interference[:,4],bottom=m_interference[:,4],color = 'white', width = barWidth, ec="k", hatch='//', label ='W - UB')

i = 0
for rect in bar1:
    height = interference[index_beta,3,i]*1.025
    x = (interference[index_beta,3,i]-m_interference[i,3]) * 100 / m_interference[i,3]
    ax[4].text(rect.get_x() , height, '%.1f%%'%(x), ha='left', va='bottom',rotation=0,fontsize=fsize)
    i = i +1

i = 0
for rect in bar2:
    height = interference[index_beta,4,i]*1.025
    x = (interference[index_beta,4,i]-m_interference[i,4]) * 100 / m_interference[i,4]
    ax[4].text(rect.get_x() , height, '%.1f%%'%(x), ha='left', va='bottom',rotation=0,fontsize=fsize)
    i = i +1

ax[4].set_title("Interference Sytem Level \n SPM," +r" $\chi=4$, $\beta = $%d"%(beta_intf))
ax[4].set_xlim(-0.5,3.85)
ax[4].set_xticks(b1)
ax[4].set_xticklabels(chi_to_test)
ax[4].set_xlabel(r"$\phi$")
ax[4].legend(fontsize = myft)

# the following is not executed. WIP because interfering hits can cause eviction anyway.
if 0:
    bar1 = ax[5].bar(b1,m_interference[:,2],color = '#574B60', width = barWidth, ec="k", hatch='', label ='R/W HIT')
    ax[5].bar(b1,interference[index_beta,2,:]-m_interference[:,2],bottom=m_interference[:,2],color = 'white', width = barWidth, ec="k", hatch='', label ='R/W HIT - UB')

    i = 0
    for rect in bar1:
        height = interference[index_beta,2,i]*1.05
        x = (interference[index_beta,2,i]-m_interference[i,2]) * 100 / m_interference[i,2]
        ax[5].text(rect.get_x() , height, '%.1f%%'%(x), ha='left', va='bottom',rotation=0,fontsize=fsize)
        i = i +1

    ax[5].set_title("Interference System Level \n LLC HIT," +r" $\chi=4$,  $\beta =$ %d"%(beta_intf))
    ax[5].set_xticks(b1)
    ax[5].set_xticklabels(chi_to_test)
    ax[5].set_xlabel(r"$\phi$")
    ax[5].legend(fontsize = myft)

plt.subplots_adjust( top=0.405,
                     bottom=0.066,
                     left=0.039,
                     right=0.992,
                     hspace=0.2,
                     wspace=0.235)
plt.show()
figure.savefig('measurements_%d.pdf' %(beta_intf), bbox_inches='tight', format='pdf')
figure.savefig('measurements_%d.svg' %(beta_intf), bbox_inches='tight', format='svg')
