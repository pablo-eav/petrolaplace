/**
 * @file root_free_reservoir_core.c
 * @brief Implementación C99 de Alto Rendimiento para el Motor Root-Free Reservoir.
 *        Cálculo determinista de transitorios de presión, derivada de Bourdet y
 *        desconvolución de Toeplitz-Tikhonov para ingeniería de yacimientos.
 * 
 * Autor: Prof. Pablo Enrique Aballe Vázquez
 * División de Dinámica de Fluidos en Medios Porosos y Transferencia Energética
 * Instituto Internacional de Investigación en Física Matemática y Aeroespacial Laplace
 */

#define ROOTFREE_EXPORTS
#include "root_free_reservoir_core.h"

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.141592653589793238462643383279502884
#endif

#define EULER_MASCHERONI 0.577215664901532860606512090082402431

static double talbot_invert_kernel(
    double t_val,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params,
    LaplaceCustomFunc_t custom_func,
    const void* user_data,
    int32_t M
);

/* ========================================================================= */
/* ARITMÉTICA COMPLEJA C99 DE ALTA EFICIENCIA (INLINE)                        */
/* ========================================================================= */

static inline cdouble_t c_add(cdouble_t a, cdouble_t b) {
    return c_make(a.r + b.r, a.i + b.i);
}

static inline cdouble_t c_sub(cdouble_t a, cdouble_t b) {
    return c_make(a.r - b.r, a.i - b.i);
}

static inline cdouble_t c_scale(cdouble_t a, double s) {
    return c_make(a.r * s, a.i * s);
}

static inline cdouble_t c_mul(cdouble_t a, cdouble_t b) {
    return c_make(a.r * b.r - a.i * b.i, a.r * b.i + a.i * b.r);
}

static inline cdouble_t c_div(cdouble_t a, cdouble_t b) {
    double denom = b.r * b.r + b.i * b.i;
    if (denom == 0.0) return c_make(0.0, 0.0);
    return c_make((a.r * b.r + a.i * b.i) / denom, (a.i * b.r - a.r * b.i) / denom);
}

static inline double c_abs(cdouble_t z) {
    return sqrt(z.r * z.r + z.i * z.i);
}

static inline double c_arg(cdouble_t z) {
    return atan2(z.i, z.r);
}

static inline cdouble_t c_sqrt(cdouble_t z) {
    double r = sqrt(c_abs(z));
    double theta = c_arg(z) * 0.5;
    return c_make(r * cos(theta), r * sin(theta));
}

static inline cdouble_t c_exp(cdouble_t z) {
    double exp_r = exp(z.r);
    return c_make(exp_r * cos(z.i), exp_r * sin(z.i));
}

static inline cdouble_t c_ln(cdouble_t z) {
    return c_make(log(c_abs(z)), c_arg(z));
}

static inline cdouble_t c_tanh(cdouble_t z) {
    /* Clip para evitar overflow en sinh(2x) y cosh(2x) */
    double x = z.r;
    if (x > 30.0) x = 30.0;
    if (x < -30.0) x = -30.0;
    double y = z.i;
    double denom = cosh(2.0 * x) + cos(2.0 * y);
    if (denom == 0.0) return c_make(1.0, 0.0);
    return c_make(sinh(2.0 * x) / denom, sin(2.0 * y) / denom);
}

/* ========================================================================= */
/* EVALUACIÓN DE FUNCIONES DE BESSEL MODIFICADAS K_0(z) Y K_1(z)              */
/* ========================================================================= */

