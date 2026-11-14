@echo off
setlocal
set "ROOT=C:\acesys-base"
set "SVC=AcesysBase"
set "TASK=AcesysBaseWatchdog"
set "NSSM=%ROOT%\tools\nssm.exe"

net session >nul 2>&1 || (echo Run as Administrator & exit /b 1)

schtasks /Delete /TN "%TASK%" /F >nul 2>&1

if not exist "%NSSM%" (
  echo nssm missing at %NSSM% — trying sc stop/delete
  sc stop "%SVC%" >nul 2>&1
  sc delete "%SVC%" >nul 2>&1
  echo Removed %SVC% ^(sc^) and task %TASK% if present
  endlocal
  exit /b 0
)

"%NSSM%" stop "%SVC%" >nul 2>&1
"%NSSM%" remove "%SVC%" confirm
echo Removed service %SVC% and watchdog task %TASK%
endlocal
