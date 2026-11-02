from pathlib import Path
import struct, math, wave
root=Path(__file__).resolve().parents[1]
assets=root/'assets/wav_tests'
assets.mkdir(exist_ok=True)
def chunk(tag,data):return tag+struct.pack('<I',len(data))+data+(b'\0' if len(data)&1 else b'')
def make(name,bits,channels,rate=48000,encoding=1,corrupt=False):
    values=[0,1,-1,-(1<<(bits-1)),(1<<(bits-1))-1,123,-234]
    samples=[];payload=bytearray()
    for i in range(77):
        l=values[i%len(values)];rr=values[(i+3)%len(values)] if channels==2 else l
        for v in ([l,rr] if channels==2 else [l]):payload+=int(v).to_bytes(bits//8,'little',signed=True)
        left=(l<<(24-bits))&0xffffff;right=(rr<<(24-bits))&0xffffff
        samples.append(f'{right:06x}{left:06x}')
    align=channels*(bits//8)
    fmt=struct.pack('<HHIIHHH',encoding,channels,rate,rate*align,align,bits,0)
    body=b'WAVE'+chunk(b'JUNK',b'odd')+chunk(b'fmt ',fmt)+chunk(b'LIST',b'hello')+chunk(b'data',payload)+chunk(b'LIST',b'TAIL')
    raw=b'RIFF'+struct.pack('<I',len(body))+body
    if corrupt:raw=raw[:-25] # RIFF length now exceeds actual file size.
    (assets/(name+'.wav')).write_bytes(raw)
    (assets/(name+'.hex')).write_text('\n'.join(f'{v:02x}' for v in raw),encoding='utf-8')
    (assets/(name+'_frames.hex')).write_text('\n'.join(samples),encoding='utf-8')
    return len(raw)
for name,bits,channels in [('mono16',16,1),('stereo16',16,2),('mono24',24,1),('stereo24',24,2)]:
    print(name,make(name,bits,channels))
print('bad_rate',make('bad_rate',16,2,44100))
print('bad_float',make('bad_float',24,2,48000,3))
print('truncated',make('truncated',16,2,corrupt=True))
# A normal 3-second stereo PCM music file for copying to a real TF card.
demo=root/'assets/MUSIC.WAV'
with wave.open(str(demo),'wb') as f:
    f.setnchannels(2);f.setsampwidth(2);f.setframerate(48000)
    out=bytearray();notes=[261.63,329.63,392,523.25,392,329.63]
    for i in range(48000*3):
        t=i/48000;local=t%0.5;envelope=min(1,local/0.01,(0.5-local)/0.02)
        v=round(9000*envelope*math.sin(2*math.pi*notes[int(t*2)%len(notes)]*t))
        out+=struct.pack('<hh',v,v)
    f.writeframes(out)
# A small, deliberately fragmented FAT32 fixture for concurrent BMP/WAV tests.
raw=(assets/'stereo24.wav').read_bytes()
disk=bytearray(8192)
disk[510:512]=b'\x55\xaa'
struct.pack_into('<H',disk,11,512);disk[13]=1
struct.pack_into('<H',disk,14,1);disk[16]=1
struct.pack_into('<I',disk,36,1);struct.pack_into('<I',disk,44,2)
for cluster,nxt in [(2,0xfffffff),(3,7),(7,0xfffffff),(4,8),(8,0xfffffff)]:
    struct.pack_into('<I',disk,512+cluster*4,nxt)
for index,name,cluster,size in [(0,b'PICTURE BMP',3,800),(1,b'MUSIC   WAV',4,len(raw))]:
    at=1024+index*32;disk[at:at+11]=name;disk[at+11]=0x20
    struct.pack_into('<H',disk,at+26,cluster);struct.pack_into('<I',disk,at+28,size)
picture=bytes((i*17+3)&255 for i in range(800))
disk[1536:2048]=picture[:512];disk[7*512:7*512+288]=picture[512:]
disk[2048:2560]=raw[:512];disk[8*512:8*512+len(raw)-512]=raw[512:]
(assets/'av_disk.hex').write_text('\n'.join(f'{v:02x}' for v in disk),encoding='utf-8')