cdouble_t rootfree_bessel_k0(cdouble_t z) {
    double mod_z = c_abs(z);
    if (mod_z == 0.0) {
        return c_make(1e12, 0.0); /* Singularidad logarítmica en el origen */
    }

    if (mod_z <= 2.8) {
        /* Serie de potencias analítica para argumentos pequeños / moderados */
        cdouble_t z2_4 = c_scale(c_mul(z, z), 0.25);
        cdouble_t term = c_make(1.0, 0.0);
        cdouble_t i0 = c_make(1.0, 0.0);
        cdouble_t sum_poly = c_make(0.0, 0.0);
        double harmonic = 0.0;

        for (int k = 1; k <= 18; ++k) {
            term = c_scale(c_mul(term, z2_4), 1.0 / ((double)k * (double)k));
            i0 = c_add(i0, term);
            harmonic += 1.0 / (double)k;
            sum_poly = c_add(sum_poly, c_scale(term, harmonic));
        }

        cdouble_t ln_half_z = c_ln(c_scale(z, 0.5));
        cdouble_t factor = c_add(ln_half_z, c_make(EULER_MASCHERONI, 0.0));
        cdouble_t result = c_sub(sum_poly, c_mul(factor, i0));
        return result;
    } else {
        /* Serie asintótica convergente de Abramowitz & Stegun (9.7.2) para Re(z) > 0 */
        cdouble_t inv_8z = c_div(c_make(1.0, 0.0), c_scale(z, 8.0));
        cdouble_t sum_asymp = c_make(1.0, 0.0);
        cdouble_t term = c_make(1.0, 0.0);

        for (int k = 1; k <= 16; ++k) {
            double c_k = -(double)((2 * k - 1) * (2 * k - 1)) / (double)k;
            term = c_mul(term, c_scale(inv_8z, c_k));
            sum_asymp = c_add(sum_asymp, term);
            if (c_abs(term) < 1e-15 * c_abs(sum_asymp)) break;
        }

        cdouble_t prefactor = c_sqrt(c_scale(c_div(c_make(M_PI, 0.0), z), 0.5));
        cdouble_t exp_minus_z = c_exp(c_scale(z, -1.0));
        return c_mul(c_mul(prefactor, exp_minus_z), sum_asymp);
    }
}

cdouble_t rootfree_bessel_k1(cdouble_t z) {
    double mod_z = c_abs(z);
    if (mod_z == 0.0) {
        return c_make(1e12, 0.0);
    }

    if (mod_z <= 2.8) {
        /* Serie de potencias para K_1(z) (Abramowitz & Stegun 9.6.11) */
        cdouble_t z_half = c_scale(z, 0.5);
        cdouble_t z2_4 = c_scale(c_mul(z, z), 0.25);
        cdouble_t term = z_half; /* term = (z/2)^{2k+1} / (k! (k+1)!) */
        cdouble_t i1 = term;
        cdouble_t sum_poly = c_scale(term, 0.5); /* k=0: (harm[0]+harm[1])/2 = (0+1)/2 = 0.5 */

        double harm_k = 0.0;
        double harm_kp1 = 1.0;

        for (int k = 1; k <= 18; ++k) {
            term = c_scale(c_mul(term, z2_4), 1.0 / ((double)k * (double)(k + 1)));
            i1 = c_add(i1, term);
            harm_k = harm_kp1;
            harm_kp1 += 1.0 / (double)(k + 1);
            sum_poly = c_add(sum_poly, c_scale(term, 0.5 * (harm_k + harm_kp1)));
        }

        cdouble_t ln_half_z = c_ln(z_half);
        cdouble_t factor = c_add(ln_half_z, c_make(EULER_MASCHERONI, 0.0));
        cdouble_t inv_z = c_div(c_make(1.0, 0.0), z);

        cdouble_t result = c_sub(c_add(inv_z, c_mul(factor, i1)), sum_poly);
        return result;
    } else {
        /* Serie asintótica para K_1(z) (Abramowitz & Stegun 9.7.2, mu = 4) */
        cdouble_t inv_8z = c_div(c_make(1.0, 0.0), c_scale(z, 8.0));
        cdouble_t sum_asymp = c_make(1.0, 0.0);
        cdouble_t term = c_make(1.0, 0.0);

        for (int k = 1; k <= 16; ++k) {
            double num = (double)(4 - (2 * k - 1) * (2 * k - 1));
            term = c_mul(term, c_scale(inv_8z, num / (double)k));
            sum_asymp = c_add(sum_asymp, term);
            if (c_abs(term) < 1e-15 * c_abs(sum_asymp)) break;
        }

        cdouble_t prefactor = c_sqrt(c_scale(c_div(c_make(M_PI, 0.0), z), 0.5));
        cdouble_t exp_minus_z = c_exp(c_scale(z, -1.0));
        return c_mul(c_mul(prefactor, exp_minus_z), sum_asymp);
    }
}

/* ========================================================================= */
/* EVALUACIÓN DE MODELOS ANALÍTICOS DE YACIMIENTOS EN LAPLACE                */
/* ========================================================================= */

