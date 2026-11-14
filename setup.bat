@echo off
setlocal
cd /d "%~dp0"
if not exist "package.json" (
  echo Put this setup.bat inside the acesys-base folder and run again.
  exit /b 1
)
echo [1/3] npm install...
call npm install
if errorlevel 1 exit /b 1
echo [2/3] node-firebird...
call npm install node-firebird
if errorlevel 1 exit /b 1
echo [3/3] validate...
call npx --yes "@grok/agent-sdk@0.3.0" validate --dir .
if errorlevel 1 exit /b 1
echo.
echo Next on Windows:
echo   1. powershell -File scripts\vault.ps1 -Action Bootstrap
echo   2. set ACESYS_SERVICE_USER / PASSWORD in .env
echo   3. install.bat ^(Admin^)  or  start.bat
echo Login: http://127.0.0.1:3000/login
endlocal
