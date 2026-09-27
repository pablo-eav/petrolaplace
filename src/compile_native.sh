#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE COMPILACIÓN NATIVA MULTIPLATAFORMA (LINUX / MACOS)
# Núcleo de Inversión Conforme y Deconvolución Root-Free en C99
# Autor: Prof. Pablo Enrique Aballe Vázquez
# ==============================================================================

set -e

OS_NAME="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================================================"
echo "  COMPILADOR NATIVO C99 - PETROLAPLACE RESERVOIR CORE"
echo "  Plataforma detectada: $OS_NAME ($(uname -m))"
echo "======================================================================"

if [ "$OS_NAME" = "Darwin" ]; then
    # macOS (Apple Silicon M1/M2/M3/M4 o Intel x86_64)
    TARGET_LIB="libroot_free_reservoir_core.dylib"
    echo "[COMPILANDO] Generando biblioteca dinámica para macOS: $TARGET_LIB..."
    clang -O3 -dynamiclib -fPIC root_free_reservoir_core.c -o "$TARGET_LIB" -lm
    echo "[OK] Compilado exitosamente con Clang."
elif [ "$OS_NAME" = "Linux" ]; then
    # GNU/Linux (Ubuntu, Debian, RedHat, CentOS, etc.)
    TARGET_LIB="libroot_free_reservoir_core.so"
    echo "[COMPILANDO] Generando biblioteca compartida para Linux: $TARGET_LIB..."
    gcc -O3 -shared -fPIC root_free_reservoir_core.c -o "$TARGET_LIB" -lm
    echo "[OK] Compilado exitosamente con GCC."
else
    echo "[ERROR] Sistema operativo no reconocido directamente por este script bash: $OS_NAME"
    exit 1
fi

echo "======================================================================"
echo "  Autocomprobación e integridad..."
python3 -c "from root_free_reservoir_dll import RootFreeReservoirDLL; core = RootFreeReservoirDLL(); print('  -> Carga nativa exitosa. Versión:', core.get_version())"
echo "======================================================================"
echo "  Listo para producción en $OS_NAME."
