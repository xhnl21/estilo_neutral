#!/usr/bin/env python3
"""Genera las imágenes del ícono de la app a partir de assets/icons.png, sin
modificarlo, para que el marco dorado del logo se vea completo en cualquier
teléfono.

Android usa íconos adaptativos: fondo + frente de 108 dp, recortados con la
forma que elija cada fabricante (círculo, cuadrado redondeado, gota…). Solo
el círculo central de 66 dp es visible siempre. flutter_launcher_icons además
agrega un margen (inset) del 16 % al frente. Por eso el logo (recortado con la
forma de su marco) va reducido al ~68 % del frente: ≈ 50 dp, que entra
completo incluso en la máscara circular.

Salida (assets/iconos_app/):
  fondo.png       fondo del ícono adaptativo (tela del logo, desenfocada)
  frente.png      logo con marco, centrado, con transparencia
  monocromo.png   monograma "EN" para los íconos temáticos (Android 13+)
  completo.png    ícono cuadrado opaco para iOS (logo al 82 % sobre la tela)

Uso:
  python3 tools/iconos/generar_icono_app.py
  dart run flutter_launcher_icons
"""
import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

RADIO = 112             # radio de las esquinas del marco del logo (px sobre 1024)
ESCALA_FRENTE = 0.68    # logo dentro del frente adaptativo (con el inset del 16 %)
ESCALA_IOS = 0.82       # logo dentro del ícono de iOS
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


def tela(src, lado):
    t = src.crop((70, 70, 860, 220)).resize((lado, lado), Image.LANCZOS).filter(ImageFilter.GaussianBlur(26))
    return ImageEnhance.Brightness(t).enhance(1.02)


def con_sombra(base, logo, x, y):
    sombra = Image.new("L", base.size, 0)
    sombra.paste(logo.getchannel("A"), (x + 6, y + 10))
    sombra = sombra.filter(ImageFilter.GaussianBlur(16)).point(lambda v: int(v * 0.35))
    base = base.convert("RGBA")
    base.paste(Image.new("RGBA", base.size, (90, 70, 50, 255)), (0, 0), sombra)
    base.paste(logo, (x, y), logo)
    return base


def generar(raiz="."):
    src = Image.open(os.path.join(raiz, "assets/icons.png")).convert("RGB")  # solo lectura
    salida = os.path.join(raiz, "assets/iconos_app")
    os.makedirs(salida, exist_ok=True)

    tela(src, LADO).save(os.path.join(salida, "fondo.png"))

    lado = int(LADO * ESCALA_FRENTE)
    frente = con_sombra(Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0)), logo_recortado(src, lado),
                        (LADO - lado) // 2, (LADO - lado) // 2)
    frente.save(os.path.join(salida, "frente.png"))

    lado = int(LADO * ESCALA_IOS)
    completo = con_sombra(tela(src, LADO), logo_recortado(src, lado), (LADO - lado) // 2, (LADO - lado) // 2)
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
