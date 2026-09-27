function dp_deriv = bourdet_derivative(t_arr, p_arr, L_factor)
% BOURDET_DERIVATIVE Calculates smooth logarithmic Bourdet derivative from data
%
%   dp_deriv = bourdet_derivative(t_arr, p_arr, L_factor)
%
% Formula:
%   d(Delta P) / d(ln t) with logarithmic window smoothing (L-factor)
%
% Inputs:
%   t_arr    - Time vector (hours)
%   p_arr    - Pressure drop vector Delta P (psi)
%   L_factor - Window smoothing factor (default = 0.15)
%
% Output:
%   dp_deriv - Bourdet derivative vector at each time point
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez.

if nargin < 3 || isempty(L_factor)
    L_factor = 0.15;
end

t_arr = t_arr(:);
p_arr = p_arr(:);
n = length(t_arr);
dp_deriv = zeros(n, 1);

ln_t = log(t_arr);

for i = 1:n
    % Find indices to the left and right satisfying ln(t) distance >= L_factor
    left_mask  = (ln_t(i) - ln_t(1:i)) >= L_factor;
    right_mask = (ln_t(i:end) - ln_t(i)) >= L_factor;
    
    idx_1 = find(left_mask, 1, 'last');
    if isempty(idx_1)
        idx_1 = max(1, i - 1);
    end
    
    idx_2_rel = find(right_mask, 1, 'first');
    if isempty(idx_2_rel)
        idx_2 = min(n, i + 1);
    else
        idx_2 = i - 1 + idx_2_rel;
    end
    
    if idx_1 == idx_2
        idx_1 = max(1, i - 1);
        idx_2 = min(n, i + 1);
    end
    
    d_ln = ln_t(idx_2) - ln_t(idx_1);
    if d_ln > 0
        dp_deriv(i) = (p_arr(idx_2) - p_arr(idx_1)) / d_ln;
    else
        dp_deriv(i) = 0.0;
    end
end

end
