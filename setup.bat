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
if not exist ".env" if exist "env.example" (
  copy /Y "env.example" ".env" >nul
  echo Created .env from env.example — edit CURSOR_API_KEY and ACESYS_FB_*.
)
echo.
echo OK. Dev: start.bat  ^|  Service: install.bat ^(Admin^)
endlocal
