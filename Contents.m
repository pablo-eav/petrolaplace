% PETROLAPLACE RESERVOIR CORE TOOLBOX
% Version 1.0.3 (R2024b) 27-Sep-2026
%
% High-Performance Numerical Laplace Inversion and Pressure Transient
% Analysis (PTA) Engine for Petroleum Reservoir Engineering.
%
% Author: Prof. Pablo Enrique Aballe Vázquez
% Instituto Internacional de Investigación en Física Matemática y Aeroespacial Laplace
%
% Namespaced Package Functions (+petrolaplace):
%   petrolaplace.invert_laplace           - Conformal Talbot contour complex Laplace inversion.
%   petrolaplace.deconvolve               - Non-iterative Toeplitz-Tikhonov Cholesky deconvolution.
%   petrolaplace.bourdet_derivative       - Smooth infinitesimal logarithmic Bourdet derivative.
%   petrolaplace.analyze_well             - Complete automated well test analysis workflow.
%   petrolaplace.model_radial_storage_skin - Standard vertical well with storage and skin.
%   petrolaplace.activate                 - Activate commercial/academic license key.
%   petrolaplace.license_status           - Query active license status, trial days, and Host ID.
%
% Build and Packaging Utilities:
%   build_mex                             - Compiles the native C99 computational kernels to MEX.
%   build_mltbx                           - Packages the toolbox into an official MATLAB .mltbx Add-On.
%   build_protected_toolbox               - Generates encrypted P-code (.p) distribution and protected .mltbx.
%   start_toolbox                         - Adds toolbox paths and verifies installation.
%   uninstall_toolbox                     - Removes toolbox paths from MATLAB environment.
%
% Examples and Tutorials:
%   examples/ex01_bourdet_storage_skin.m  - Bourdet storage & skin match vs Stehfest.
%   examples/ex02_warren_root_carbonate.m - Naturally fractured dual-porosity reservoir.
%   examples/ex03_shale_horizontal_mfhw.m - Multi-fractured horizontal well in tight shale.
%   examples/ex04_multirate_deconvolution.m - Variable-rate deconvolution under noisy gauges.
%
% Interactive Desktop Application:
%   app/PetroLaplaceApp                   - Interactive GUI studio for PTA analysis.
%
% Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez. All Rights Reserved.
