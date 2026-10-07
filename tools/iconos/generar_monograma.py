#!/usr/bin/env python3
"""Genera el ícono chico de las notificaciones (monograma "EN") a partir del
logo assets/icons.png, sin modificarlo.

El logo es un render 3D: no se puede recortar la silueta automáticamente, así
que el monograma está TRAZADO A MANO sobre él (coordenadas del logo de
1024 px) con trazos gruesos (x1.4, para que se lea a 24 px).

Salida:
  assets/notificaciones/monograma_en.png         (fuente, 1024 px, blanco)
  android/app/src/main/res/drawable-*/ic_notificacion_en.png  (24 a 96 px)

Uso: python3 tools/iconos/generar_monograma.py  (requiere Pillow)
"""
import os
from PIL import Image, ImageDraw
K=4  # escala de dibujo
X0,Y0,X1,Y1=280,225,790,605
def P(x,y): return ((x-X0)*K,(y-Y0)*K)
def catmull(pts, n=24):
    out=[]
    pts=[pts[0]]+pts+[pts[-1]]
    for i in range(1,len(pts)-2):
        p0,p1,p2,p3=pts[i-1],pts[i],pts[i+1],pts[i+2]
        for t in [j/n for j in range(n)]:
            t2,t3=t*t,t*t*t
            out.append(tuple(0.5*((2*p1[k])+(-p0[k]+p2[k])*t+(2*p0[k]-5*p1[k]+4*p2[k]-p3[k])*t2+(-p0[k]+3*p1[k]-3*p2[k]+p3[k])*t3) for k in (0,1)))
    out.append(pts[-2]); return out
def trazo(d, pts, ancho, curva=True, punta_ini=False):
    q=catmull(pts) if curva else pts
    if not curva:  # recta densa
        (ax,ay),(bx,by)=q; q=[(ax+(bx-ax)*t/60, ay+(by-ay)*t/60) for t in range(61)]
    n=len(q)
    for i,(x,y) in enumerate(q):
        w=ancho
        if punta_ini: w=ancho*min(1,0.15+i/(n*0.18))
        X,Y=P(x,y); r=w*K/2
        d.ellipse([X-r,Y-r,X+r,Y+r], fill=255)
def dibujar():
    m=Image.new('L',((X1-X0)*K,(Y1-Y0)*K),0); d=ImageDraw.Draw(m)
    # Arco exterior ("C"), con punta abajo a la izquierda
    trazo(d,[(318,480),(312,440),(312,385),(323,330),(352,288),(398,265),(450,258),(505,262)],24,punta_ini=True)
    # Bucle interior ("e"), desde la punta izquierda hasta la base de la N
    trazo(d,[(364,400),(376,358),(400,327),(437,313),(474,318),(497,338),(500,368),(484,393),(450,410),(408,425),(372,445),(352,475),(350,510),(363,535),(392,550),(435,555),(478,550),(515,530),(538,500),(545,470)],28,punta_ini=True)
    # N: palo izquierdo, diagonal y palo derecho
    trazo(d,[(545,262),(545,475)],30,curva=False)
    trazo(d,[(556,272),(722,535)],28,curva=False)
    trazo(d,[(745,258),(745,555)],30,curva=False)
    trazo(d,[(722,535),(733,560),(745,555)],28)
    return m

GROSOR = 1.4
DENSIDADES = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}

def generar(raiz="."):
    base = trazo
    globals()["trazo"] = lambda d, pts, ancho, **kw: base(d, pts, ancho * GROSOR, **kw)
    try:
        m = dibujar()
    finally:
        globals()["trazo"] = base
    m = m.crop(m.getbbox())
    lado = int(max(m.size) * 1.16)  # margen del 8% por lado (zona segura)
    alfa = Image.new("L", (lado, lado), 0)
    alfa.paste(m, ((lado - m.size[0]) // 2, (lado - m.size[1]) // 2))

    def blanco(px):
        a = alfa.resize((px, px), Image.LANCZOS)
        img = Image.new("RGBA", (px, px), (255, 255, 255, 0))
        img.putalpha(a)
        return img

    os.makedirs(os.path.join(raiz, "assets/notificaciones"), exist_ok=True)
    blanco(1024).save(os.path.join(raiz, "assets/notificaciones/monograma_en.png"))
    for dpi, px in DENSIDADES.items():
        carpeta = os.path.join(raiz, f"android/app/src/main/res/drawable-{dpi}")
        os.makedirs(carpeta, exist_ok=True)
        blanco(px).save(os.path.join(carpeta, "ic_notificacion_en.png"), optimize=True)
    print("Monograma generado:", ", ".join(f"{d} {p}px" for d, p in DENSIDADES.items()))

if __name__ == "__main__":
    generar(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))
