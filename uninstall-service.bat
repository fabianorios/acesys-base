@echo off
setlocal
set "SVC=AcesysBase"
set "NSSM=C:\acesys-base\tools\nssm.exe"
net session >nul 2>&1 || (echo Run as Administrator & exit /b 1)
if not exist "%NSSM%" (echo nssm missing & exit /b 1)
"%NSSM%" stop "%SVC%"
"%NSSM%" remove "%SVC%" confirm
echo Removed %SVC%
endlocal