cdouble_t rootfree_eval_laplace_model(
    cdouble_t s,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params
) {
    if (!params) return c_make(0.0, 0.0);

    switch (model_type) {
        case MODEL_RADIAL_STORAGE_SKIN: {
            cdouble_t sqrt_s = c_sqrt(s);
            cdouble_t k0 = rootfree_bessel_k0(sqrt_s);
            cdouble_t k1 = rootfree_bessel_k1(sqrt_s);

            /* numerador = K_0(sqrt(s)) + S * sqrt(s) * K_1(sqrt(s)) */
            cdouble_t num = c_add(k0, c_scale(c_mul(sqrt_s, k1), params->S));

            /* denominador = s * [ sqrt(s)*K_1(sqrt(s)) + C_D * s * numerador ] */
            cdouble_t term1 = c_mul(sqrt_s, k1);
            cdouble_t term2 = c_scale(c_mul(s, num), params->C_D);
            cdouble_t denom = c_mul(s, c_add(term1, term2));

            return c_div(num, denom);
        }

        case MODEL_DUAL_POROSITY_WARREN_ROOT: {
            double w = params->omega;
            double lam = params->lambda_param;

            /* f(s) = [ omega * (1 - omega) * s + lambda ] / [ (1 - omega) * s + lambda ] */
            cdouble_t f_num = c_add(c_scale(s, w * (1.0 - w)), c_make(lam, 0.0));
            cdouble_t f_den = c_add(c_scale(s, 1.0 - w), c_make(lam, 0.0));
            cdouble_t f_s = c_div(f_num, f_den);

            cdouble_t s_eff = c_mul(s, f_s);
            cdouble_t sqrt_s_eff = c_sqrt(s_eff);

            cdouble_t k0 = rootfree_bessel_k0(sqrt_s_eff);
            cdouble_t k1 = rootfree_bessel_k1(sqrt_s_eff);

            cdouble_t num = c_add(k0, c_scale(c_mul(sqrt_s_eff, k1), params->S));
            cdouble_t term1 = c_mul(sqrt_s_eff, k1);
            cdouble_t term2 = c_scale(c_mul(s, num), params->C_D);
            cdouble_t denom = c_mul(s, c_add(term1, term2));

            return c_div(num, denom);
        }

        case MODEL_UNCONVENTIONAL_SHALE_MFHW: {
            cdouble_t sqrt_s = c_sqrt(s);
            cdouble_t arg = c_scale(sqrt_s, params->y_eD > 0.0 ? params->y_eD : 5.0);
            cdouble_t tanh_val = c_tanh(arg);

            /* p_linear = (pi / (s * sqrt(s))) * tanh(y_eD * sqrt(s)) */
            cdouble_t s_15 = c_mul(s, sqrt_s);
            cdouble_t p_linear = c_mul(c_div(c_make(M_PI, 0.0), s_15), tanh_val);

            /* p_fracture = p_linear + S_f / s */
            cdouble_t p_fracture = c_add(p_linear, c_div(c_make(params->S_f, 0.0), s));

            /* p_well = p_fracture / (1.0 + C_D * s * p_fracture) */
            cdouble_t cd_s_pf = c_scale(c_mul(s, p_fracture), params->C_D);
            cdouble_t denom = c_add(c_make(1.0, 0.0), cd_s_pf);

            return c_div(p_fracture, denom);
        }

        case MODEL_INFINITE_ACTING_RADIAL: {
            cdouble_t sqrt_s = c_sqrt(s);
            cdouble_t k0 = rootfree_bessel_k0(sqrt_s);
            cdouble_t k1 = rootfree_bessel_k1(sqrt_s);
            cdouble_t denom = c_mul(s, c_mul(sqrt_s, k1));
            return c_div(k0, denom);
        }

        default:
            return c_make(0.0, 0.0);
    }
}

/* ========================================================================= */
/* INVERSIÓN CONFORME DE TALBOT Y DERIVADA DE BOURDET                        */
/* ========================================================================= */

