@echo off
REM Schedule ensure-acesys.ps1 every 2 minutes (SYSTEM). Run as Administrator.
setlocal
set "ROOT=C:\acesys-base"
set "TASK=AcesysBaseWatchdog"
set "PS1=%ROOT%\scripts\ensure-acesys.ps1"

net session >nul 2>&1
if errorlevel 1 (
  echo Run install-watchdog.cmd as Administrator.
  exit /b 1
)

if not exist "%PS1%" (
  echo Missing %PS1%
  exit /b 1
)

schtasks /Delete /TN "%TASK%" /F >nul 2>&1
schtasks /Create /TN "%TASK%" /SC MINUTE /MO 2 /RU SYSTEM /RL HIGHEST ^
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%PS1%\"" /F
if errorlevel 1 (
  echo Failed to create scheduled task %TASK%
  exit /b 1
)

echo OK. Task %TASK% runs every 2 minutes.
endlocal
