"""
Módulo de Modelos Analíticos de Yacimientos de Hidrocarburos en el Dominio de Laplace
Autor: Pablo Enrique Aballe Vázquez
División de Dinámica de Fluidos en Medios Porosos y Transferencia Energética

Modelos implementados:
1. Pozo vertical con Almacenamiento de Pozo (Wellbore Storage, C_D) y Daño de Formación (Skin, S).
2. Yacimiento Naturalmente Fracturado (Modelo de Doble Porosidad de Warren & Root).
3. Pozo Horizontal Multifracturado en Yacimientos No Convencionales (Shale / Tight Gas).
4. Pozo con Límite Exterior Cerrado (Declinación Pseudo-Estacionaria / PSS).
"""

import numpy as np
import scipy.special as sp

def laplace_radial_storage_skin(s, C_D=1000.0, S=2.0, r_D=1.0):
    """
    Solución analítica de la ecuación de difusividad radial en el dominio de Laplace
    para un pozo con almacenamiento de pozo C_D y factor de daño (skin) S.
    """
    sqrt_s = np.sqrt(s)
    k0 = sp.kv(0, sqrt_s * r_D)
    k1 = sp.kv(1, sqrt_s)
    
    numerador = k0 + S * sqrt_s * k1
    denominador = s * (sqrt_s * k1 + C_D * s * numerador)
    
    return numerador / denominador

def laplace_dual_porosity_warren_root(s, C_D=500.0, S=1.5, omega=0.02, lambda_param=1e-6):
    """
    Modelo de doble porosidad de Warren & Root (matriz microporosa + red de fracturas).
    """
    f_s = (omega * (1.0 - omega) * s + lambda_param) / ((1.0 - omega) * s + lambda_param)
    s_eff = s * f_s
    sqrt_s_eff = np.sqrt(s_eff)
    
    k0 = sp.kv(0, sqrt_s_eff)
    k1 = sp.kv(1, sqrt_s_eff)
    
    numerador = k0 + S * sqrt_s_eff * k1
    denominador = s * (sqrt_s_eff * k1 + C_D * s * numerador)
    
    return numerador / denominador

def laplace_unconventional_shale_mfhw(s, C_D=50.0, S_f=0.5, x_eD=10.0, y_eD=5.0):
    """
    Modelo para Pozo Horizontal Multifracturado (MFHW) en Formaciones No Convencionales (Shale).
    """
    sqrt_s = np.sqrt(s)
    arg = sqrt_s * y_eD
    arg_real = np.clip(np.real(arg), -50.0, 50.0)
    arg_safe = arg_real + 1j * np.imag(arg)
    tanh_val = np.tanh(arg_safe)
        
    p_linear = (np.pi / (s * sqrt_s)) * tanh_val
    p_fracture = p_linear + S_f / s
    p_well = p_fracture / (1.0 + C_D * s * p_fracture)
    
    return p_well

def laplace_infinite_acting_reservoir(s):
    """
    Solución pura de línea fuente infinita (Theis / Ei solution):
    """
    sqrt_s = np.sqrt(s)
    k0 = sp.kv(0, sqrt_s)
    k1 = sp.kv(1, sqrt_s)
    return k0 / (s * sqrt_s * k1)