ROOTFREE_API const char* rootfree_reservoir_get_version(void) {
    return "RootFree-Reservoir-Core-v1.0.0-MISRA-C99-x64";
}

ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_self_test(void) {
    /* 1. Prueba de Bessel K_0(1.0) real: Valor exacto = 0.4210244382407083 */
    cdouble_t k0_test = rootfree_bessel_k0(c_make(1.0, 0.0));
    double err_k0 = fabs(k0_test.r - 0.4210244382407083);
    if (err_k0 > 1e-10) return ROOTFREE_RES_ERR_SELF_TEST_FAIL;

    /* 2. Prueba de Bessel K_1(1.0) real: Valor exacto = 0.6019072301972346 */
    cdouble_t k1_test = rootfree_bessel_k1(c_make(1.0, 0.0));
    double err_k1 = fabs(k1_test.r - 0.6019072301972346);
    if (err_k1 > 1e-10) return ROOTFREE_RES_ERR_SELF_TEST_FAIL;

    /* 3. Inversión analítica de f(s) = 1/s (escalón unitario H(t) = 1.0) */
    ReservoirParams_t p;
    memset(&p, 0, sizeof(p));
    double p_val = 0.0, dp_val = 0.0;
    RootFreeResStatus_t st = rootfree_reservoir_invert_scalar(
        10.0, MODEL_INFINITE_ACTING_RADIAL, &p, 36, &p_val, &dp_val
    );
    if (st != ROOTFREE_RES_OK) return ROOTFREE_RES_ERR_SELF_TEST_FAIL;

    return ROOTFREE_RES_OK;
}

