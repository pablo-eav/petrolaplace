/**
 * @file root_free_reservoir_core.h
 * @brief Interfaz C99 / DLL de Alto Rendimiento para el Motor Root-Free Reservoir.
 *        Cálculo determinista de transitorios de presión, derivada de Bourdet y
 *        desconvolución de Toeplitz-Tikhonov para ingeniería de yacimientos.
 * 
 * Autor: Prof. Pablo Enrique Aballe Vázquez
 * División de Dinámica de Fluidos en Medios Porosos y Transferencia Energética
 * Instituto Internacional de Investigación en Física Matemática y Aeroespacial Laplace
 */

#ifndef ROOT_FREE_RESERVOIR_CORE_H
#define ROOT_FREE_RESERVOIR_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>

#if defined(_WIN32) || defined(_WIN64)
    #ifdef ROOTFREE_EXPORTS
        #define ROOTFREE_API __declspec(dllexport)
    #else
        #define ROOTFREE_API __declspec(dllimport)
    #endif
#else
    #define ROOTFREE_API __attribute__((visibility("default")))
#endif

/* Estructura para aritmética compleja C99 portable e independiente de compilador */
typedef struct {
    double r; /* Parte real */
    double i; /* Parte imaginaria */
} cdouble_t;

static inline cdouble_t c_make(double r, double i) {
    cdouble_t z; z.r = r; z.i = i; return z;
}

/* Identificadores estándar de modelos de yacimientos */
typedef enum {
    MODEL_RADIAL_STORAGE_SKIN     = 1, /* Pozo vertical con C_D y S */
    MODEL_DUAL_POROSITY_WARREN_ROOT = 2, /* Warren & Root (omega, lambda, C_D, S) */
    MODEL_UNCONVENTIONAL_SHALE_MFHW = 3, /* Pozo horizontal multifracturado en lutitas */
    MODEL_INFINITE_ACTING_RADIAL   = 4, /* Línea fuente infinita pura (Ei) */
    MODEL_RATIONAL_FRACTION        = 5  /* Fracción racional P(s)/Q(s) */
} ReservoirModelType_t;

/* Códigos de estado del motor */
typedef enum {
    ROOTFREE_RES_OK                 = 0,
    ROOTFREE_RES_ERR_NULL_POINTER   = -1,
    ROOTFREE_RES_ERR_INVALID_PARAM  = -2,
    ROOTFREE_RES_ERR_MODEL_UNKNOWN  = -3,
    ROOTFREE_RES_ERR_SINGULAR_MATRIX = -4,
    ROOTFREE_RES_ERR_SELF_TEST_FAIL = -5
} RootFreeResStatus_t;

/* Estructura de parámetros físicos para los modelos analíticos */
typedef struct {
    double C_D;           /* Almacenamiento adimensional del pozo */
    double S;             /* Factor de daño (skin) */
    double omega;         /* Relación de almacenamiento de fracturas (doble porosidad) */
    double lambda_param;  /* Coeficiente de transferencia interporosidad */
    double y_eD;          /* Espaciamiento adimensional entre fracturas (MFHW) */
    double S_f;           /* Daño superficial de la fractura hidráulica */
} ReservoirParams_t;

/* Puntero a función de evaluación en el dominio de Laplace personalizada */
typedef cdouble_t (*LaplaceCustomFunc_t)(cdouble_t s, const void* user_data);

/* ========================================================================= */
/* FUNCIONES DE GESTIÓN Y AUTOCOMPROBACIÓN DEL MOTOR                          */
/* ========================================================================= */

/**
 * @brief Obtiene la cadena de versión y firma de la biblioteca.
 */
ROOTFREE_API const char* rootfree_reservoir_get_version(void);

/**
 * @brief Ejecuta el Built-In-Test (BIT) matemático para certificar la integridad numérica.
 * @return ROOTFREE_RES_OK si supera todas las pruebas analíticas con precisión < 1e-12.
 */
ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_self_test(void);

