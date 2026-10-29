"""Deterministic tileable technical PBR maps; original local assets, no external generators."""
import numpy as np,math,struct,zlib,pathlib
N=1024
Y,X=np.mgrid[0:N,0:N].astype(np.float32)/N
BASE=pathlib.Path(__file__).resolve().parents[2]/'assets/textures/coffeehouse_pbr'
BASE.mkdir(parents=True,exist_ok=True)
def png(path,a):
 a=np.clip(a*255,0,255).astype(np.uint8)
 if a.ndim==2:a=np.repeat(a[...,None],3,axis=2)
 h,w,c=a.shape
 def chunk(k,data):return struct.pack('!I',len(data))+k+data+struct.pack('!I',zlib.crc32(k+data)&0xffffffff)
 raw=b''.join(b'\x00'+a[row].tobytes() for row in range(h))
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,6))+chunk(b'IEND',b''))
def noise(seed,freqs):
 rng=np.random.default_rng(seed);field=np.zeros_like(X)
 total=0
 for octave,f in enumerate(freqs):
  amp=.52**octave
  for j in range(5):
   kx=int(rng.integers(max(1,f//2),f+1));ky=int(rng.integers(max(1,f//2),f+1))
   if j%2:kx=-kx
   field+=amp*np.sin(math.tau*(kx*X+ky*Y)+rng.random()*math.tau)/5
  total+=amp
 field=field/total
 return .5+field*.7
def normal(height,tile_meters):
 dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*tile_meters/N)
 dy=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*tile_meters/N)
 out=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1);out/=np.linalg.norm(out,axis=-1,keepdims=True)
 return out*.5+.5
def write(name,rgb,rough,height,meters):
 png(BASE/(name+'_albedo.png'),rgb);png(BASE/(name+'_roughness.png'),rough);png(BASE/(name+'_normal.png'),normal(height,meters))
 print('PBR_READY',name)
low=noise(12,[1,3,8]);mid=noise(34,[8,21,64]);fine=noise(82,[127,227])
# Shallow hammered marks on oxidised copper, with restrained fine scuffing.
cells=86;u=X*cells;v=Y*cells;ix=np.floor(u);iy=np.floor(v);best=np.ones_like(X)*10
for ox in [-1,0,1]:
 for oy in [-1,0,1]:
  cx=ix+ox;cy=iy+oy
  jx=np.mod(np.sin(cx*127.1+cy*311.7)*43758.5453,1);jy=np.mod(np.sin(cx*269.5+cy*183.3)*18363.734,1)
  best=np.minimum(best,(u-cx-.2-.6*jx)**2+(v-cy-.2-.6*jy)**2)
dent=np.exp(-best*7)
oxide=np.clip((low-.59)*5,0,.55)
rgb=np.array([.61,.355,.215])[None,None,:]*(.94+(mid-.5)[...,None]*.20)
rgb=rgb*(1-oxide[...,None])+np.array([.23,.265,.205])[None,None,:]*oxide[...,None]
scratches=np.exp(-np.abs(np.sin(math.tau*(Y*193+low*.3)))*240)*(mid>.53)
rgb+=scratches[...,None]*.035
write('hammered_copper',rgb,.70+(low-.5)*.14+oxide*.14+dent*.020,-dent*.00010+(fine-.5)*.000012,.65)
# Seasoned cast iron; broad colour is almost black, fine casting pores carry the detail.
iron=np.array([.17,.18,.175])[None,None,:]*(.90+(mid-.5)[...,None]*.34)
write('cast_iron',iron,.81+(mid-.5)*.17,(fine-.5)*.000025+(mid-.5)*.00004,.5)
# Honed warm marble, fine veins instead of polished plastic.
warp=(low-.5)*2+(mid-.5)*.30
vein=np.exp(-np.abs(np.sin(math.tau*(X*3+Y+warp)))*42)
vein2=np.exp(-np.abs(np.sin(math.tau*(X*7-Y*2+warp*.6)))*100)
marble=np.array([.72,.69,.62])[None,None,:]*(.98+(mid-.5)[...,None]*.06)
marble-=vein[...,None]*np.array([.14,.13,.11])[None,None,:]+vein2[...,None]*.025
write('honed_marble',marble,.54+(mid-.5)*.12,(fine-.5)*.000006,.9)
# Old lime plaster: fine trowel relief and small mottling, no giant dark blotches.
plaster=np.array([.59,.52,.425])[None,None,:]*(1+(low-.5)[...,None]*.10+(mid-.5)[...,None]*.055)
write('lime_plaster',plaster,.92+(mid-.5)*.06,(mid-.5)*.00020+(fine-.5)*.00007,1.1)
# Fine satin variation used with the existing scanned wood albedo/normal maps.
png(BASE/'worn_wood_roughness.png',.69+(low-.5)*.13+(mid-.5)*.08)