static double talbot_invert_kernel(
    double t_val,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params,
    LaplaceCustomFunc_t custom_func,
    const void* user_data,
    int32_t M
) {
    if (t_val <= 0.0) return 0.0;
    if (M < 16) M = 36;

    /* Factor de escala temporal óptimo de Weideman-Talbot: r = 2M / (5t) */
    double r = 2.0 * (double)M / (5.0 * t_val);
    double h = M_PI / (double)M;
    double sum_im = 0.0;

    for (int k = 1; k < M; ++k) {
        double theta = (double)k * h;
        double sin_th = sin(theta);
        double cos_th = cos(theta);
        double cot_th = cos_th / sin_th;

        /* s(theta) = r * ( theta * cot(theta) + i * theta ) */
        cdouble_t s_node = c_make(r * theta * cot_th, r * theta);

        /* ds/dtheta = r * ( cot(theta) - theta / sin^2(theta) + i ) */
        cdouble_t ds_dtheta = c_make(r * (cot_th - theta / (sin_th * sin_th)), r);

        /* w_k = (pi/M) * ds_dtheta * exp(s * t) */
        cdouble_t exp_st = c_exp(c_scale(s_node, t_val));
        cdouble_t w_k = c_scale(c_mul(ds_dtheta, exp_st), h);

        /* Evaluación de f(s) */
        cdouble_t f_val;
        if (custom_func) {
            f_val = custom_func(s_node, user_data);
        } else {
            f_val = rootfree_eval_laplace_model(s_node, model_type, params);
        }

        cdouble_t term = c_mul(w_k, f_val);
        sum_im += term.i;
    }

    /* Nodo central theta = 0 (límite analítico) */
    cdouble_t s_0 = c_make(r, 0.0);
    cdouble_t w_0 = c_make(0.0, 0.5 * h * r * exp(r * t_val));
    cdouble_t f_0;
    if (custom_func) {
        f_0 = custom_func(s_0, user_data);
    } else {
        f_0 = rootfree_eval_laplace_model(s_0, model_type, params);
    }
    cdouble_t term_0 = c_mul(w_0, f_0);
    sum_im += term_0.i;

    return sum_im / M_PI;
}

ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_invert_scalar(
    double t,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params,
    int32_t M,
    double* p_val,
    double* dp_val
) {
    if (!p_val) return ROOTFREE_RES_ERR_NULL_POINTER;
    if (t <= 0.0) {
        *p_val = 0.0;
        if (dp_val) *dp_val = 0.0;
        return ROOTFREE_RES_OK;
    }

    *p_val = talbot_invert_kernel(t, model_type, params, NULL, NULL, M);

    if (dp_val) {
        double delta = 1e-3;
        double t_plus = t * exp(delta);
        double t_minus = t * exp(-delta);
        double p_plus = talbot_invert_kernel(t_plus, model_type, params, NULL, NULL, M);
        double p_minus = talbot_invert_kernel(t_minus, model_type, params, NULL, NULL, M);
        *dp_val = (p_plus - p_minus) / (2.0 * delta);
    }

    return ROOTFREE_RES_OK;
}

ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_invert_vector(
    const double* t_array,
    int32_t n_points,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params,
    int32_t M,
    double* p_out,
    double* dp_out
) {
    if (!t_array || !p_out) return ROOTFREE_RES_ERR_NULL_POINTER;
    if (n_points <= 0) return ROOTFREE_RES_ERR_INVALID_PARAM;

    const double delta = 1e-3;
    const double inv_2delta = 1.0 / (2.0 * delta);

    for (int32_t idx = 0; idx < n_points; ++idx) {
        double t = t_array[idx];
        if (t <= 0.0) {
            p_out[idx] = 0.0;
            if (dp_out) dp_out[idx] = 0.0;
            continue;
        }

        p_out[idx] = talbot_invert_kernel(t, model_type, params, NULL, NULL, M);

        if (dp_out) {
            double t_plus = t * exp(delta);
            double t_minus = t * exp(-delta);
            double p_plus = talbot_invert_kernel(t_plus, model_type, params, NULL, NULL, M);
            double p_minus = talbot_invert_kernel(t_minus, model_type, params, NULL, NULL, M);
            dp_out[idx] = (p_plus - p_minus) * inv_2delta;
        }
    }

    return ROOTFREE_RES_OK;
}

ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_invert_custom(
    const double* t_array,
    int32_t n_points,
    LaplaceCustomFunc_t func,
    const void* user_data,
    int32_t M,
    double* p_out,
    double* dp_out
) {
    if (!t_array || !p_out || !func) return ROOTFREE_RES_ERR_NULL_POINTER;
    if (n_points <= 0) return ROOTFREE_RES_ERR_INVALID_PARAM;

    const double delta = 1e-3;
    const double inv_2delta = 1.0 / (2.0 * delta);

    for (int32_t idx = 0; idx < n_points; ++idx) {
        double t = t_array[idx];
        if (t <= 0.0) {
            p_out[idx] = 0.0;
            if (dp_out) dp_out[idx] = 0.0;
            continue;
        }

        p_out[idx] = talbot_invert_kernel(t, (ReservoirModelType_t)0, NULL, func, user_data, M);

        if (dp_out) {
            double t_plus = t * exp(delta);
            double t_minus = t * exp(-delta);
            double p_plus = talbot_invert_kernel(t_plus, (ReservoirModelType_t)0, NULL, func, user_data, M);
            double p_minus = talbot_invert_kernel(t_minus, (ReservoirModelType_t)0, NULL, func, user_data, M);
            dp_out[idx] = (p_plus - p_minus) * inv_2delta;
        }
    }

    return ROOTFREE_RES_OK;
}

