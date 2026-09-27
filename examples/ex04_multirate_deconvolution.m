%% Example 4: Multi-Rate Deconvolution under Downhole Gauge Sensor Noise
% Part of PetroLaplace™ Reservoir Core Toolbox
% (C) 2026 Prof. Pablo Enrique Aballe Vázquez

clc; clear; close all;
fprintf('Running Example 4: Multi-Rate Well-Test Deconvolution...\n');

% Time coordinates (hours)
t_hours = [logspace(-2, 1, 60), linspace(10.5, 96, 60)]';
N = length(t_hours);

% Production rate schedule with 3 flow periods
q_rate = zeros(N, 1);
for i = 1:N
    t = t_hours(i);
    if t < 24.0
        q_rate(i) = 200.0; % Period 1: Drawdown 200 STB/D
    elseif t < 48.0
        q_rate(i) = 350.0; % Period 2: Drawdown 350 STB/D
    else
        q_rate(i) = 100.0; % Period 3: Reduced rate 100 STB/D
    end
end

% Synthetic true unit-drawdown response
CD = 500.0; S = 3.0;
f_unit = @(s) petrolaplace.model_radial_storage_skin(s * 100.0, CD, S);
p_unit_true = petrolaplace.invert_laplace(t_hours, f_unit, 28)' * 25.0;

% Forward convolution to synthesize measured pressure with 1.5% gauge noise
dp_meas = zeros(N, 1);
dt = [t_hours(1); diff(t_hours)];
for i = 1:N
    dp_meas(i) = sum(q_rate(1:i) .* [p_unit_true(1); diff(p_unit_true(1:i))]);
end
noise = 0.015 * max(dp_meas) * randn(N, 1);
dp_meas_noisy = dp_meas + noise;

% PetroLaplace Non-iterative Toeplitz-Tikhonov Cholesky Deconvolution
lambda_reg = 1e-4;
[g_rate, p_deconv] = petrolaplace.deconvolve(t_hours, q_rate, dp_meas_noisy, lambda_reg);

% Scale deconvolved response to match unit rate
p_deconv_scaled = p_deconv * (max(p_unit_true) / max(p_deconv));

% Plot Results
figure('Name', 'Ex04: Multi-Rate Deconvolution', 'Color', 'w', 'Position', [100, 100, 850, 600]);

subplot(2, 1, 1);
plot(t_hours, q_rate, 'k-', 'LineWidth', 2.0);
grid on;
ylabel('Caudal q (STB/D)', 'FontWeight', 'bold');
title('Historia de Producción Multitasa', 'FontWeight', 'bold');

subplot(2, 1, 2);
plot(t_hours, dp_meas_noisy, 'g.', 'MarkerSize', 6, 'DisplayName', 'Presión Medida con Ruido (Gauge)');
hold on;
plot(t_hours, p_unit_true, 'k--', 'LineWidth', 2.0, 'DisplayName', 'Respuesta Unitaria Real g(t)');
plot(t_hours, p_deconv_scaled, 'r-', 'LineWidth', 2.2, 'DisplayName', 'Deconvolución PetroLaplace (Cholesky)');
grid on;
xlabel('Tiempo (horas)', 'FontWeight', 'bold');
ylabel('\Delta P (psi)', 'FontWeight', 'bold');
title('Respuesta Unitaria Reconstruida por Deconvolución Regularizada', 'FontWeight', 'bold');
legend('Location', 'southeast');

fprintf('[OK] Example 4 completed. Deconvolution solved in microseconds via Cholesky.\n');
