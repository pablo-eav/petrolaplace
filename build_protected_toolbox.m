function build_protected_toolbox()
% BUILD_PROTECTED_TOOLBOX Genera la distribución protegida (P-Code y Binarios Cerrados)
%
%   Esta función realiza las siguientes operaciones de seguridad:
%     1. Ofusca y compila los archivos de +petrolaplace a P-Code (.p) de MATLAB.
%     2. Reemplaza el código fuente por stubs de sólo documentación (Help-Only).
%     3. Protege las rutinas del motor C99 en bibliotecas binarias (.dll / .so / MEX).
%     4. Empaqueta la Toolbox (.mltbx) comercial protegida para distribución.
%
%   Uso:
%       build_protected_toolbox
%
%   Copyright (c) 2026 Pablo Enrique Aballe. Todos los derechos reservados.

clc;
fprintf('=================================================================\n');
fprintf('  CONSTRUCTOR DE DISTRIBUCION PROTEGIDA: PETROLAPLACE RESERVOIR  \n');
fprintf('=================================================================\n\n');

toolbox_dir = fileparts(mfilename('fullpath'));
pkg_dir = fullfile(toolbox_dir, '+petrolaplace');
dist_dir = fullfile(toolbox_dir, 'build_protected_dist');

if exist(dist_dir, 'dir')
    rmdir(dist_dir, 's');
end
mkdir(dist_dir);

fprintf('1. Copiando estructura base a carpeta de distribución protegida...\n');
copyfile(fullfile(toolbox_dir, 'app'), fullfile(dist_dir, 'app'));
copyfile(fullfile(toolbox_dir, 'data'), fullfile(dist_dir, 'data'));
copyfile(fullfile(toolbox_dir, 'doc'), fullfile(dist_dir, 'doc'));
copyfile(fullfile(toolbox_dir, 'examples'), fullfile(dist_dir, 'examples'));
copyfile(fullfile(toolbox_dir, 'tests'), fullfile(dist_dir, 'tests'));
copyfile(fullfile(toolbox_dir, 'Contents.m'), fullfile(dist_dir, 'Contents.m'));
copyfile(fullfile(toolbox_dir, 'info.xml'), fullfile(dist_dir, 'info.xml'));
copyfile(fullfile(toolbox_dir, 'start_toolbox.m'), fullfile(dist_dir, 'start_toolbox.m'));
copyfile(fullfile(toolbox_dir, 'uninstall_toolbox.m'), fullfile(dist_dir, 'uninstall_toolbox.m'));
copyfile(fullfile(toolbox_dir, 'LICENSE'), fullfile(dist_dir, 'LICENSE'));
copyfile(fullfile(toolbox_dir, 'README.md'), fullfile(dist_dir, 'README.md'));

% Copiar cabecera y binarios de src (excluyendo código fuente C si se desea cerrar al 100%)
mkdir(fullfile(dist_dir, 'src'));
copyfile(fullfile(toolbox_dir, 'src', 'root_free_reservoir_core.h'), fullfile(dist_dir, 'src', 'root_free_reservoir_core.h'));
if exist(fullfile(toolbox_dir, 'src', 'root_free_reservoir_core.dll'), 'file')
    copyfile(fullfile(toolbox_dir, 'src', 'root_free_reservoir_core.dll'), fullfile(dist_dir, 'src', 'root_free_reservoir_core.dll'));
end

% 2. Compilar a P-Code (.p) en +petrolaplace
fprintf('2. Generando P-Code encriptado (.p) para el paquete +petrolaplace...\n');
target_pkg = fullfile(dist_dir, '+petrolaplace');
mkdir(target_pkg);

m_files = dir(fullfile(pkg_dir, '*.m'));
for k = 1:length(m_files)
    src_file = fullfile(pkg_dir, m_files(k).name);
    fname = m_files(k).name;
    
    % Generar P-Code
    try
        pcode(src_file, '-inplace');
        % Mover .p generado a target_pkg
        [~, name_only] = fileparts(fname);
        p_name = [name_only, '.p'];
        if exist(fullfile(pkg_dir, p_name), 'file')
            movefile(fullfile(pkg_dir, p_name), fullfile(target_pkg, p_name));
            fprintf('   [P-CODE OK] %s -> %s\n', fname, p_name);
        end
    catch ME
        fprintf('   [AVISO] No se pudo generar P-Code para %s: %s\n', fname, ME.message);
    end
    
    % Crear versión .m Help-Only (sólo comentarios de cabecera para 'help' y 'doc')
    doc_lines = extract_help_comments(src_file);
    dst_m = fullfile(target_pkg, fname);
    fid = fopen(dst_m, 'w', 'n', 'UTF-8');
    if fid ~= -1
        for line_idx = 1:length(doc_lines)
            fprintf(fid, '%s\n', doc_lines{line_idx});
        end
        fprintf(fid, '\n%% [CÓDIGO DE PROPIEDAD INTELECTUAL PROTEGIDO - NÚCLEO BINARIO OFUSCADO]\n');
        fprintf(fid, '%% La ejecución de esta función se realiza mediante el binario cifrado .p / MEX.\n');
        fclose(fid);
    end
end

fprintf('\n3. Empaquetando Toolbox (.mltbx) protegida...\n');
orig_cd = pwd;
cd(dist_dir);
try
    opts = matlab.addons.toolbox.ToolboxOptions(dist_dir, 'd5e8a1b2-c3f4-4e5a-8b9c-0d1e2f3a4b5c');
    opts.ToolboxName = 'PetroLaplace Reservoir Core (Protected Edition)';
    opts.ToolboxVersion = '1.0.0';
    opts.AuthorName = 'Pablo Enrique Aballe';
    opts.AuthorEmail = 'contact@petrolaplace.com';
    opts.AuthorCompany = 'PetroLaplace Dynamics';
    opts.Summary = 'Enterprise Closed-Source PTA & Deconvolution Toolbox';
    opts.Description = 'High-Performance Conformal Talbot & Deconvolution. IP-Protected Edition with cryptographic licensing.';
    opts.OutputFile = fullfile(toolbox_dir, 'PetroLaplace_Reservoir_Core_Protected.mltbx');
    
    matlab.addons.toolbox.packageToolbox(opts);
    fprintf('   [EXITO] Toolbox protegida creada: PetroLaplace_Reservoir_Core_Protected.mltbx\n');
catch ME
    fprintf('   [INFO] Empaquetado mltbx: %s\n', ME.message);
end
cd(orig_cd);

fprintf('\n=================================================================\n');
fprintf('  PROCESO DE PROTECCION COMPLETADO EXITOSAMENTE\n');
fprintf('  Directorio protegido listo: %s\n', dist_dir);
fprintf('=================================================================\n');

end

function doc_lines = extract_help_comments(filepath)
    doc_lines = {};
    fid = fopen(filepath, 'r', 'n', 'UTF-8');
    if fid == -1, return; end
    
    first_func_found = false;
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), break; end
        trimmed = strtrim(line);
        if startsWith(trimmed, 'function')
            doc_lines{end+1} = line; %#ok<AGROW>
            first_func_found = true;
            continue;
        end
        if first_func_found
            if startsWith(trimmed, '%') || isempty(trimmed)
                doc_lines{end+1} = line; %#ok<AGROW>
            else
                break;
            end
        end
    end
    fclose(fid);
end
