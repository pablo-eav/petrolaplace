function results = analyze_well(t_hr, p_wf, pvt_params, plot_diag)
% ANALYZE_WELL End-to-end automated Pressure Transient Analysis and reservoir characterization
%
% Syntax:
%   results = analyze_well(t_hr, p_wf, pvt_params)
%   results = analyze_well(t_hr, p_wf, pvt_params, plot_diag)
%
% Inputs:
%   t_hr       - Time vector (hours)
%   p_wf       - Bottom-hole flowing pressure vector (psi)
%   pvt_params - Struct with fields:
%                  Pi  - Initial virgin reservoir pressure (psi)
%                  q   - Flow rate (STB/D)
%                  h   - Net formation thickness (ft)
%                  phi - Porosity (fraction)
%                  mu  - Oil viscosity (cp)
%                  ct  - Total compressibility (1/psi)
%                  B   - Formation volume factor (RB/STB)
%                  rw  - Wellbore radius (ft)
%   plot_diag  - Boolean, true to display 4-quadrant diagnostic figure (default = true)
%
% Outputs:
%   results - Struct with calculated properties:
%               k_mD      - Permeability (mD)
%               kh        - Flow capacity (mD*ft)
%               S         - Skin factor
%               CD        - Dimensionless wellbore storage
%               C_storage - Physical storage coefficient (bbl/psi)
%               dp_skin   - Pressure drop due to skin (psi)
%               FE        - Flow efficiency
%               r_inv_ft  - Investigation radius (ft)
%               rmse      - Fit root-mean-square error (psi)
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez.

if nargin < 4 || isempty(plot_diag)
    plot_diag = true;
end

% Verificación de licencia activa (Trial 30 días o Comercial)
petrolaplace.LicenseManager.verify();

t_hr = t_hr(:);
p_wf = p_wf(:);

Pi  = pvt_params.Pi;
q   = pvt_params.q;
h   = pvt_params.h;
phi = pvt_params.phi;
mu  = pvt_params.mu;
ct  = pvt_params.ct;
B   = pvt_params.B;
rw  = pvt_params.rw;

% 1. Pressure drop and Bourdet derivative
dp_psi = Pi - p_wf;
L_factor = 0.15;
if isfield(pvt_params, 'L_factor')
    L_factor = pvt_params.L_factor;
end
dp_deriv = petrolaplace.bourdet_derivative(t_hr, dp_psi, L_factor);

% 2. Automated non-linear matching
% Initial parameter guesses: [t_factor, p_factor, CD, S]
x0 = [3500.0, 30.0, 500.0, 3.0];

obj_fun = @(x) calc_fit_error(x, t_hr, dp_psi);
opts = optimset('Display', 'off', 'MaxIter', 400, 'TolX', 1e-3, 'TolFun', 1e-3);
x_opt = fminsearch(obj_fun, x0, opts);

t_fac = x_opt(1);
p_fac = x_opt(2);
CD_opt = max(0.1, x_opt(3));
S_opt  = x_opt(4);

% 3. Extract physical properties
% p_D = (kh / 141.2 q mu B) * Delta P  =>  p_fac = 141.2 q mu B / kh
kh = (141.2 * q * mu * B) / p_fac;
k_mD = kh / h;

% t_D = (0.0002637 k / (phi mu ct rw^2)) * t  =>  t_fac
C_storage = (CD_opt * 2 * pi * phi * ct * h * (rw^2)) / 5.615; % bbl/psi
dp_skin = 0.869 * (p_fac / 2.0) * S_opt;
dp_total = dp_psi(end);
dp_ideal = dp_total - dp_skin;
FE = dp_ideal / dp_total;

t_test_hr = t_hr(end);
r_inv_ft = 0.029 * sqrt((k_mD * t_test_hr) / (phi * mu * ct));
r_wa = rw * exp(-S_opt);

% Calibrated model curves
t_D = t_hr * t_fac;
model_f = @(s) petrolaplace.model_radial_storage_skin(s, CD_opt, S_opt);
[p_D_cal, dp_D_cal] = petrolaplace.invert_laplace(t_D, model_f, 32);

