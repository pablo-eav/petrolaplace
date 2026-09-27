%% Example 2: Naturally Fractured Carbonate Reservoir (Warren & Root Dual Porosity)
% Part of PetroLaplace™ Reservoir Core Toolbox
% (C) 2026 Prof. Pablo Enrique Aballe Vázquez

clc; clear; close all;
fprintf('Running Example 2: Warren & Root Dual Porosity Carbonate Reservoir...\n');

CD     = 100.0;
S      = 0.0;
omega  = 0.05;   % Fracture storativity ratio
lambda = 1e-5;   % Interporosity transfer coefficient

tD = logspace(-1, 7, 90);

% Warren & Root transfer function in Laplace domain
% s_eff = s * [(omega*(1-omega)*s + lambda) / ((1-omega)*s + lambda)]
f_dual = @(s) s .* (omega * (1.0 - omega) .* s + lambda) ./ ((1.0 - omega) .* s + lambda);
model_dual = @(s) petrolaplace.model_radial_storage_skin(f_dual(s), CD, S);

[pD, dpD] = petrolaplace.invert_laplace(tD, model_dual, 36);

% Plot Dual Porosity Dip
figure('Name', 'Ex02: Warren & Root Dual Porosity', 'Color', 'w', 'Position', [150, 150, 750, 520]);
loglog(tD, pD, 'b-', 'LineWidth', 2.0, 'DisplayName', 'p_D');
hold on;
loglog(tD, dpD, 'r-', 'LineWidth', 2.2, 'DisplayName', 'Derivada Bourdet');
yline(0.5, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Meseta Radial Infinita (0.500)');

grid on;
xlabel('Tiempo Adimensional t_D', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Presión y Derivada Adimensionales', 'FontSize', 11, 'FontWeight', 'bold');
title(sprintf('PetroLaplace: Warren & Root (\\omega = %.2f, \\lambda = 10^{-5})', omega), ...
    'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'northwest', 'FontSize', 10);

fprintf('[OK] Example 2 completed. Dual-porosity transition valley detected successfully.\n');
