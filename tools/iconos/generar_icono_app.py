#!/usr/bin/env python3
"""Genera las imágenes del ícono de la app a partir de assets/icons.png, sin
modificarlo. El logo ocupa casi todo el ícono, con el borde dorado justo en
el borde, para que se lean el monograma y el texto.

Android usa íconos adaptativos: fondo + frente de 108 dp, de los que el
teléfono muestra los 72 dp centrales, recortados con su máscara (cuadrado
redondeado, la de MIUI, círculo…). flutter_launcher_icons agrega un margen
(inset) del 16 % al frente, que así cubre 73,44 dp: la zona visible es el
98 % central de frente.png.

El logo va al 95 % de la zona visible y el fondo es un degradado dorado como
el bisel del marco (claro arriba a la izquierda, oscuro abajo a la derecha):
en las esquinas, donde la máscara redondea más que el logo, lo que se ve es
ese dorado, y el borde del ícono queda dorado de punta a punta. Con 95 %, la
línea dorada interior del marco entra completa en máscaras con esquinas de
hasta el 25 % del lado (MIUI, Pixel, iOS). En una máscara circular se
recortan las esquinas del marco, pero el monograma y el texto entran.

Salida (assets/iconos_app/):
  fondo.png       fondo del ícono adaptativo (degradado dorado del bisel)
  frente.png      logo con marco, centrado, con transparencia
  monocromo.png   monograma "EN" para los íconos temáticos (Android 13+)
  completo.png    ícono cuadrado opaco para iOS (logo sobre el mismo dorado)

Uso:
  python3 tools/iconos/generar_icono_app.py
  dart run flutter_launcher_icons
"""
import os
from PIL import Image, ImageDraw

RADIO = 112             # radio de las esquinas del marco del logo (px sobre 1024)
ESCALA_VISIBLE = 0.95   # logo dentro de la zona visible del ícono
ZONA_VISIBLE = 72 / 73.44  # zona visible dentro del frente (inset del 16 %)
ESCALA_FRENTE = ESCALA_VISIBLE * ZONA_VISIBLE
ESCALA_IOS = ESCALA_VISIBLE  # en iOS la imagen entera es la zona visible
ESCALA_MONOCROMO = 0.62 # monograma dentro del frente monocromo
LADO = 1024


def mascara_redondeada(lado, radio, k=4):
    m = Image.new("L", (lado * k,) * 2, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, lado * k - 1, lado * k - 1], radius=radio * k, fill=255)
    return m.resize((lado, lado), Image.LANCZOS)


def logo_recortado(src, lado):
    logo = src.convert("RGBA").resize((lado, lado), Image.LANCZOS)
    logo.putalpha(mascara_redondeada(lado, RADIO * lado // 1024))
    return logo


def dorado(src, lado):
    """Degradado diagonal con los colores del bisel del marco."""
    claro = src.getpixel((8, 512))        # bisel izquierdo (iluminado)
    oscuro = src.getpixel((512, 1016))    # bisel inferior (en sombra)
    paso = 256
    grad = Image.new("RGB", (paso, paso))
    px = grad.load()
    for y in range(paso):
        for x in range(paso):
            t = (x + y) / (2 * (paso - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(claro, oscuro))
    return grad.resize((lado, lado), Image.BICUBIC)


def centrado(base, logo):
    base = base.convert("RGBA")
    x = (base.width - logo.width) // 2
    base.paste(logo, (x, x), logo)
    return base


def generar(raiz="."):
    src = Image.open(os.path.join(raiz, "assets/icons.png")).convert("RGB")  # solo lectura
    salida = os.path.join(raiz, "assets/iconos_app")
    os.makedirs(salida, exist_ok=True)

    dorado(src, LADO).save(os.path.join(salida, "fondo.png"))

    frente = centrado(Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0)), logo_recortado(src, int(LADO * ESCALA_FRENTE)))
    frente.save(os.path.join(salida, "frente.png"))

    completo = centrado(dorado(src, LADO), logo_recortado(src, int(LADO * ESCALA_IOS)))
    completo.convert("RGB").save(os.path.join(salida, "completo.png"))

    mono_src = os.path.join(raiz, "assets/notificaciones/monograma_en.png")
    if os.path.exists(mono_src):
        mono = Image.open(mono_src).convert("RGBA")
        lado = int(LADO * ESCALA_MONOCROMO)
        mono = mono.resize((lado, lado), Image.LANCZOS)
        lienzo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
        lienzo.paste(mono, ((LADO - lado) // 2, (LADO - lado) // 2), mono)
        lienzo.save(os.path.join(salida, "monocromo.png"))
    print("Ícono de la app generado en assets/iconos_app/.")


if __name__ == "__main__":
    generar(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))
