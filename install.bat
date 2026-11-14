@echo off
setlocal EnableExtensions
REM Install / refresh Acesys Base as a Windows service (NSSM).
REM Secrets live in DPAPI vault — not in AppEnvironmentExtra / plaintext .env.
set "ROOT=C:\acesys-base"
set "REPO=https://github.com/fabianorios/acesys-base.git"
set "SVC=AcesysBase"
set "NSSM=%ROOT%\tools\nssm.exe"
set "VAULT=%ProgramData%\AcesysBase\secrets.dpapi"

net session >nul 2>&1
if errorlevel 1 (
  echo Run this install.bat as Administrator.
  exit /b 1
)

where git >nul 2>&1 || (echo git not found & exit /b 1)
where node >nul 2>&1 || (echo node not found & exit /b 1)
where npm >nul 2>&1 || (echo npm not found & exit /b 1)

if not exist "%ROOT%" mkdir "%ROOT%"
if exist "%ROOT%\.git" (
  echo Updating repo...
  pushd "%ROOT%"
  git pull --ff-only
  if errorlevel 1 (popd & exit /b 1)
  popd
) else (
  echo Cloning into %ROOT% ...
  if exist "%ROOT%\package.json" (
    echo Folder exists without .git — move old files aside, then re-run.
    exit /b 1
  )
  git clone "%REPO%" "%ROOT%"
  if errorlevel 1 exit /b 1
)

pushd "%ROOT%"
call npm install
if errorlevel 1 (popd & exit /b 1)
call npm install node-firebird
if errorlevel 1 (popd & exit /b 1)

if not exist ".env" if exist "env.example" copy /Y "env.example" ".env" >nul

REM Load optional service-account overrides from .env (ObjectName only)
if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="ACESYS_SERVICE_USER" set "ACESYS_SERVICE_USER=%%B"
    if /I "%%A"=="ACESYS_SERVICE_PASSWORD" set "ACESYS_SERVICE_PASSWORD=%%B"
  )
)

if not exist "%VAULT%" (
  echo.
  echo DPAPI vault missing: %VAULT%
  echo Run as the interactive Windows user who will own CurrentUser DPAPI:
  echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\vault.ps1" -Action Bootstrap
  echo Then re-run install.bat.
  popd
  exit /b 1
)

if not exist "tools" mkdir "tools"
if not exist "%NSSM%" (
  echo Place nssm.exe at %NSSM% then re-run.
  popd
  exit /b 1
)

if not exist "%ROOT%\serve.cmd" (
  echo Missing serve.cmd in %ROOT%
  popd
  exit /b 1
)

"%NSSM%" stop "%SVC%" >nul 2>&1
"%NSSM%" remove "%SVC%" confirm >nul 2>&1

"%NSSM%" install "%SVC%" "%ComSpec%" "/c" "%ROOT%\serve.cmd"
"%NSSM%" set "%SVC%" AppDirectory "%ROOT%"
"%NSSM%" set "%SVC%" DisplayName "Acesys Base Agent"
"%NSSM%" set "%SVC%" Description "Outbound-only Agent SDK host; DPAPI vault; playground login on 127.0.0.1"
"%NSSM%" set "%SVC%" Start SERVICE_AUTO_START
"%NSSM%" set "%SVC%" AppStdout "%ROOT%\logs\service.out.log"
"%NSSM%" set "%SVC%" AppStderr "%ROOT%\logs\service.err.log"
"%NSSM%" set "%SVC%" AppRotateFiles 1
"%NSSM%" set "%SVC%" AppRotateBytes 2097152
"%NSSM%" set "%SVC%" AppExit Default Restart
"%NSSM%" set "%SVC%" AppRestartDelay 5000

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs"

REM Prefer interactive / logon user so CurrentUser DPAPI decrypt works.
if defined ACESYS_SERVICE_USER (
  if defined ACESYS_SERVICE_PASSWORD (
    echo Setting ObjectName to %ACESYS_SERVICE_USER% ...
    "%NSSM%" set "%SVC%" ObjectName "%ACESYS_SERVICE_USER%" "%ACESYS_SERVICE_PASSWORD%"
    if errorlevel 1 (
      echo Failed to set ObjectName. Aborting — CurrentUser vault needs that account.
      popd
      exit /b 1
    )
  ) else (
    echo ACESYS_SERVICE_USER set but ACESYS_SERVICE_PASSWORD missing.
    echo Set both in .env ^(service account only^) or: nssm edit %SVC%
    popd
    exit /b 1
  )
) else (
  echo.
  echo ERROR: ACESYS_SERVICE_USER / ACESYS_SERVICE_PASSWORD required.
  echo CurrentUser DPAPI vault must be decrypted by the same Windows user who ran Bootstrap.
  echo Put them in %ROOT%\.env then re-run.
  popd
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\apply-env-to-nssm.ps1" -Root "%ROOT%" -Service "%SVC%" -Nssm "%NSSM%"

"%NSSM%" start "%SVC%"
if errorlevel 1 (
  echo Service start failed. Check %ROOT%\logs\service.err.log
  popd
  exit /b 1
)

if exist "%ROOT%\scripts\install-watchdog.cmd" (
  call "%ROOT%\scripts\install-watchdog.cmd"
)

echo.
echo OK. Login: http://127.0.0.1:3000/login
echo Service: %SVC%  Logs: %ROOT%\logs\
echo Vault: %VAULT% ^(DPAPI CurrentUser — not admin-proof^)
popd
endlocal
