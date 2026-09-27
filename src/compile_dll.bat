@echo off
setlocal
echo ====================================================================
echo COMPILACION C99 / x64 MSVC: ROOT-FREE RESERVOIR DLL
echo ====================================================================

call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

if errorlevel 1 (
    echo [ERROR] No se pudo inicializar el entorno vcvars64.bat
    exit /b 1
)

cd /d "%~dp0"

echo.
echo [1] Compilando root_free_reservoir_core.dll (Optimizacion /O2 /LD)...
cl.exe /O2 /LD /W3 /D_CRT_SECURE_NO_WARNINGS /DROOTFREE_EXPORTS ^
    root_free_reservoir_core.c ^
    /Fe:root_free_reservoir_core.dll ^
    /link /DLL /INCREMENTAL:NO

if errorlevel 1 (
    echo [ERROR] Fallo en la compilacion de la DLL.
    exit /b 1
)

echo.
echo [2] Compilando banco de pruebas nativo C (test_runner_reservoir.exe)...
cl.exe /O2 /W3 /D_CRT_SECURE_NO_WARNINGS ^
    test_runner_reservoir.c ^
    root_free_reservoir_core.lib ^
    /Fe:test_runner_reservoir.exe

if errorlevel 1 (
    echo [ERROR] Fallo en la compilacion del test runner.
    exit /b 1
)

echo.
echo ====================================================================
echo COMPILACION EXITOSA: root_free_reservoir_core.dll y test_runner_reservoir.exe
echo ====================================================================
