#!/usr/bin/env python3
"""Extrae los errores de la salida de un paso de script.sh y los agrega a
script/log_script.txt, ordenados para analizarlos.

Uso (lo llama script.sh):
  python3 script/extraer_errores.py <paso> <código de salida> <salida.txt> <log>

Separa:
  FALLOS        lo que hace fallar el paso: tests en [E], excepciones de
                Flutter, errores de flutter analyze, de Gradle/Kotlin.
  ADVERTENCIAS  lo que no lo hace fallar: avisos de analyze y de Gradle.
  REGISTRADOS   errores y advertencias que la app escribe con Logger
                durante los tests (❌ [ERROR], ⚠️ [WARNING]). Muchos son
                esperados (el test los provoca a propósito); se agrupan
                por mensaje, con cuántas veces aparecieron y en qué tests.

De las trazas se quitan los frames de Flutter, Dart y del runner de tests:
quedan los del proyecto.
"""
import os
import re
import sys
from collections import OrderedDict

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
PROGRESO = re.compile(r"^\d\d:\d\d \+\d+(?: ~\d+)?(?: -(\d+))?: (.*?)\s*$")
TIMESTAMP = re.compile(r"^\[\d{4}-\d\d-\d\dT[\d:.]+\] ")
FRAME = re.compile(r"^\s*#\d+\s")
FRAME_AJENO = re.compile(
    r"package:(flutter|flutter_test|test_api|test_core|stack_trace|matcher|bloc|flutter_bloc|provider)/|"
    r"\(dart:|dart:async|dart:core|dart:isolate"
)
LOGGER = re.compile(r"(❌ \[ERROR\]|⚠️ \[WARNING\]|🔥 \[FATAL\])")
ANALYZE = re.compile(r"^\s*(error|warning|info) • ")
GRADLE_FALLO = re.compile(r"^(FAILURE:|BUILD FAILED|\* What went wrong:|e: |Execution failed|Error: |ERROR: )")
GRADLE_AVISO = re.compile(r"(?i)^(w: |warning:|.*\bdeprecated\b|.*please migrate your plugin)")
TESTS_FALLIDOS = re.compile(r"Some tests failed|Test failed|Failed to load")


RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")) + os.sep


def limpiar(linea):
    """Sin colores ANSI y con rutas relativas a la raíz del proyecto."""
    return ANSI.sub("", linea.rstrip("\n")).replace("\r", "").replace("file://" + RAIZ, "").replace(RAIZ, "")


def filtrar_frames(lineas):
    """Quita los frames ajenos al proyecto y deja una nota con cuántos."""
    salida, omitidos = [], 0
    for l in lineas:
        if FRAME.match(l) and FRAME_AJENO.search(l):
            omitidos += 1
            continue
        if l.strip() == "<asynchronous suspension>":
            continue
        salida.append(l)
    if omitidos:
        salida.append(f"      (… {omitidos} frames de Flutter/Dart omitidos)")
    return salida


def es_continuacion(linea):
    return bool(
        linea.startswith("   └─")
        or linea.startswith("  ")
        or FRAME.match(linea)
        or linea.strip() == "<asynchronous suspension>"
    )


