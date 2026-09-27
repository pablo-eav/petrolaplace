"""
Módulo Python Binding de Alto Rendimiento para root_free_reservoir_core.dll (ctypes)
Autor: Prof. Pablo Enrique Aballe Vázquez
División de Dinámica de Fluidos en Medios Porosos y Transferencia Energética

Permite invocar el motor compilado nativo en C99/x64 desde Python con latencias sub-milisegundo.
"""

import os
import sys
import ctypes
import numpy as np
import time
import matplotlib.pyplot as plt

# Definición de tipos y enumeraciones C
MODEL_RADIAL_STORAGE_SKIN = 1
MODEL_DUAL_POROSITY_WARREN_ROOT = 2
MODEL_UNCONVENTIONAL_SHALE_MFHW = 3
MODEL_INFINITE_ACTING_RADIAL = 4
MODEL_RATIONAL_FRACTION = 5

class CDouble(ctypes.Structure):
    _fields_ = [("r", ctypes.c_double), ("i", ctypes.c_double)]

class ReservoirParams(ctypes.Structure):
    _fields_ = [
        ("C_D", ctypes.c_double),
        ("S", ctypes.c_double),
        ("omega", ctypes.c_double),
        ("lambda_param", ctypes.c_double),
        ("y_eD", ctypes.c_double),
        ("S_f", ctypes.c_double)
    ]

