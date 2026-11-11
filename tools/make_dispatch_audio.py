"""Original, quiet maritime feedback. Stdlib only; no external sound samples."""
from pathlib import Path
import math,random,wave,struct,json
OUT=Path(__file__).resolve().parent.parent/'assets/audio'
RATE=44100
def envelope(t,d,attack=.035):
 return min(1.,t/attack)**1.4 * min(1.,(d-t)/.15)**1.5
def write(name,d,signal):
 samples=[signal(i/RATE,d) for i in range(round(d*RATE))]
 peak=max(abs(x) for x in samples);gain=.70/max(1.,peak)
 with wave.open(str(OUT/(name+'.wav')),'wb') as f:
  f.setparams((1,2,RATE,0,'NONE','not compressed'))
  f.writeframes(b''.join(struct.pack('<h',round(max(-1.,min(1.,x*gain))*32767)) for x in samples))
 return dict(name=name,duration=d,peak=round(peak*gain,4),rms=round(math.sqrt(sum((x*gain)**2 for x in samples)/len(samples)),4))
def horn(kind):
 root=[146.83,110.,164.81][kind]
 def sample(t,d):
  breath=1+.012*math.sin(2*math.pi*3.5*t)
  body=.43*math.sin(2*math.pi*root*breath*t)+.24*math.sin(2*math.pi*root*1.5*t)
  body+=.08*math.sin(2*math.pi*root*2.0*t)+.035*math.sin(2*math.pi*root*3*t)
  return math.tanh(body*1.2)*envelope(t,d,.045)
 return sample
def seal(t,d):
 return (.28*math.sin(2*math.pi*220*t)*math.exp(-t*34)+.18*math.sin(2*math.pi*880*t)*math.exp(-t*22))*min(1,t/.004)
def chime(t,d):
 s=0
 for k,f in enumerate((587.33,739.99,880.)):
  u=t-.065*k
  if u>=0:s+=.13*math.sin(2*math.pi*f*u)*math.exp(-u*12)*min(1,u/.006)
 return s*min(1,(d-t)/.04)
if __name__=='__main__':
 results=[]
 for k,n in enumerate(('feeder','tanker','coaster')):results.append(write('dispatch_'+n,(.48,.58,.44)[k],horn(k)))
 results.append(write('dispatch_seal',.18,seal));results.append(write('dispatch_chime',.40,chime))
 (OUT/'dispatch_audio_metrics.json').write_text(json.dumps(results,indent=2))
 print(json.dumps(results))
