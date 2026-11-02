"""Convert integer PCM WAV to 48kHz/16-bit mono or stereo. No MP3 decoder.
This is file preparation only; playback and analysis run in FPGA RTL.
"""
from pathlib import Path
import argparse, wave, struct, json
p=argparse.ArgumentParser()
p.add_argument('input',type=Path);p.add_argument('output',type=Path)
a=p.parse_args()
if a.output.exists():raise SystemExit('Output exists; refusing to overwrite')
with wave.open(str(a.input),'rb') as f:
    channels=f.getnchannels();width=f.getsampwidth();rate=f.getframerate();count=f.getnframes()
    if channels not in (1,2) or width not in (2,3) or f.getcomptype()!='NONE':
        raise SystemExit('Requires 16/24-bit integer PCM WAV, mono or stereo')
    if count==0 or not 4000<=rate<=192000:raise SystemExit('Unsupported rate or empty WAV')
    data=f.readframes(count)
def sample(i,ch):
    pos=(min(i,count-1)*channels+ch)*width
    return int.from_bytes(data[pos:pos+width],'little',signed=True)>>(8 if width==3 else 0)
out_count=(count*48000+rate-1)//rate
with wave.open(str(a.output),'wb') as out:
    out.setnchannels(channels);out.setsampwidth(2);out.setframerate(48000)
    block=bytearray()
    for j in range(out_count):
        i,frac=divmod(j*rate,48000)
        for ch in range(channels):
            v=(sample(i,ch)*(48000-frac)+sample(i+1,ch)*frac+24000)//48000
            block+=struct.pack('<h',max(-32768,min(32767,v)))
        if len(block)>=16384:out.writeframesraw(block);block.clear()
    out.writeframes(block)
print(json.dumps({'output':str(a.output),'rate':48000,'bits':16,'channels':channels,'frames':out_count,'seconds':out_count/48000}))