dp_model = p_D_cal(:) * p_fac;
dp_deriv_model = dp_D_cal(:) * p_fac;
rmse = sqrt(mean((dp_psi - dp_model).^2));

% Store results
results.k_mD      = k_mD;
results.kh        = kh;
results.S         = S_opt;
results.CD        = CD_opt;
results.C_storage = C_storage;
results.dp_skin   = dp_skin;
results.FE        = FE;
results.r_inv_ft  = r_inv_ft;
results.r_wa      = r_wa;
results.rmse      = rmse;

% 4. Visualization
if plot_diag
    figure('Name', 'PetroLaplace Reservoir Diagnostic Studio', 'Color', 'w', 'Position', [100, 100, 1050, 750]);
    
    % Panel 1: Bourdet Diagnostic Log-Log
    subplot(2, 2, 1);
    loglog(t_hr, dp_psi, 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 5, 'DisplayName', '\Delta P (Medida)');
    hold on;
    loglog(t_hr, dp_deriv, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 5, 'DisplayName', 'Derivada Bourdet');
    loglog(t_hr, dp_model, 'b-', 'LineWidth', 1.8, 'DisplayName', 'Ajuste Root-Free \Delta P');
    loglog(t_hr, dp_deriv_model, 'r-', 'LineWidth', 1.8, 'DisplayName', 'Ajuste Root-Free Derivada');
    grid on;
    xlabel('Tiempo de Prueba \Delta t (horas)');
    ylabel('\Delta P y Derivada (psi)');
    title('Diagnóstico Bourdet Log-Log');
    legend('Location', 'northwest');
    
    % Panel 2: History Match Cartesiano
    subplot(2, 2, 2);
    plot(t_hr, p_wf, 'k.', 'MarkerSize', 8, 'DisplayName', 'P_{wf} Medida');
    hold on;
    plot(t_hr, Pi - dp_model, 'r-', 'LineWidth', 2.0, 'DisplayName', 'Modelo Calibrado');
    grid on;
    xlabel('Tiempo (horas)');
    ylabel('Presión de Fondo P_{wf} (psi)');
    title(sprintf('Ajuste Cartesiano (RMSE = %.2f psi)', rmse));
    legend('Location', 'northeast');
    
    % Panel 3: Skin Impact Breakdown
    subplot(2, 2, 3);
    bar([1, 2], [dp_ideal, dp_skin], 'FaceColor', [0.15, 0.45, 0.75]);
    set(gca, 'XTickLabel', {'Flujo Útil (\Delta P_{ideal})', 'Pérdida por Daño (\Delta P_{skin})'});
    ylabel('Caída de Presión (psi)');
    title(sprintf('Impacto Económico del Daño (S = +%.2f, FE = %.1f%%)', S_opt, FE*100));
    grid on;
    
    % Panel 4: Radius of Investigation vs Time
    subplot(2, 2, 4);
    r_inv_series = 0.029 * sqrt((k_mD * t_hr) / (phi * mu * ct));
    plot(t_hr, r_inv_series, 'g-', 'LineWidth', 2.2);
    grid on;
    xlabel('Tiempo (horas)');
    ylabel('Radio de Investigación r_{inv} (ft)');
    title(sprintf('Radio Investigado: %.0f ft (%.0f m)', r_inv_ft, r_inv_ft * 0.3048));
end

end

function err = calc_fit_error(x, t_hr, dp_psi)
    t_fac = max(1.0, x(1));
    p_fac = max(0.1, x(2));
    CD_val = max(0.1, x(3));
    S_val = x(4);
    
    t_D = t_hr * t_fac;
    f_lap = @(s) petrolaplace.model_radial_storage_skin(s, CD_val, S_val);
    p_D = petrolaplace.invert_laplace(t_D, f_lap, 24);
    model = p_D(:) * p_fac;
    err = sqrt(mean((dp_psi - model).^2));
end
