%% Example 1: Standard Vertical Well with Wellbore Storage and Skin (Bourdet Diagnostic)
% Part of PetroLaplace™ Reservoir Core Toolbox
% (C) 2026 Prof. Pablo Enrique Aballe Vázquez

clc; clear; close all;
fprintf('Running Example 1: Bourdet Storage & Skin Diagnostic...\n');

% Dimensionless parameters
CD = 1000.0;
S  = 2.5;

% Dimensionless time range (6 log cycles)
tD = logspace(-1, 5, 80);

% Model evaluation via PetroLaplace
model_func = @(s) petrolaplace.model_radial_storage_skin(s, CD, S);
[pD, dpD] = petrolaplace.invert_laplace(tD, model_func, 32);

% Diagnostic Plot
figure('Name', 'Ex01: Bourdet Storage & Skin', 'Color', 'w', 'Position', [150, 150, 750, 520]);
loglog(tD, pD, 'b-', 'LineWidth', 2.2, 'DisplayName', 'p_D (Adimensional)');
hold on;
loglog(tD, dpD, 'r-', 'LineWidth', 2.2, 'DisplayName', 'dp_D/d(ln t_D) (Derivada Bourdet)');
yline(0.5, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Flujo Radial Infinito (0.500)');

grid on;
xlabel('Tiempo Adimensional t_D', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Presión y Derivada Adimensionales', 'FontSize', 11, 'FontWeight', 'bold');
title(sprintf('PetroLaplace: Curvas Tipo de Bourdet (C_D = %.0f, S = +%.1f)', CD, S), ...
    'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'northwest', 'FontSize', 10);

fprintf('[OK] Example 1 completed successfully. Infinite acting radial plateau = %.4f\n', dpD(end));