/* ========================================================================= */
/* EVALUACIÓN ANALÍTICA DE MODELOS EN EL PLANO COMPLEJO                      */
/* ========================================================================= */

/**
 * @brief Evalúa la función de Bessel K_0(z) para un número complejo z con Re(z) > 0.
 */
ROOTFREE_API cdouble_t rootfree_bessel_k0(cdouble_t z);

/**
 * @brief Evalúa la función de Bessel K_1(z) para un número complejo z con Re(z) > 0.
 */
ROOTFREE_API cdouble_t rootfree_bessel_k1(cdouble_t z);

/**
 * @brief Evalúa la solución analítica en el plano de Laplace s para el modelo seleccionado.
 */
ROOTFREE_API cdouble_t rootfree_eval_laplace_model(
    cdouble_t s,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params
);

/* ========================================================================= */
/* INVERSIÓN CONFORME DE TALBOT Y DERIVADA DE BOURDET                        */
/* ========================================================================= */

/**
 * @brief Invierte la transformada de Laplace f(s) en un instante de tiempo escalar t > 0.
 * @param t Tiempo adimensional de prueba.
 * @param model_type Tipo de modelo analítico.
 * @param params Parámetros físicos del modelo.
 * @param M Número de nodos de cuadratura conforme (típicamente 32 a 48).
 * @param p_val Puntero de salida para P(t).
 * @param dp_val Puntero de salida para la derivada de Bourdet t*dP/dt (puede ser NULL).
 */
ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_invert_scalar(
    double t,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params,
    int32_t M,
    double* p_val,
    double* dp_val
);

/**
 * @brief Invierte un vector completo de tiempos en una única llamada vectorizada ultrarrápida.
 * @param t_array Array de tiempos t > 0.
 * @param n_points Número de puntos en el array.
 * @param model_type Tipo de modelo analítico.
 * @param params Parámetros físicos del modelo.
 * @param M Número de nodos de cuadratura conforme.
 * @param p_out Array de salida para P(t) (tamaño n_points).
 * @param dp_out Array de salida para la derivada de Bourdet (tamaño n_points, o NULL).
 */
ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_invert_vector(
    const double* t_array,
    int32_t n_points,
    ReservoirModelType_t model_type,
    const ReservoirParams_t* params,
    int32_t M,
    double* p_out,
    double* dp_out
);

/**
 * @brief Inversión de Laplace para una función personalizada arbitraria f(s).
 */
ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_invert_custom(
    const double* t_array,
    int32_t n_points,
    LaplaceCustomFunc_t func,
    const void* user_data,
    int32_t M,
    double* p_out,
    double* dp_out
);

/* ========================================================================= */
/* DESCONVOLUCIÓN TOEPLITZ-TIKHONOV DE CAUDAL VARIABLE Y PRESIÓN CON RUIDO    */
/* ========================================================================= */

/**
 * @brief Desconvolución regularizada de Tikhonov de segundo orden.
 *        Resuelve (K^T * K + lambda^2 * L^T * L) * g' = K^T * P_meas
 *        mediante factorización de Cholesky simétrica definida positiva en tiempo récord.
 * 
 * @param t_history Vector de tiempos de adquisición (tamaño N).
 * @param q_history Vector de caudales medidos (tamaño N).
 * @param p_measured Vector de caídas de presión medidas (tamaño N).
 * @param N Número de muestras temporales.
 * @param lambda_reg Parámetro de regularización de Tikhonov (ej. 1e-4 a 1e-2).
 * @param g_out Vector de salida para la respuesta al impulso unitario g(t) (tamaño N).
 * @param dg_out Vector de salida para la derivada de Bourdet de g(t) (tamaño N, o NULL).
 */
ROOTFREE_API RootFreeResStatus_t rootfree_reservoir_deconvolve(
    const double* t_history,
    const double* q_history,
    const double* p_measured,
    int32_t N,
    double lambda_reg,
    double* g_out,
    double* dg_out
);

#ifdef __cplusplus
}
#endif

#endif /* ROOT_FREE_RESERVOIR_CORE_H */
