@echo off
setlocal
cd /d "%~dp0"
if not exist "package.json" (
  echo Put this start.bat inside C:\Users\fabia\agents\acesys-base and run again.
  exit /b 1
)
echo Starting Acesys SQL playground (http://127.0.0.1:3000/playground) ...
call npx --yes "@grok/agent-sdk@0.3.0" serve --dir . --mode single --dev
endlocal
