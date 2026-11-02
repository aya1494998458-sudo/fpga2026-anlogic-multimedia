from pathlib import Path
import struct
ROOT=Path(__file__).resolve().parents[1]
def make(name,w,h,top=False,bad=False):
    stride=(w*3+3)&~3
    rows=[[(x*7%256,y*3%256,(x+y)*5%256) for x in range(w)] for y in range(h)]
    bmp=bytearray(54+stride*h)
    bmp[:2]=b'BM'
    struct.pack_into('<I',bmp,2,len(bmp));struct.pack_into('<I',bmp,10,54)
    struct.pack_into('<IiiHHII',bmp,14,40,w,-h if top else h,1,32 if bad else 24,0,stride*h)
    for y in range(h):
        for x,(r,g,b) in enumerate(rows[y]):bmp[54+y*stride+x*3:54+y*stride+x*3+3]=bytes([b,g,r])
    (ROOT/'assets'/f'{name}.bmp').write_bytes(bmp)
    (ROOT/'assets'/f'{name}_bytes.hex').write_text('\n'.join(f'{v:02x}' for v in bmp),encoding='utf-8')
    if w*480>=h*640:fw,fh=640,max(2,h*640//w)
    else:fw,fh=max(2,w*480//h),480
    ox,oy=(640-fw)//2,(480-fh)//2
    sx,sy=((w-1)<<16)//(fw-1),((h-1)<<16)//(fh-1)
    pixels=[]
    for y in range(480):
        for x in range(640):
            if not(ox<=x<ox+fw and oy<=y<oy+fh):pixels.append('000000');continue
            xx,yy=(x-ox)*sx,(y-oy)*sy
            x0,y0=xx>>16,yy>>16;x1,y1=min(w-1,x0+1),min(h-1,y0+1)
            fx,fy=(xx>>8)&255,(yy>>8)&255
            rgb=[]
            for c in range(3):
                a=rows[y0][x0][c]*(256-fx)+rows[y0][x1][c]*fx
                b=rows[y1][x0][c]*(256-fx)+rows[y1][x1][c]*fx
                rgb.append((a*(256-fy)+b*fy+32768)>>16)
            pixels.append(''.join(f'{v:02x}' for v in rgb))
    (ROOT/'assets'/f'{name}_expected.hex').write_text('\n'.join(pixels),encoding='utf-8')
    return len(bmp)
if __name__=='__main__':
    for args in [('scale320',320,240),('scale640',640,480),('topdown',5,4,True),('portrait',3,7),('invalid',5,4,False,True)]:print(args[0],make(*args))