class RootFreeReservoirDLL:
    def __init__(self, dll_path=None):
        if dll_path is None:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            # Selección de biblioteca compartida según el sistema operativo
            if sys.platform.startswith("win"):
                candidates = ["root_free_reservoir_core.dll", "libroot_free_reservoir_core.dll"]
            elif sys.platform.startswith("darwin"): # macOS
                candidates = ["libroot_free_reservoir_core.dylib", "root_free_reservoir_core.dylib", "libroot_free_reservoir_core.so"]
            else: # Linux / Unix
                candidates = ["libroot_free_reservoir_core.so", "root_free_reservoir_core.so"]
            
            for c in candidates:
                p = os.path.join(base_dir, c)
                if os.path.exists(p):
                    dll_path = p
                    break
            
            if dll_path is None or not os.path.exists(dll_path):
                expected = candidates[0] if candidates else "root_free_reservoir_core.dll"
                dll_path = os.path.join(base_dir, expected)
        
        # Si no existe en Linux o macOS, intentar autocompilación instantánea
        if not os.path.exists(dll_path) and not sys.platform.startswith("win"):
            print(f"[INFO] Compilando biblioteca nativa en primer uso para {sys.platform}...")
            if self._auto_compile_library(dll_path):
                print(f"[OK] Biblioteca nativa compilada y verificada: {os.path.basename(dll_path)}")
        
        if not os.path.exists(dll_path):
            raise FileNotFoundError(
                f"No se encontró la biblioteca compilada en: {dll_path}.\n"
                f"En Linux compile con: gcc -O3 -shared -fPIC root_free_reservoir_core.c -o libroot_free_reservoir_core.so -lm\n"
                f"En macOS compile con: clang -O3 -dynamiclib -fPIC root_free_reservoir_core.c -o libroot_free_reservoir_core.dylib -lm\n"
                f"En Windows compile con: compile_dll.bat"
            )
        
        self.dll = ctypes.CDLL(dll_path)
        self._setup_function_signatures()
        
        # Ejecutar autocomprobación de integridad
        status = self.dll.rootfree_reservoir_self_test()
        if status != 0:
            raise RuntimeError(f"Fallo en la autocomprobación Built-In-Test (BIT), código: {status}")

    @staticmethod
    def _auto_compile_library(target_path):
        """Compila automáticamente la biblioteca C99 en Linux o macOS usando el compilador del sistema."""
        import subprocess
        import shutil
        base_dir = os.path.dirname(os.path.abspath(__file__))
        c_src = os.path.join(base_dir, "root_free_reservoir_core.c")
        if not os.path.exists(c_src):
            return False
        
        if sys.platform.startswith("darwin"): # macOS (Clang / GCC)
            compiler = shutil.which("clang") or shutil.which("gcc")
            if compiler:
                cmd = [compiler, "-O3", "-dynamiclib", "-fPIC", c_src, "-o", target_path, "-lm"]
                res = subprocess.run(cmd, capture_output=True, text=True)
                return res.returncode == 0
        elif sys.platform.startswith("linux"): # Linux (GCC / Clang)
            compiler = shutil.which("gcc") or shutil.which("clang")
            if compiler:
                cmd = [compiler, "-O3", "-shared", "-fPIC", c_src, "-o", target_path, "-lm"]
                res = subprocess.run(cmd, capture_output=True, text=True)
                return res.returncode == 0
        return False

    def _setup_function_signatures(self):
        # const char* rootfree_reservoir_get_version(void)
        self.dll.rootfree_reservoir_get_version.restype = ctypes.c_char_p
        self.dll.rootfree_reservoir_get_version.argtypes = []

        # int rootfree_reservoir_self_test(void)
        self.dll.rootfree_reservoir_self_test.restype = ctypes.c_int
        self.dll.rootfree_reservoir_self_test.argtypes = []

        # int rootfree_reservoir_invert_vector(...)
        self.dll.rootfree_reservoir_invert_vector.restype = ctypes.c_int
        self.dll.rootfree_reservoir_invert_vector.argtypes = [
            ctypes.POINTER(ctypes.c_double), # t_array
            ctypes.c_int32,                  # n_points
            ctypes.c_int32,                  # model_type
            ctypes.POINTER(ReservoirParams), # params
            ctypes.c_int32,                  # M
            ctypes.POINTER(ctypes.c_double), # p_out
            ctypes.POINTER(ctypes.c_double)  # dp_out
        ]

        # int rootfree_reservoir_deconvolve(...)
        self.dll.rootfree_reservoir_deconvolve.restype = ctypes.c_int
        self.dll.rootfree_reservoir_deconvolve.argtypes = [
            ctypes.POINTER(ctypes.c_double), # t_history
            ctypes.POINTER(ctypes.c_double), # q_history
            ctypes.POINTER(ctypes.c_double), # p_measured
            ctypes.c_int32,                  # N
            ctypes.c_double,                 # lambda_reg
            ctypes.POINTER(ctypes.c_double), # g_out
            ctypes.POINTER(ctypes.c_double)  # dg_out
        ]

    def get_version(self):
        return self.dll.rootfree_reservoir_get_version().decode('utf-8')

    def invert(self, t, model_type=MODEL_RADIAL_STORAGE_SKIN, C_D=1000.0, S=2.0,
               omega=0.02, lambda_param=1e-6, y_eD=5.0, S_f=0.5, M=36):
        """
        Invierte en tiempo ultra-rápido un vector de tiempos t_D usando la DLL C99.
        Retorna: (p_array, dp_bourdet_array)
        """
        t_arr = np.ascontiguousarray(np.atleast_1d(t), dtype=np.float64)
        n = len(t_arr)
        
        p_out = np.zeros(n, dtype=np.float64)
        dp_out = np.zeros(n, dtype=np.float64)
        
        params = ReservoirParams(
            C_D=C_D, S=S, omega=omega, lambda_param=lambda_param, y_eD=y_eD, S_f=S_f
        )
        
        t_ptr = t_arr.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        p_ptr = p_out.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        dp_ptr = dp_out.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        
        status = self.dll.rootfree_reservoir_invert_vector(
            t_ptr, n, model_type, ctypes.byref(params), M, p_ptr, dp_ptr
        )
        
        if status != 0:
            raise RuntimeError(f"Error en DLL invert_vector, código: {status}")
            
        return p_out, dp_out

    def deconvolve(self, t_history, q_history, p_measured, lambda_reg=1e-3):
        """
        Desconvolución Toeplitz-Tikhonov regularizada mediante Cholesky nativo C99.
        Retorna: (g_out, dg_out)
        """
        t_arr = np.ascontiguousarray(t_history, dtype=np.float64)
        q_arr = np.ascontiguousarray(q_history, dtype=np.float64)
        p_arr = np.ascontiguousarray(p_measured, dtype=np.float64)
        N = len(t_arr)
        
        g_out = np.zeros(N, dtype=np.float64)
        dg_out = np.zeros(N, dtype=np.float64)
        
        t_ptr = t_arr.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        q_ptr = q_arr.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        p_ptr = p_arr.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        g_ptr = g_out.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        dg_ptr = dg_out.ctypes.data_as(ctypes.POINTER(ctypes.c_double))
        
        status = self.dll.rootfree_reservoir_deconvolve(
            t_ptr, q_ptr, p_ptr, N, lambda_reg, g_ptr, dg_ptr
        )
        
        if status != 0:
            raise RuntimeError(f"Error en DLL deconvolve, código: {status}")
            
        return g_out, dg_out


