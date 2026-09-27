function PetroLaplaceApp()
    % PETROLAPLACEAPP Interactive MATLAB Application for PetroLaplace™ Reservoir Core
    %
    % Launch with:
    %   PetroLaplaceApp
    %
    % Author: Pablo Enrique Aballe
    % Copyright 2026 PetroLaplace Project. All rights reserved.

    % Create UI Figure
    fig = uifigure('Name', 'PetroLaplace™ Reservoir Core Studio', ...
                   'Position', [100, 100, 1000, 650], ...
                   'Color', [0.96, 0.97, 0.98]);

    % Grid Layout
    grid = uigridlayout(fig, [1, 2]);
    grid.ColumnWidth = {'320px', '1x'};

    % Control Panel (Left)
    panelLeft = uipanel(grid, 'Title', 'Reservoir Configuration & Models', ...
                        'FontWeight', 'bold', 'FontSize', 12, ...
                        'BackgroundColor', 'white');
    pGrid = uigridlayout(panelLeft, [10, 1]);
    pGrid.RowHeight = {'30px', '30px', '30px', '30px', '30px', '30px', '30px', '30px', '40px', '1x'};

    % Model Dropdown
    lblModel = uilabel(pGrid, 'Text', 'Select Reservoir Model:', 'FontWeight', 'bold');
    dropModel = uidropdown(pGrid, 'Items', ...
        {'Radial Storage & Skin (Homogeneous)', ...
         'Warren-Root Dual-Porosity (Carbonate)', ...
         'Multi-Fractured Horizontal Well (Shale)'}, ...
        'Value', 'Radial Storage & Skin (Homogeneous)');

    % Parameter CD
    lblCD = uilabel(pGrid, 'Text', 'Wellbore Storage C_D:');
    editCD = uieditfield(pGrid, 'numeric', 'Value', 1000, 'Limits', [1, 1e7]);

    % Parameter Skin
    lblSkin = uilabel(pGrid, 'Text', 'Skin Factor S:');
    editSkin = uieditfield(pGrid, 'numeric', 'Value', 2.5, 'Limits', [-5, 50]);

    % Parameter Omega (Dual Porosity)
    lblOmega = uilabel(pGrid, 'Text', 'Storativity Ratio \omega (Dual Por.):');
    editOmega = uieditfield(pGrid, 'numeric', 'Value', 0.05, 'Limits', [1e-4, 1.0]);

    % Parameter Lambda (Dual Porosity)
    lblLambda = uilabel(pGrid, 'Text', 'Interporosity Coeff \lambda (Dual Por.):');
    editLambda = uieditfield(pGrid, 'numeric', 'Value', 1e-6, 'Limits', [1e-10, 1e-2]);

    % Run Analysis Button
    btnRun = uibutton(pGrid, 'push', 'Text', 'Run Conformal Talbot Match', ...
                      'FontWeight', 'bold', 'BackgroundColor', [0.0, 0.45, 0.74], ...
                      'FontColor', 'white');

    % Right Area: Plot Panel
    panelRight = uipanel(grid, 'Title', 'Diagnostic Log-Log Bourdet Derivative', ...
                         'FontWeight', 'bold', 'FontSize', 12, ...
                         'BackgroundColor', 'white');
    axGrid = uigridlayout(panelRight, [1, 1]);
    ax = uiaxes(axGrid);
    ax.XScale = 'log';
    ax.YScale = 'log';
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    xlabel(ax, 'Dimensionless Time t_D', 'FontWeight', 'bold');
    ylabel(ax, 'Dimensionless Pressure & Bourdet Derivative', 'FontWeight', 'bold');
    title(ax, 'PetroLaplace: Stehfest-Free Conformal Talbot Integration');

    % Initial Plot execution
    updatePlot();

    % Callbacks
    btnRun.ButtonPushedFcn = @(btn, event) updatePlot();
    dropModel.ValueChangedFcn = @(dp, event) updatePlot();

    function updatePlot()
        t = logspace(-2, 5, 120);
        CD = editCD.Value;
        S = editSkin.Value;
        modelIdx = dropModel.Value;

        if contains(modelIdx, 'Radial')
            F_s = @(s) petrolaplace.model_radial_storage_skin(s, CD, S);
        elseif contains(modelIdx, 'Warren-Root')
            omega = editOmega.Value;
            lambda = editLambda.Value;
            F_s = @(s) (besselk(0, sqrt(s .* (omega + (1-omega).*lambda./(s + lambda)))) + S) ./ ...
                       (s .* (1 + s .* CD .* (besselk(0, sqrt(s .* (omega + (1-omega).*lambda./(s + lambda)))) + S)));
        else
            % Shale MFHW approx
            F_s = @(s) (sqrt(pi./(4.*s)) + S) ./ (s .* (1 + s .* CD .* (sqrt(pi./(4.*s)) + S)));
        end

        cla(ax);
        try
            [pD, dpD] = petrolaplace.invert_laplace(F_s, t);
            loglog(ax, t, pD, 'b-', 'LineWidth', 2.2, 'DisplayName', 'p_D (Pressure)');
            hold(ax, 'on');
            loglog(ax, t, dpD, 'r-', 'LineWidth', 2.0, 'DisplayName', 't_D \cdot p_D'' (Bourdet)');
            legend(ax, 'Location', 'northwest', 'FontWeight', 'bold');
            hold(ax, 'off');
        catch err
            uialert(fig, ['Error calculating model: ' err.message], 'Execution Error');
        end
    end
end
