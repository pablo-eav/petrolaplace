"""
Implementación del Algoritmo de Stehfest (1970) para Análisis de Transitorios de Presión
Autor: Pablo Enrique Aballe Vázquez
División de Dinámica de Fluidos en Medios Porosos y Transferencia Energética

El algoritmo de Stehfest calcula la transformada inversa de Laplace f(t) mediante:
    f(t) = (ln(2) / t) * sum_{i=1}^N V_i * F_bar(i * ln(2) / t)
donde N es un número par (típicamente 8, 10, 12, 16 o 18).
"""

import math
import numpy as np

def compute_stehfest_weights(N=12):
    """
    Calcula los coeficientes ponderados V_i del algoritmo de Stehfest.
    
    V_i = (-1)^(N/2 + i) * sum_{k=floor((i+1)/2)}^{min(i, N/2)} [ k^(N/2) * (2k)! / 
          ( (N/2 - k)! * k! * (k-1)! * (i-k)! * (2k - i)! ) ]
    """
    if N % 2 != 0:
        raise ValueError("El orden N de Stehfest debe ser un número par.")
    
    half_N = N // 2
    V = np.zeros(N, dtype=np.float64)
    
    for i in range(1, N + 1):
        total_sum = 0.0
        k_min = (i + 1) // 2
        k_max = min(i, half_N)
        
        for k in range(k_min, k_max + 1):
            numerator = (k ** half_N) * math.factorial(2 * k)
            denominator = (
                math.factorial(half_N - k) *
                math.factorial(k) *
                math.factorial(k - 1) *
                math.factorial(i - k) *
                math.factorial(2 * k - i)
            )
            total_sum += numerator / denominator
        
        sign = (-1) ** (half_N + i)
        V[i - 1] = sign * total_sum
        
    return V

def stehfest_invert(f_laplace, t, N=12, **kwargs):
    """
    Invierte una función f_laplace(s) en el instante t (escalar o array) utilizando el método de Stehfest.
    
    f_laplace: función s -> F_bar(s). Debe admitir argumentos reales positivos.
    t: tiempo o vector de tiempos t > 0.
    N: orden de Stehfest (recomendado N=8, 10 o 12 en double precision).
    """
    t_arr = np.atleast_1d(np.asarray(t, dtype=np.float64))
    V = compute_stehfest_weights(N)
    ln2 = math.log(2.0)
    
    results = np.zeros_like(t_arr)
    
    for idx, t_val in enumerate(t_arr):
        if t_val <= 0:
            results[idx] = np.nan
            continue
            
        sum_terms = 0.0
        for i in range(1, N + 1):
            s_i = (i * ln2) / t_val
            f_val = f_laplace(s_i, **kwargs)
            sum_terms += V[i - 1] * f_val
            
        results[idx] = (ln2 / t_val) * sum_terms
        
    if np.isscalar(t):
        return results[0]
    return results

def stehfest_bourdet_derivative(f_laplace, t, N=12, delta_ln_t=0.01, **kwargs):
    """
    Calcula la derivada diagnóstica de Bourdet:
        P'(t) = d P / d(ln t) = t * dP/dt
    mediante diferencias centrales finitas sobre la inversión de Stehfest.
    Nota: Esta es la técnica habitual de la industria, muy susceptible a ruido.
    """
    t_arr = np.atleast_1d(np.asarray(t, dtype=np.float64))
    derivatives = np.zeros_like(t_arr)
    
    for idx, t_val in enumerate(t_arr):
        t_plus = t_val * math.exp(delta_ln_t)
        t_minus = t_val * math.exp(-delta_ln_t)
        
        p_plus = stehfest_invert(f_laplace, t_plus, N=N, **kwargs)
        p_minus = stehfest_invert(f_laplace, t_minus, N=N, **kwargs)
        
        # dP / d(ln t) = (P(t+) - P(t-)) / (2 * delta_ln_t)
        derivatives[idx] = (p_plus - p_minus) / (2.0 * delta_ln_t)
        
    if np.isscalar(t):
        return derivatives[0]
    return derivatives

if __name__ == "__main__":
    for order in [8, 12, 16, 18]:
        w = compute_stehfest_weights(order)
        print(f"Stehfest N={order}: max |V_i| = {np.max(np.abs(w)):.2e}, min V_i = {np.min(w):.2e}")
