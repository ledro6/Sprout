"""
Рисует выгруженные растения листом — простой растеризатор без GPU, чтобы
видеть формы там, где нет ни телефона, ни Xcode.

    python3 tool/plant-preview/render.py папка имя…

Свет сверху слева, камера чуть сверху и сбоку, как держат телефон над
столом. Кладёт sheet.png в ту же папку.
"""
import sys, numpy as np
from PIL import Image, ImageDraw
def load(path):
    V=[];C=[];N=[];F=[]
    for line in open(path):
        p=line.split()
        if not p: continue
        if p[0]=='v': V.append(list(map(float,p[1:4]))); C.append(list(map(float,p[4:7])))
        elif p[0]=='vn': N.append(list(map(float,p[1:4])))
        elif p[0]=='f': F.append([int(x.split('//')[0])-1 for x in p[1:4]])
    return np.array(V),np.array(C),np.array(N),np.array(F)
def render(path, W=360, H=420, yaw=0.5, pitch=-0.42, dist=0.9, look=0.17):
    V,C,N,F=load(path)
    cy,sy=np.cos(yaw),np.sin(yaw); cp,sp=np.cos(pitch),np.sin(pitch)
    R1=np.array([[cy,0,-sy],[0,1,0],[sy,0,cy]])
    R2=np.array([[1,0,0],[0,cp,-sp],[0,sp,cp]])
    P=(V-[0,look,0])@R1.T@R2.T; P[:,2]+=dist
    Nc=N@R1.T@R2.T
    f=1.6*H/2
    x=P[:,0]/P[:,2]*f+W/2; y=-P[:,1]/P[:,2]*f+H/2; z=P[:,2]
    light=np.array([-0.4,0.8,-0.5]); light/=np.linalg.norm(light)
    lam=np.clip(Nc@light,0,1)
    # back-face: normal facing camera (camera at origin looking +z) -> n.z<0 visible
    shade=C*(0.35+0.75*lam[:,None])
    img=np.ones((H,W,3))*np.array([0.93,0.94,0.95]); zb=np.full((H,W),1e9)
    for a,b,c in F:
        # culling by geometric normal vs view
        pa,pb,pc=P[a],P[b],P[c]
        n=np.cross(pb-pa,pc-pa)
        if np.dot(n,pa)>=0: continue
        xs=np.array([x[a],x[b],x[c]]); ys=np.array([y[a],y[b],y[c]])
        x0,x1=int(max(0,np.floor(xs.min()))),int(min(W-1,np.ceil(xs.max())))
        y0,y1=int(max(0,np.floor(ys.min()))),int(min(H-1,np.ceil(ys.max())))
        if x0>x1 or y0>y1: continue
        gx,gy=np.meshgrid(np.arange(x0,x1+1)+0.5,np.arange(y0,y1+1)+0.5)
        d=(ys[1]-ys[2])*(xs[0]-xs[2])+(xs[2]-xs[1])*(ys[0]-ys[2])
        if abs(d)<1e-12: continue
        w0=((ys[1]-ys[2])*(gx-xs[2])+(xs[2]-xs[1])*(gy-ys[2]))/d
        w1=((ys[2]-ys[0])*(gx-xs[2])+(xs[0]-xs[2])*(gy-ys[2]))/d
        w2=1-w0-w1
        m=(w0>=0)&(w1>=0)&(w2>=0)
        if not m.any(): continue
        zz=w0*z[a]+w1*z[b]+w2*z[c]
        sub=zb[y0:y1+1,x0:x1+1]
        m&=zz<sub
        if not m.any(): continue
        sub[m]=zz[m]
        col=(w0[...,None]*shade[a]+w1[...,None]*shade[b]+w2[...,None]*shade[c])
        img[y0:y1+1,x0:x1+1][m]=col[m]
    return Image.fromarray((np.clip(img,0,1)*255).astype(np.uint8))
names=sys.argv[2:]
tiles=[render(f"{sys.argv[1]}/{n}.obj") for n in names]
W,H=tiles[0].size; cols=4; rows=(len(tiles)+cols-1)//cols
sheet=Image.new('RGB',(W*cols,H*rows),'white')
dr=ImageDraw.Draw(sheet)
for i,(t,n) in enumerate(zip(tiles,names)):
    sheet.paste(t,((i%cols)*W,(i//cols)*H)); dr.text(((i%cols)*W+8,(i//cols)*H+8),n,fill='black')
sheet.save(sys.argv[1]+'/sheet.png')
