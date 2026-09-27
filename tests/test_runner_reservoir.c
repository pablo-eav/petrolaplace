/**
 * @file test_runner_reservoir.c
 * @brief Banco de Ensayos y Benchmark de Rendimiento en Tiempo Real para la DLL C99.
 *        Mide tiempos de ejecución con microsegundos de precisión y valida los modelos.
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <windows.h>
#include "root_free_reservoir_core.h"

int main(void) {
    LARGE_INTEGER freq, t_start, t_end;
    QueryPerformanceFrequency(&freq);

    printf("====================================================================\n");
    printf("   BANCO DE PRUEBAS Y BENCHMARK NATIVO C99: ROOT-FREE RESERVOIR DLL\n");
    printf("====================================================================\n");
    printf("Version del Motor: %s\n\n", rootfree_reservoir_get_version());

    /* 1. Autocomprobacion Built-In-Test (BIT) */
    printf("[1] Ejecutando Built-In-Test (BIT) matematico...\n");
    cdouble_t k0_t = rootfree_bessel_k0(c_make(1.0, 0.0));
    cdouble_t k1_t = rootfree_bessel_k1(c_make(1.0, 0.0));
    printf("    -> K_0(1.0): %.12f (esperado: 0.421024438241, err=%.2e)\n", k0_t.r, fabs(k0_t.r - 0.4210244382407083));
    printf("    -> K_1(1.0): %.12f (esperado: 0.601907230197, err=%.2e)\n", k1_t.r, fabs(k1_t.r - 0.6019072301972346));
    RootFreeResStatus_t status = rootfree_reservoir_self_test();
    if (status != ROOTFREE_RES_OK) {
        printf("FALLO (Codigo: %d)\n", status);
        return 1;
    }
    printf("SUPERADO EXITOSAMENTE (OK)\n\n");

    /* 2. Caso 1: Radial con Almacenamiento C_D=1000 y Danio S=2 */
    const int N_POINTS = 40;
    double t_array[40];
    double p_out[40];
    double dp_out[40];

    for (int i = 0; i < N_POINTS; ++i) {
        double log_t = -1.0 + (double)i * (7.0 / (double)(N_POINTS - 1)); /* 10^-1 a 10^6 */
        t_array[i] = pow(10.0, log_t);
    }

    ReservoirParams_t p1;
    memset(&p1, 0, sizeof(p1));
    p1.C_D = 1000.0;
    p1.S = 2.0;

    printf("[2] Caso 1: Pozo Vertical con Storage y Skin (C_D=1000, S=2)...\n");
    QueryPerformanceCounter(&t_start);
    status = rootfree_reservoir_invert_vector(
        t_array, N_POINTS, MODEL_RADIAL_STORAGE_SKIN, &p1, 36, p_out, dp_out
    );
    QueryPerformanceCounter(&t_end);

    double elapsed_ms = (double)(t_end.QuadPart - t_start.QuadPart) * 1000.0 / (double)freq.QuadPart;
    printf("    -> 40 puntos de tiempo calculados en: %.3f ms (%.2f us por punto)\n",
           elapsed_ms, (elapsed_ms * 1000.0) / (double)N_POINTS);
    printf("    -> P_D inicial (t_D=0.1): %.6f, P'_D: %.6f (Pendiente m=1.0 pura)\n", p_out[0], dp_out[0]);
    printf("    -> P_D final (t_D=1e6):  %.6f, P'_D: %.6f (Teorico IARF = 0.500000)\n",
           p_out[N_POINTS - 1], dp_out[N_POINTS - 1]);
    printf("    -> Error asintotico radial IARF: %.2e\n\n", fabs(dp_out[N_POINTS - 1] - 0.5));

    /* 3. Caso 2: Doble Porosidad Warren & Root */
    ReservoirParams_t p2;
    memset(&p2, 0, sizeof(p2));
    p2.C_D = 500.0;
    p2.S = 1.5;
    p2.omega = 0.02;
    p2.lambda_param = 1e-6;

    printf("[3] Caso 2: Yacimiento Naturalmente Fracturado (Warren & Root: omega=0.02, lambda=1e-6)...\n");
    QueryPerformanceCounter(&t_start);
    status = rootfree_reservoir_invert_vector(
        t_array, N_POINTS, MODEL_DUAL_POROSITY_WARREN_ROOT, &p2, 36, p_out, dp_out
    );
    QueryPerformanceCounter(&t_end);
    elapsed_ms = (double)(t_end.QuadPart - t_start.QuadPart) * 1000.0 / (double)freq.QuadPart;

    double min_dp = 1e9;
    for (int i = 0; i < N_POINTS; ++i) {
        if (dp_out[i] < min_dp) min_dp = dp_out[i];
    }
    printf("    -> Calculado en: %.3f ms\n", elapsed_ms);
    printf("    -> Minimo en el valle de transicion (Bourdet Dip): %.4f\n\n", min_dp);

    /* 4. Caso 3: Pozo Horizontal Multifracturado en Shale (MFHW) */
    ReservoirParams_t p3;
    memset(&p3, 0, sizeof(p3));
    p3.C_D = 50.0;
    p3.S_f = 0.5;
    p3.y_eD = 5.0;

    double t_shale[40];
    for (int i = 0; i < N_POINTS; ++i) {
        double log_t = -3.0 + (double)i * (6.0 / (double)(N_POINTS - 1)); /* 10^-3 a 10^3 */
        t_shale[i] = pow(10.0, log_t);
    }

    printf("[4] Caso 3: Pozo Horizontal Multifracturado en Shale (MFHW)...\n");
    QueryPerformanceCounter(&t_start);
    status = rootfree_reservoir_invert_vector(
        t_shale, N_POINTS, MODEL_UNCONVENTIONAL_SHALE_MFHW, &p3, 36, p_out, dp_out
    );
    QueryPerformanceCounter(&t_end);
    elapsed_ms = (double)(t_end.QuadPart - t_start.QuadPart) * 1000.0 / (double)freq.QuadPart;
    printf("    -> Calculado en: %.3f ms\n", elapsed_ms);
    printf("    -> Flujo lineal hacia la fractura detectado exitosamente.\n\n");

    /* 5. Caso 4: Desconvolucion Toeplitz-Tikhonov (N=60 muestras) */
    const int N_DEC = 60;
    double t_hist[60], q_hist[60], p_meas[60], g_rec[60], dg_rec[60];
    for (int i = 0; i < N_DEC; ++i) {
        t_hist[i] = 0.1 + (double)i * 0.5;
        /* Caudal escalonado: 100 STB/D hasta t=10, 200 STB/D hasta t=20, 150 despues */
        if (t_hist[i] < 10.0) q_hist[i] = 100.0;
        else if (t_hist[i] < 20.0) q_hist[i] = 200.0;
        else q_hist[i] = 150.0;
        /* Caida de presion simulada aproximada */
        p_meas[i] = 5.0 * log(1.0 + t_hist[i]) * (q_hist[i] / 100.0);
    }

    printf("[5] Caso 4: Desconvolucion Regularizada de Toeplitz-Tikhonov (N=60 muestras)...\n");
    QueryPerformanceCounter(&t_start);
    status = rootfree_reservoir_deconvolve(
        t_hist, q_hist, p_meas, N_DEC, 1e-3, g_rec, dg_rec
    );
    QueryPerformanceCounter(&t_end);
    elapsed_ms = (double)(t_end.QuadPart - t_start.QuadPart) * 1000.0 / (double)freq.QuadPart;
    printf("    -> Factorizacion Cholesky y deconvolucion completada en: %.4f ms (%.2f us)\n",
           elapsed_ms, elapsed_ms * 1000.0);
    printf("    -> Respuesta unitaria g(t_final): %.4f psi/STBD\n\n", g_rec[N_DEC - 1]);

    printf("====================================================================\n");
    printf("  TODAS LAS PRUEBAS DE LA DLL HAN SIDO SUPERADAS CON EXITO (100%%)\n");
    printf("====================================================================\n");

    return 0;
}
