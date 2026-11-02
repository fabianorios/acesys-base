@echo off
setlocal EnableExtensions
set "ROOT=C:\acesys-base"
set "REPO=https://github.com/fabianorios/acesys-base.git"
set "SVC=AcesysBase"
set "NSSM=%ROOT%\tools\nssm.exe"
net session >nul 2>&1
if errorlevel 1 (echo Run as Administrator. & exit /b 1)
where git >nul 2>&1 || (echo git not found & exit /b 1)
where node >nul 2>&1 || (echo node not found & exit /b 1)
where npm >nul 2>&1 || (echo npm not found & exit /b 1)
if not exist "%ROOT%" mkdir "%ROOT%"
if exist "%ROOT%\.git" (pushd "%ROOT%" & git pull --ff-only & popd) else (git clone "%REPO%" "%ROOT%" || exit /b 1)
pushd "%ROOT%"
call npm install || (popd & exit /b 1)
call npm install node-firebird || (popd & exit /b 1)
if not exist ".env" if exist "env.example" copy /Y "env.example" ".env" >nul
if not exist "tools" mkdir "tools"
if not exist "%NSSM%" (echo Place nssm.exe at %NSSM% & popd & exit /b 1)
if not exist "%ROOT%\serve.cmd" (echo Missing serve.cmd & popd & exit /b 1)
"%NSSM%" stop "%SVC%" >nul 2>&1
"%NSSM%" remove "%SVC%" confirm >nul 2>&1
"%NSSM%" install "%SVC%" "%ROOT%\serve.cmd"
"%NSSM%" set "%SVC%" AppDirectory "%ROOT%"
"%NSSM%" set "%SVC%" DisplayName "Acesys Base Agent"
"%NSSM%" set "%SVC%" Start SERVICE_AUTO_START
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs"
"%NSSM%" set "%SVC%" AppStdout "%ROOT%\logs\service.out.log"
"%NSSM%" set "%SVC%" AppStderr "%ROOT%\logs\service.err.log"
"%NSSM%" start "%SVC%"
echo OK. http://127.0.0.1:3000/playground
popd
endlocal
