function success = activate(key, email)
% ACTIVATE Activa una clave comercial o académica para PetroLaplace™ Reservoir Core
%
% Sintaxis:
%   petrolaplace.activate('SU-CLAVE-DE-PRODUCTO')
%   petrolaplace.activate('SU-CLAVE-DE-PRODUCTO', 'su-email@empresa.com')
%
% Parte de PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Pablo Enrique Aballe. Todos los derechos reservados.

if nargin < 1 || isempty(key)
    fprintf('===============================================================================\n');
    fprintf(' ACTIVACION DE LICENCIA - PETROLAPLACE™ RESERVOIR CORE TOOLBOX                 \n');
    fprintf('===============================================================================\n');
    fprintf(' Uso: petrolaplace.activate(''CLAVE-PRODUCTO'', ''su-email@empresa.com'')       \n');
    fprintf(' Su Host ID actual: %s\n', petrolaplace.LicenseManager.get_host_id());
    fprintf(' Adquiera su clave comercial en: https://mathworks.com/products/connections     \n');
    fprintf('===============================================================================\n');
    success = false;
    return;
end

if nargin < 2
    email = '';
end

success = petrolaplace.LicenseManager.activate(key, email);

end
