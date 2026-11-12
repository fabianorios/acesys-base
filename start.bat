@echo off
setlocal
cd /d "%~dp0"
if not exist "package.json" (
  echo Run this from the acesys-base install folder.
  exit /b 1
)
if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if not "%%A"=="" set "%%A=%%B"
  )
)
echo Starting Acesys playground on http://127.0.0.1:3000/playground ...
call "%~dp0serve.cmd"
endlocal
