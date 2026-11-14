@echo off
setlocal
cd /d "%~dp0"
if not exist "package.json" (
  echo Run this from the acesys-base install folder.
  exit /b 1
)
echo Starting Acesys gate on http://127.0.0.1:3000/login ...
call "%~dp0serve.cmd"
endlocal
