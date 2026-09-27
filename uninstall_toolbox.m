function uninstall_toolbox()
% UNINSTALL_TOOLBOX Removes PetroLaplace Reservoir Core paths from MATLAB environment
%
% Syntax:
%   uninstall_toolbox
%
% Part of PetroLaplace™ Reservoir Core Toolbox.

root_dir = fileparts(mfilename('fullpath'));

rmpath(root_dir);
rmpath(fullfile(root_dir, 'examples'));
rmpath(fullfile(root_dir, 'tests'));
rmpath(fullfile(root_dir, 'app'));
rmpath(fullfile(root_dir, 'doc'));

fprintf('PetroLaplace Toolbox paths have been successfully removed from MATLAB.\n');
end
