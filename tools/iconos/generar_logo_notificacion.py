#!/usr/bin/env python3
"""Genera las imágenes del logo para las notificaciones a partir de
assets/icons.png, sin modificarlo.

El logo es un cuadrado con un marco dorado de esquinas redondeadas; por
fuera del marco, en las cuatro esquinas, tiene un fondo gris beige liso que
se veía como un recuadro detrás del marco. Acá se recorta con la forma del
marco (radio medido: ~110 px sobre 1024).

Salida:
  assets/notificaciones/logo_notificacion_2x1.jpg                      (1024×512, fuente)
  android/app/src/main/res/drawable-nodpi/logo_notificacion_2x1.jpg     (al expandir)
  android/app/src/main/res/drawable-nodpi/ic_logo_notificacion.png      (miniatura, esquinas transparentes)

Uso: python3 tools/iconos/generar_logo_notificacion.py  (requiere Pillow)
"""
import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

RADIO = 112        # radio de las esquinas del marco, en px del logo de 1024
SUPERMUESTREO = 4  # para suavizar el borde del recorte


def mascara_redondeada(lado, radio):
    grande = Image.new("L", (lado * SUPERMUESTREO,) * 2, 0)
    ImageDraw.Draw(grande).rounded_rectangle(
        [0, 0, lado * SUPERMUESTREO - 1, lado * SUPERMUESTREO - 1],
        radius=radio * SUPERMUESTREO, fill=255)
    return grande.resize((lado, lado), Image.LANCZOS)


def generar(raiz="."):
    src = Image.open(os.path.join(raiz, "assets/icons.png")).convert("RGB")  # solo lectura
    lado_src = src.size[0]
    logo = src.convert("RGBA")
    logo.putalpha(mascara_redondeada(lado_src, RADIO * lado_src // 1024))

    # 1. Apaisada 2:1: logo completo sobre la tela del propio logo (franja sin letras).
    W, H = 1024, 512
    fondo = src.crop((70, 70, 860, 220)).resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(22))
    fondo = ImageEnhance.Brightness(fondo).enhance(1.02)
    lado = 480
    x0, y0 = (W - lado) // 2, (H - lado) // 2
    chico = logo.resize((lado, lado), Image.LANCZOS)
    # Sombra suave con la misma forma redondeada.
    sombra = Image.new("L", (W, H), 0)
    sombra.paste(mascara_redondeada(lado, RADIO * lado // 1024), (x0 + 6, y0 + 8))
    sombra = sombra.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.35))
    fondo = Image.composite(Image.new("RGB", (W, H), (120, 100, 75)), fondo, sombra)
    fondo.paste(chico, (x0, y0), chico)

    nodpi = os.path.join(raiz, "android/app/src/main/res/drawable-nodpi")
    os.makedirs(nodpi, exist_ok=True)
    os.makedirs(os.path.join(raiz, "assets/notificaciones"), exist_ok=True)
    fondo.save(os.path.join(raiz, "assets/notificaciones/logo_notificacion_2x1.jpg"), quality=90, optimize=True)
    fondo.save(os.path.join(nodpi, "logo_notificacion_2x1.jpg"), quality=90, optimize=True)

    # 2. Miniatura cuadrada con las esquinas transparentes.
    logo.resize((256, 256), Image.LANCZOS).save(os.path.join(nodpi, "ic_logo_notificacion.png"), optimize=True)
    print("Logo de notificación generado (apaisado 1024×512 y miniatura 256 px).")


if __name__ == "__main__":
    generar(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))
