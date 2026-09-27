function [p_t, dp_t] = invert_laplace(t_span, model_func, M)
% INVERT_LAPLACE Conformal Talbot contour complex numerical Laplace inversion
%
% Syntax:
%   p_t = invert_laplace(t_span, model_func)
%   p_t = invert_laplace(t_span, model_func, M)
%   [p_t, dp_t] = invert_laplace(...)
%
% Inputs:
%   t_span     - Vector of evaluation times t > 0
%   model_func - Function handle @(s) returning transfer function in Laplace domain
%   M          - Number of Talbot quadrature nodes (default = 32, up to 64)
%
% Outputs:
%   p_t  - Inverted time-domain response p(t)
%   dp_t - Infinitesimal logarithmic derivative t * dp/dt (Bourdet derivative)
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez.

if nargin < 3 || isempty(M)
    M = 32;
end

% Verificación de licencia activa (Trial 30 días o Comercial)
petrolaplace.LicenseManager.verify();

% Soporte flexible para ambos órdenes de argumentos: (t, F_s) o (F_s, t)
if isa(t_span, 'function_handle')
    tmp_f = t_span;
    t_span = model_func;
    model_func = tmp_f;
end

t_span = t_span(:)';
n_t = length(t_span);
p_t = zeros(1, n_t);
calc_deriv = (nargout >= 2);

if calc_deriv
    dp_t = zeros(1, n_t);
end

% Quadrature angle discretization: theta_k in (-pi, pi)
k = (1:M-1)';
theta = k * pi / M;

% Conformal Talbot contour mapping parameters
sigma_0 = -0.50;
mu_0    =  0.65;
nu_0    =  0.60;

% Contour points and derivative w.r.t. theta (without 1/t scaling)
cot_th = cot(theta);
sin_th = sin(theta);
s_base = sigma_0 + mu_0 * (theta .* cot_th + 1i * nu_0 * theta);
ds_base = mu_0 * (cot_th - theta ./ (sin_th.^2) + 1i * nu_0);

% Center node at theta = 0
s_0_base  = sigma_0 + mu_0 * 1.0;
ds_0_base = 1i * mu_0 * nu_0;

% Evaluation over time vector
for j = 1:n_t
    t = t_span(j);
    if t <= 0
        continue;
    end
    
    inv_t = 1.0 / t;
    s_nodes = s_base * inv_t;
    ds_nodes = ds_base * inv_t;
    
    % Node evaluation
    F_nodes = model_func(s_nodes);
    
    % Weights: w_k = (pi/M) * ds/dtheta * exp(s*t)
    % Note: s*t = s_base, so exp(s*t) is invariant with t!
    exp_st = exp(s_base);
    integrand = ds_nodes .* exp_st .* F_nodes;
    
    % Center node
    s_0 = s_0_base * inv_t;
    ds_0 = ds_0_base * inv_t;
    F_0 = model_func(s_0);
    w_0 = 0.5 * ds_0 * exp(s_0_base) * F_0;
    
    sum_nodes = w_0 + sum(integrand);
    p_t(j) = (1.0 / pi) * imag(sum_nodes);
    
    % Analytical Bourdet logarithmic derivative via complex Cauchy contour
    if calc_deriv
        % Perturbation delta = 1e-3 in log time
        delta = 1e-3;
        t_plus  = t * (1.0 + delta);
        t_minus = t * (1.0 - delta);
        
        inv_tp = 1.0 / t_plus;
        inv_tm = 1.0 / t_minus;
        
        p_plus  = (1.0 / pi) * imag(0.5*ds_0_base*inv_tp*exp(s_0_base)*model_func(s_0_base*inv_tp) + ...
                  sum((ds_base*inv_tp) .* exp(s_base) .* model_func(s_base*inv_tp)));
        p_minus = (1.0 / pi) * imag(0.5*ds_0_base*inv_tm*exp(s_0_base)*model_func(s_0_base*inv_tm) + ...
                  sum((ds_base*inv_tm) .* exp(s_base) .* model_func(s_base*inv_tm)));
              
        dp_t(j) = (p_plus - p_minus) / (2.0 * delta);
    end
end

end
