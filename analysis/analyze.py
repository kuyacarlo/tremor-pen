import pandas as pd, numpy as np, glob, json
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
from scipy.signal import welch, sosfreqz, butter
FS=104.0
def biq(hp,f):
    w=2*np.pi*f/FS; c=np.cos(w); al=np.sin(w)/(2*0.707); a0=1+al
    if hp: b=[(1+c)/2,-(1+c),(1+c)/2]
    else:  b=[(1-c)/2,1-c,(1-c)/2]
    return np.array(b)/a0, np.array([1,-2*c/a0,(1-al)/a0])
class B:
    def __init__(s,hp,f,x0=0.0):
        s.b,s.a=biq(hp,f); s.z1=s.z2=0.0
        if not hp:  # prime LP to steady state at x0
            y=x0; s.z1=y-s.b[0]*x0; s.z2=s.b[2]*x0-s.a[2]*y; s.z1=s.b[1]*x0-s.a[1]*y+s.z2
    def run(s,x):
        y=s.b[0]*x+s.z1; s.z1=s.b[1]*x-s.a[1]*y+s.z2; s.z2=s.b[2]*x-s.a[2]*y; return y
def replay(a):
    tr=[[B(True,4),B(False,12)] for _ in range(3)]
    st=[[B(True,0.5),B(False,3)] for _ in range(3)]
    pt=ps=0.0; flag=False; cnt=0; HOLD=int(0.5*FS); out=[]; R=[]; M=[]
    for i,v in enumerate(a):
        et=es=0.0
        for k in range(3):
            y=tr[k][1].run(tr[k][0].run(v[k])); et+=y*y
            z=st[k][1].run(st[k][0].run(v[k])); es+=z*z
        pt+=0.01*(et-pt); ps+=0.01*(es-ps)
        rms=np.sqrt(pt)*1000; ratio=pt/(ps+1e-12)
        if not flag:
            cnt=cnt+1 if (ratio>3 and rms>30) else 0
            if cnt>=HOLD: flag=True; cnt=0
        else:
            cnt=cnt+1 if (ratio<1.5 or rms<20) else 0
            if cnt>=HOLD: flag=False; cnt=0
        out.append(flag); R.append(ratio); M.append(rms)
    return np.array(out),np.array(R),np.array(M)
names={'idle':'Idle','normal_writing':'Normal writing','drawing':'Drawing','fake_tremor':'Simulated tremor','fake_tremor_writing':'Simulated tremor + writing'}
order=['idle','normal_writing','drawing','fake_tremor','fake_tremor_writing']
res={}; W=int(2.5*FS)
fig,ax=plt.subplots(figsize=(7,3.6)); figr,axr=plt.subplots(figsize=(7,3.6))
for key in order:
    fn=[f for f in glob.glob(f'/mnt/user-data/uploads/{key}_raw_*.csv')][0]
    d=pd.read_csv(fn); a=d[['ax','ay','az']].values*0.061/1000
    fl,R,M=replay(a-a[:10].mean(0))
    # energy-only baseline: tremor band rms >170 mg (same smoothing)
    t=d.t_ms.values; dur=(t[-1]-t[0])/1000
    f,P=welch(a-a.mean(0),FS,nperseg=512,axis=0); P=P.sum(1); m=(f>0.5)&(f<20)
    res[key]=dict(name=names[key],rows=len(d),dur=round(dur,1),
        flagged=round(100*fl[W:].mean(),1), energy=round(100*(M[W:]>170).mean(),1),
        ratio_med=round(float(np.median(R[W:])),2), rms_med=round(float(np.median(M[W:])),1),
        peak=round(float(f[m][P[m].argmax()]),1))
    ax.semilogy(f[f<20],P[f<20],label=names[key],lw=1.2)
    axr.plot(np.arange(len(R))/FS,np.clip(R,1e-2,1e3),label=names[key],lw=1)
ax.axvspan(0.5,3,color='#9FE1CB',alpha=.35,lw=0); ax.axvspan(4,12,color='#F5C4B3',alpha=.35,lw=0)
ax.set_xlabel('Frequency (Hz)'); ax.set_ylabel('Acceleration PSD (g²/Hz)'); ax.set_title('Spectrum per condition (green: stroke band, orange: tremor band)',fontsize=9)
ax.legend(fontsize=7); fig.tight_layout(); fig.savefig('fig/spectra.png',dpi=200)
axr.set_yscale('log'); axr.axhline(3,color='k',ls='--',lw=.8); axr.axhline(1.5,color='k',ls=':',lw=.8)
axr.axvline(2.5,color='gray',lw=.6)
axr.set_xlabel('Time (s)'); axr.set_ylabel('Tremor ÷ stroke power'); axr.set_title('Detector ratio over time (dashed: start 3, dotted: stop 1.5)',fontsize=9)
axr.legend(fontsize=7,loc='upper left'); figr.tight_layout(); figr.savefig('fig/ratio.png',dpi=200)
# filter response
fig,ax=plt.subplots(figsize=(7,3.2)); ff=np.linspace(0.05,50,2000)
from scipy.signal import freqz
for lo,hi,lab,c in [(0.5,3,'Stroke band 0.5–3 Hz','#0F6E56'),(4,12,'Tremor band 4–12 Hz','#993C1D')]:
    b1,a1=biq(True,lo); b2,a2=biq(False,hi)
    _,h1=freqz(b1,a1,worN=ff,fs=FS); _,h2=freqz(b2,a2,worN=ff,fs=FS)
    ax.semilogx(ff,20*np.log10(np.abs(h1*h2)),label=lab,color=c)
ax.set_ylim(-40,3); ax.axhline(-3,color='gray',lw=.6,ls='--'); ax.set_xlabel('Frequency (Hz)'); ax.set_ylabel('Gain (dB)')
ax.set_title('Firmware band-pass filters (2nd-order HP + 2nd-order LP, fs = 104 Hz)',fontsize=9); ax.legend(fontsize=8); ax.grid(alpha=.3,which='both')
fig.tight_layout(); fig.savefig('fig/filters.png',dpi=200)
# bar chart
fig,ax=plt.subplots(figsize=(7,3.2)); x=np.arange(5)
ax.bar(x-0.2,[res[k]['energy'] for k in order],0.4,label='Energy only (>170 mg)',color='#B4B2A9')
ax.bar(x+0.2,[res[k]['flagged'] for k in order],0.4,label='Ratio detector',color='#993C1D')
ax.set_xticks(x,[names[k].replace(' + ','\n+ ') for k in order],fontsize=8); ax.set_ylabel('% of time flagged'); ax.legend(fontsize=8)
for i,k in enumerate(order):
    ax.text(i-0.2,res[k]['energy']+1,f"{res[k]['energy']:.0f}",ha='center',fontsize=7); ax.text(i+0.2,res[k]['flagged']+1,f"{res[k]['flagged']:.0f}",ha='center',fontsize=7)
fig.tight_layout(); fig.savefig('fig/compare.png',dpi=200)
# idle noise & calibration
d=pd.read_csv(glob.glob('/mnt/user-data/uploads/idle_raw_*.csv')[0]); a=d[['ax','ay','az']].values*0.061
res['idle_mag_g']=round(float(np.linalg.norm(a.mean(0))/1000),4); res['idle_std_mg']=[round(float(v),2) for v in a.std(0)]
json.dump(res,open('results.json','w'),indent=1); print(json.dumps(res,indent=1))
