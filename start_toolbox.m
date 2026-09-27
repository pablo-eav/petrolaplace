function start_toolbox()
% START_TOOLBOX Initializes PetroLaplace Reservoir Core paths and displays banner
%
% Syntax:
%   start_toolbox
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez.

root_dir = fileparts(mfilename('fullpath'));

addpath(root_dir);
addpath(fullfile(root_dir, 'examples'));
addpath(fullfile(root_dir, 'tests'));
addpath(fullfile(root_dir, 'app'));
addpath(fullfile(root_dir, 'doc'));

fprintf('=================================================================\n');
fprintf('   PETROLAPLACE RESERVOIR CORE TOOLBOX v1.0.0 INITIALIZED        \n');
fprintf('   High-Performance PTA & Deconvolution Engine (Root-Free C99)   \n');
fprintf('   (C) 2026 Prof. Pablo Enrique Aballe Vázquez                   \n');
fprintf('=================================================================\n');
fprintf('  * Namespaced functions: +petrolaplace\n');
fprintf('  * Compile MEX native core: build_mex\n');
fprintf('  * Package Add-On (.mltbx): build_mltbx\n');
fprintf('  * Run interactive Studio:  PetroLaplaceApp\n');
fprintf('  * Run unit test suite:     run_all_tests\n');
fprintf('=================================================================\n\n');
end
