function pD_s = model_radial_storage_skin(s, CD, S)
% MODEL_RADIAL_STORAGE_SKIN Evaluates Laplace transfer function for wellbore storage and skin
%
%   pD_s = model_radial_storage_skin(s, CD, S)
%
% Formula:
%   pD_s = [K0(sqrt(s)) + S*sqrt(s)*K1(sqrt(s))] / 
%          [s * (sqrt(s)*K1(sqrt(s)) + CD*s*(K0(sqrt(s)) + S*sqrt(s)*K1(sqrt(s))))]
%
% Inputs:
%   s  - Complex Laplace variable (scalar or vector)
%   CD - Dimensionless wellbore storage coefficient (>= 0)
%   S  - Dimensionless skin factor
%
% Output:
%   pD_s - Dimensionless pressure in Laplace domain
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez.

sqs = sqrt(s);
k0 = besselk(0, sqs);
k1 = besselk(1, sqs);

num = k0 + S .* sqs .* k1;
den = s .* (sqs .* k1 + CD .* s .* num);

pD_s = num ./ den;

% Handle s -> 0 limits or NaN safely
nan_idx = isnan(pD_s) | isinf(pD_s);
if any(nan_idx)
    pD_s(nan_idx) = 0.0;
end

end
