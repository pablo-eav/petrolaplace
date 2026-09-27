function lic_info = license_status()
% LICENSE_STATUS Muestra el estado actual de la licencia de PetroLaplace™
%
% Sintaxis:
%   petrolaplace.license_status
%   info = petrolaplace.license_status
%
% Parte de PetroLaplace™ Reservoir Core Toolbox.
% Copyright (c) 2026 Pablo Enrique Aballe. Todos los derechos reservados.

if nargout > 0
    [~, lic_info] = petrolaplace.LicenseManager.check_status();
else
    petrolaplace.LicenseManager.display_status();
end

end
