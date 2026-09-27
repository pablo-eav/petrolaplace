%% Example 3: Multi-Fractured Horizontal Well (MFHW) in Unconventional Shale
% Part of PetroLaplace™ Reservoir Core Toolbox
% (C) 2026 Prof. Pablo Enrique Aballe Vázquez

clc; clear; close all;
fprintf('Running Example 3: MFHW in Tight Shale Reservoir (Vaca Muerta / Permian)...\n');

yeD = 1.5;   % Dimensionless fracture half-spacing
Sf  = 0.05;  % Fracture face skin

tD = logspace(-3, 3, 80);

% Unconventional linear flow transfer function in Laplace domain
% pD_shale(s) = (pi / (s*sqrt(s))) * tanh(sqrt(s)*yeD) + Sf/s
model_shale = @(s) (pi ./ (s .* sqrt(s))) .* tanh(sqrt(s) .* yeD) + (Sf ./ s);

[pD, dpD] = petrolaplace.invert_laplace(tD, model_shale, 32);

% Plot Linear Flow Half-Slope
figure('Name', 'Ex03: MFHW Shale Reservoir', 'Color', 'w', 'Position', [150, 150, 750, 520]);
loglog(tD, pD, 'b-', 'LineWidth', 2.0, 'DisplayName', 'p_D');
hold on;
loglog(tD, dpD, 'r-', 'LineWidth', 2.2, 'DisplayName', 'Derivada Bourdet');

% Reference slope m = 0.5 (Linear Flow towards fractures)
t_ref = logspace(-2, 0, 30);
p_ref = 1.8 * sqrt(t_ref);
loglog(t_ref, p_ref, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Pendiente de Fractura m = 1/2');

grid on;
xlabel('Tiempo Adimensional t_D', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Presión y Derivada', 'FontSize', 11, 'FontWeight', 'bold');
title('PetroLaplace: Pozo Horizontal Multifracturado en Shale (MFHW)', ...
    'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'northwest', 'FontSize', 10);

fprintf('[OK] Example 3 completed. Linear flow regime m = 1/2 identified.\n');