def ejecutar_benchmark_comparativo():
    print("=" * 70)
    print("BENCHMARK COMPARATIVO: MOTOR PYTHON vs MOTOR NATIVO C99 DLL (x64)")
    print("=" * 70)
    
    # 1. Cargar DLL
    engine_dll = RootFreeReservoirDLL()
    print(f"Versión de la DLL cargada: {engine_dll.get_version()}")
    
    # 2. Vector de tiempos (40 puntos logarítmicos)
    t_D = np.logspace(-1, 6, 40)
    
    # Benchmark Caso 1: Radial con Almacenamiento y Daño
    print("\n[1] Caso 1: Pozo Vertical con Storage (C_D=1000) y Daño (S=2.0)")
    
    # Tiempo DLL C99
    t0 = time.perf_counter()
    p_dll, dp_dll = engine_dll.invert(t_D, model_type=MODEL_RADIAL_STORAGE_SKIN, C_D=1000.0, S=2.0)
    t_dll = time.perf_counter() - t0
    
    print(f"    -> Tiempo DLL C99 (40 puntos):   {t_dll * 1000:.3f} ms ({t_dll*1e6/40:.2f} µs/punto)")
    print(f"    -> P_D inicial: {p_dll[0]:.6f}, P'_D inicial: {dp_dll[0]:.6f} (Pendiente m=1.0 pura)")
    print(f"    -> Asíntota radial final P'_D:  {dp_dll[-1]:.6f} (Teórico = 0.500000)")
    
    # Benchmark Caso 2: Doble Porosidad Warren & Root
    print("\n[2] Caso 2: Yacimiento Doble Porosidad Warren & Root (omega=0.02, lambda=1e-6)")
    t0 = time.perf_counter()
    p_dp_dll, dp_dp_dll = engine_dll.invert(
        t_D, model_type=MODEL_DUAL_POROSITY_WARREN_ROOT, C_D=500.0, S=1.5, omega=0.02, lambda_param=1e-6
    )
    t_dp_dll = time.perf_counter() - t0
    print(f"    -> Tiempo DLL C99:               {t_dp_dll * 1000:.3f} ms")
    print(f"    -> Mínimo valle Bourdet Dip:     {np.min(dp_dp_dll):.4f}")
    
    # Benchmark Caso 3: Shale Multifracturado
    print("\n[3] Caso 3: Pozo Horizontal Multifracturado en Shale (MFHW)")
    t_shale = np.logspace(-3, 3, 40)
    t0 = time.perf_counter()
    p_shale_dll, dp_shale_dll = engine_dll.invert(
        t_shale, model_type=MODEL_UNCONVENTIONAL_SHALE_MFHW, C_D=50.0, S_f=0.5, y_eD=5.0
    )
    t_shale_dll = time.perf_counter() - t0
    print(f"    -> Tiempo DLL C99:               {t_shale_dll * 1000:.3f} ms")
    
    # Benchmark Caso 4: Desconvolución Toeplitz-Tikhonov
    print("\n[4] Caso 4: Desconvolución Toeplitz-Tikhonov (N=100 muestras)")
    t_hist = np.linspace(0.1, 50.0, 100)
    q_hist = np.zeros(100)
    q_hist[t_hist < 15.0] = 100.0
    q_hist[(t_hist >= 15.0) & (t_hist < 35.0)] = 250.0
    q_hist[t_hist >= 35.0] = 180.0
    
    # Presión simulada con respuesta logarithmic drawdown y ruido gaussiano
    np.random.seed(42)
    noise = np.random.normal(0, 0.5, 100)
    p_meas = 8.5 * np.log(1.0 + t_hist) * (q_hist / 100.0) + noise
    
    t0 = time.perf_counter()
    g_rec, dg_rec = engine_dll.deconvolve(t_hist, q_hist, p_meas, lambda_reg=5e-3)
    t_dec_dll = time.perf_counter() - t0
    print(f"    -> Tiempo Desconvolución Cholesky DLL: {t_dec_dll * 1000:.4f} ms ({t_dec_dll*1e6:.1f} µs)")
    
    # Generación de figura diagnóstica de verificación
    plt.style.use('default')
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(14, 10))
    fig.patch.set_facecolor('#ffffff')
    
    # Panel 1: Pozo Vertical con Storage y Skin
    ax1.loglog(t_D, p_dll, 'b-', lw=2.5, label=r'Caída de Presión $P_D(t_D)$')
    ax1.loglog(t_D, dp_dll, 'r-', lw=2.5, label=r"Derivada Bourdet $t_D \cdot P'_D$")
    ax1.axhline(0.5, color='k', ls='--', alpha=0.7, label=r'Meseta IARF ($P^\prime_D = 0.5$)')
    ax1.set_title('Modelo 1: Pozo Vertical Storage & Skin (DLL C99)', fontsize=11, fontweight='bold', color='#123456')
    ax1.set_xlabel('Tiempo Adimensional $t_D$', fontsize=10)
    ax1.set_ylabel(r'$P_D$ y $t_D \cdot P_D^\prime$', fontsize=10)
    ax1.grid(True, which='both', ls=':', alpha=0.6)
    ax1.legend(loc='lower right', fontsize=9)
    
    # Panel 2: Doble Porosidad Warren & Root
    ax2.loglog(t_D, p_dp_dll, 'navy', lw=2.5, label=r'$P_D(t_D)$')
    ax2.loglog(t_D, dp_dp_dll, 'crimson', lw=2.5, label=r"Derivada Bourdet $t_D \cdot P'_D$")
    ax2.axhline(0.5, color='k', ls='--', alpha=0.7)
    ax2.annotate('Valle de Bourdet (Dip)\n' + r'$\omega=0.02, \lambda=10^{-6}$',
                 xy=(1e2, np.min(dp_dp_dll)), xytext=(1e1, 0.005),
                 arrowprops=dict(arrowstyle='->', color='crimson', lw=1.5),
                 fontsize=9, fontweight='bold', color='crimson')
    ax2.set_title('Modelo 2: Doble Porosidad Warren & Root (DLL C99)', fontsize=11, fontweight='bold', color='#123456')
    ax2.set_xlabel('Tiempo Adimensional $t_D$', fontsize=10)
    ax2.set_ylabel(r'$P_D$ y $t_D \cdot P_D^\prime$', fontsize=10)
    ax2.grid(True, which='both', ls=':', alpha=0.6)
    ax2.legend(loc='lower right', fontsize=9)
    
    # Panel 3: Shale Multifracturado
    ax3.loglog(t_shale, p_shale_dll, 'darkgreen', lw=2.5, label=r'$P_D(t)$')
    ax3.loglog(t_shale, dp_shale_dll, 'darkorange', lw=2.5, label=r"Derivada Bourdet $t \cdot P'$")
    # Línea de pendiente 1/2
    t_ref = np.logspace(-2, 0, 20)
    ax3.loglog(t_ref, 0.5 * np.sqrt(t_ref), 'k:', lw=2, label='Pendiente m = 0.5 (Flujo Lineal)')
    ax3.set_title('Modelo 3: Pozo Horizontal Multifracturado MFHW (DLL C99)', fontsize=11, fontweight='bold', color='#123456')
    ax3.set_xlabel('Tiempo Adimensional $t_{D}$', fontsize=10)
    ax3.set_ylabel(r'$P_D$ y $t \cdot P^\prime$', fontsize=10)
    ax3.grid(True, which='both', ls=':', alpha=0.6)
    ax3.legend(loc='lower right', fontsize=9)
    
    # Panel 4: Desconvolución Toeplitz-Tikhonov
    ax4.plot(t_hist, p_meas, 'gray', ls='None', marker='o', ms=3, alpha=0.6, label='Presión Medida con Ruido')
    ax4.plot(t_hist, g_rec, 'b-', lw=2.5, label=r'Respuesta Unitaria Reconstruida $g(t)$')
    ax4.plot(t_hist, dg_rec, 'm--', lw=2.0, label=r'Derivada Bourdet Suavizada $t \cdot g^\prime(t)$')
    ax4.set_title(f'Desconvolución Cholesky Toeplitz-Tikhonov (Latencia: {t_dec_dll*1000:.3f} ms)',
                  fontsize=11, fontweight='bold', color='#123456')
    ax4.set_xlabel('Tiempo de Adquisición (horas)', fontsize=10)
    ax4.set_ylabel('Presión / Respuesta Unitaria (psi)', fontsize=10)
    ax4.grid(True, ls=':', alpha=0.6)
    ax4.legend(loc='upper left', fontsize=9)
    
    plt.tight_layout()
    output_fig = os.path.join(os.path.dirname(os.path.abspath(__file__)), "verificacion_dll_reservoir_c99.png")
    plt.savefig(output_fig, dpi=300)
    print(f"\n[OK] Gráfica de verificación generada: {output_fig}")
    print("=" * 70)


if __name__ == "__main__":
    ejecutar_benchmark_comparativo()
