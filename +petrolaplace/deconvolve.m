function [g_rate, p_unit] = deconvolve(t_span, q_history, p_measured, lambda_reg)
% DECONVOLVE Fast regularized Toeplitz-Tikhonov well-test deconvolution
%
% Syntax:
%   [g_rate, p_unit] = deconvolve(t_span, q_history, p_measured)
%   [g_rate, p_unit] = deconvolve(t_span, q_history, p_measured, lambda_reg)
%
% Solves Duhamel's convolution integral:
%   Delta P(t) = \int_0^t q(tau) * g'(t - tau) dtau
%
% Matrix Formulation:
%   (K^T * K + lambda^2 * L^T * L) * g' = K^T * Delta P
% via non-iterative Cholesky decomposition.
%
% Inputs:
%   t_span     - Vector of time coordinates (hours)
%   q_history  - Vector of surface production rates (STB/D)
%   p_measured - Vector of pressure drops Delta P (psi)
%   lambda_reg - Tikhonov curvature regularization weight (default = 1e-3)
%
% Outputs:
%   g_rate - Unit-rate impulse response derivative g'(t)
%   p_unit - Equivalent constant-rate unit drawdown response Delta P_u(t)
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez.

if nargin < 4 || isempty(lambda_reg)
    lambda_reg = 1e-3;
end

t_span = t_span(:);
q_history = q_history(:);
p_measured = p_measured(:);
N = length(t_span);

% Build lower triangular Toeplitz convolution matrix K
dt = [t_span(1); diff(t_span)];
K = zeros(N, N);

for i = 1:N
    for j = 1:i
        K(i, j) = q_history(j) * dt(j);
    end
end

% Build second-order discrete curvature operator L (N-2 x N)
if N >= 3
    e = ones(N, 1);
    L = spdiags([e -2*e e], 0:2, N-2, N);
else
    L = speye(N);
end

% Normal equations system: A * g' = b
KT_K = K' * K;
LT_L = full(L' * L);
A = KT_K + (lambda_reg^2) * LT_L;
b = K' * p_measured;

% Cholesky factorization: A = R' * R
R = chol(A);
y = R' \ b;
g_rate = R \ y;

% Reconstruct unit constant-rate drawdown response by trapezoidal integration
p_unit = cumsum(g_rate .* dt);

end
