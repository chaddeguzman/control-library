@echo off
setlocal

set "PROJECT_ROOT=%~dp0"
set "RUNNER=%PROJECT_ROOT%5 harness\run-inbound-skill.ps1"

if not exist "%RUNNER%" (
    echo Runner not found:
    echo %RUNNER%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo Done.
) else (
    echo Finished with errors. Exit code: %EXIT_CODE%
)
pause
exit /b %EXIT_CODE%