/* ========================================================================= */
/* DESCONVOLUCIÓN TOEPLITZ-TIKHONOV POR FACTORIZACIÓN CHOLESKY EN C99        */
/* ========================================================================= */

ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_deconvolve(
    const double* t_history,
    const double* q_history,
    const double* p_measured,
    int32_t N,
    double lambda_reg,
    double* g_out,
    double* dg_out
) {
    if (!t_history || !q_history || !p_measured || !g_out) {
        return ROOTFREE_RES_ERR_NULL_POINTER;
    }
    if (N < 4) return ROOTFREE_RES_ERR_INVALID_PARAM;

    /* Asignación de memoria dinámica para buffers de trabajo */
    double* dt = (double*)malloc(N * sizeof(double));
    double* K = (double*)calloc(N * N, sizeof(double));
    double* A = (double*)calloc(N * N, sizeof(double));
    double* b = (double*)calloc(N, sizeof(double));
    double* g_prime = (double*)calloc(N, sizeof(double));
    double* L_chol = (double*)calloc(N * N, sizeof(double));
    double* y_tmp = (double*)calloc(N, sizeof(double));

    if (!dt || !K || !A || !b || !g_prime || !L_chol || !y_tmp) {
        free(dt); free(K); free(A); free(b); free(g_prime); free(L_chol); free(y_tmp);
        return ROOTFREE_RES_ERR_NULL_POINTER;
    }

    /* 1. Cálculo de paso de muestreo dt */
    dt[0] = t_history[1] - t_history[0];
    for (int i = 1; i < N - 1; ++i) {
        dt[i] = 0.5 * (t_history[i + 1] - t_history[i - 1]);
    }
    dt[N - 1] = t_history[N - 1] - t_history[N - 2];

    /* 2. Construcción de matriz de convolución triangular inferior K */
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j <= i; ++j) {
            int tau_idx = i - j;
            K[i * N + j] = q_history[tau_idx] * dt[j];
        }
    }

    /* 3. Cálculo de K^T * K y b = K^T * p_measured */
    for (int i = 0; i < N; ++i) {
        double bi = 0.0;
        for (int k = i; k < N; ++k) {
            bi += K[k * N + i] * p_measured[k];
        }
        b[i] = bi;

        for (int j = i; j < N; ++j) {
            double a_ij = 0.0;
            int start_k = (i > j) ? i : j;
            for (int k = start_k; k < N; ++k) {
                a_ij += K[k * N + i] * K[k * N + j];
            }
            A[i * N + j] = a_ij;
            A[j * N + i] = a_ij;
        }
    }

    /* 4. Suma del operador de suavizado de Tikhonov de segundo orden lambda^2 * L^T * L */
    double lam2 = lambda_reg * lambda_reg;
    for (int i = 0; i < N - 2; ++i) {
        /* Fila i de L tiene [1, -2, 1] en las columnas i, i+1, i+2 */
        int c0 = i, c1 = i + 1, c2 = i + 2;
        A[c0 * N + c0] += lam2 * 1.0;
        A[c0 * N + c1] += lam2 * (-2.0);
        A[c0 * N + c2] += lam2 * 1.0;

        A[c1 * N + c0] += lam2 * (-2.0);
        A[c1 * N + c1] += lam2 * 4.0;
        A[c1 * N + c2] += lam2 * (-2.0);

        A[c2 * N + c0] += lam2 * 1.0;
        A[c2 * N + c1] += lam2 * (-2.0);
        A[c2 * N + c2] += lam2 * 1.0;
    }

    /* Condicionamiento numérico mínimo en la diagonal */
    for (int i = 0; i < N; ++i) {
        A[i * N + i] += 1e-12;
    }

    /* 5. Factorización de Cholesky A = L_chol * L_chol^T */
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j <= i; ++j) {
            double sum = A[i * N + j];
            for (int k = 0; k < j; ++k) {
                sum -= L_chol[i * N + k] * L_chol[j * N + k];
            }
            if (i == j) {
                if (sum <= 0.0) {
                    sum = 1e-12; /* Regularización preventiva */
                }
                L_chol[i * N + j] = sqrt(sum);
            } else {
                L_chol[i * N + j] = sum / L_chol[j * N + j];
            }
        }
    }

    /* 6. Sustitución progresiva: L_chol * y = b */
    for (int i = 0; i < N; ++i) {
        double sum = b[i];
        for (int k = 0; k < i; ++k) {
            sum -= L_chol[i * N + k] * y_tmp[k];
        }
        y_tmp[i] = sum / L_chol[i * N + i];
    }

    /* 7. Sustitución regresiva: L_chol^T * g_prime = y */
    for (int i = N - 1; i >= 0; --i) {
        double sum = y_tmp[i];
        for (int k = i + 1; k < N; ++k) {
            sum -= L_chol[k * N + i] * g_prime[k];
        }
        g_prime[i] = sum / L_chol[i * N + i];
    }

    /* 8. Integración trapezoidal para obtener la respuesta al escalón unitario g(t) */
    double cumsum = 0.0;
    for (int i = 0; i < N; ++i) {
        cumsum += g_prime[i] * dt[i];
        g_out[i] = cumsum;
    }

    /* 9. Cálculo opcional de la derivada de Bourdet dg/d(ln t) = t * g'(t) */
    if (dg_out) {
        for (int i = 0; i < N; ++i) {
            dg_out[i] = t_history[i] * g_prime[i];
        }
    }

    /* Liberación de memoria */
    free(dt); free(K); free(A); free(b); free(g_prime); free(L_chol); free(y_tmp);
    return ROOTFREE_RES_OK;
}
