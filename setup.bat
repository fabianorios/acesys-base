@echo off
setlocal
cd /d "%~dp0"
if not exist "package.json" (
  echo Put this setup.bat inside C:\Users\fabia\agents\acesys-base and run again.
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
echo OK. Next: double-click start.bat or run it from this folder.
endlocal