def analizar(lineas):
    fallos, avisos = [], []
    registrados = OrderedDict()  # clave -> {"bloque", "veces", "tests"}
    test_actual = ""
    i = 0
    while i < len(lineas):
        l = lineas[i]
        m = PROGRESO.match(l)
        if m:
            nombre = m.group(2)
            if nombre.endswith("[E]"):
                # Test fallido: su detalle sigue hasta la próxima línea de progreso.
                bloque = [f"TEST FALLIDO: {nombre[:-3].strip()}"]
                i += 1
                while i < len(lineas) and not PROGRESO.match(lineas[i]):
                    bloque.append(lineas[i])
                    i += 1
                fallos.append(filtrar_frames(bloque))
                continue
            if not nombre.startswith("loading "):
                test_actual = nombre
            i += 1
            continue

        if "══╡ EXCEPTION CAUGHT" in l:
            bloque = [f"[en: {test_actual}]" if test_actual else "", l]
            i += 1
            while i < len(lineas):
                bloque.append(lineas[i])
                if lineas[i].startswith("════════"):
                    i += 1
                    break
                i += 1
            fallos.append(filtrar_frames([b for b in bloque if b]))
            continue

        if LOGGER.search(l):
            bloque = [TIMESTAMP.sub("", l)]
            i += 1
            while i < len(lineas) and lineas[i].strip() and es_continuacion(lineas[i]) and not PROGRESO.match(lineas[i]):
                bloque.append(lineas[i])
                i += 1
            bloque = filtrar_frames(bloque)
            # Agrupa por mensaje y causa (sin la traza, que cambia por test).
            clave = "\n".join(b for b in bloque if not FRAME.match(b) and "frames de Flutter" not in b)
            r = registrados.setdefault(clave, {"bloque": bloque, "veces": 0, "tests": []})
            r["veces"] += 1
            if test_actual and test_actual not in r["tests"]:
                r["tests"].append(test_actual)
            continue

        a = ANALYZE.match(l)
        if a:
            (fallos if a.group(1) == "error" else avisos).append([l.strip()])
            i += 1
            continue

        if GRADLE_FALLO.match(l):
            bloque = [l]
            i += 1
            while i < len(lineas) and lineas[i].strip() and not GRADLE_FALLO.match(lineas[i]):
                bloque.append(lineas[i])
                i += 1
            fallos.append(bloque)
            continue

        if TESTS_FALLIDOS.search(l):
            fallos.append([l.strip()])
        elif GRADLE_AVISO.match(l.strip()):
            avisos.append([l.strip()])
        i += 1
    return fallos, avisos, registrados


def main():
    paso, codigo, origen, destino = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
    with open(origen, encoding="utf-8", errors="replace") as f:
        lineas = [limpiar(l) for l in f]
    fallos, avisos, registrados = analizar(lineas)

    # Sin fallos reconocidos pero el comando falló: las últimas líneas.
    if codigo != 0 and not fallos:
        fallos.append(["(No se reconoció el error; últimas 40 líneas de la salida:)"] + lineas[-40:])

    out = []
    estado = "OK" if codigo == 0 else f"FALLÓ (código {codigo})"
    out.append("=" * 78)
    out.append(f"PASO: {paso} — {estado}")
    out.append(f"  fallos: {len(fallos)} · advertencias: {len(avisos)} · "
               f"registrados por la app: {sum(r['veces'] for r in registrados.values())} "
               f"({len(registrados)} distintos)")
    out.append("=" * 78)

    if fallos:
        out.append("\n--- FALLOS ---")
        for n, b in enumerate(fallos, 1):
            out.append(f"\n[{n}]")
            out.extend(b)
    if avisos:
        out.append("\n--- ADVERTENCIAS ---")
        vistos = set()
        for b in avisos:
            t = "\n".join(b)
            if t not in vistos:
                vistos.add(t)
                out.append(t)
    if registrados:
        out.append("\n--- REGISTRADOS POR LA APP (Logger; no hacen fallar el paso) ---")
        for n, r in enumerate(sorted(registrados.values(), key=lambda r: -r["veces"]), 1):
            out.append(f"\n[{n}] {r['veces']} {'vez' if r['veces'] == 1 else 'veces'}")
            out.extend(r["bloque"])
            if r["tests"]:
                muestra = r["tests"][:5]
                out.append("  en tests:")
                out.extend(f"    - {t}" for t in muestra)
                if len(r["tests"]) > 5:
                    out.append(f"    … y {len(r['tests']) - 5} más")
    if not (fallos or avisos or registrados):
        out.append("Sin errores.")
    out.append("")

    with open(destino, "a", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
