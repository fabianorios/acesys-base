@echo off
setlocal EnableExtensions
REM Install / refresh Acesys Base as a Windows service (NSSM).
REM Run as Administrator. Secrets stay in local .env only.
set "ROOT=C:\acesys-base"
set "REPO=https://github.com/fabianorios/acesys-base.git"
set "SVC=AcesysBase"
set "NSSM=%ROOT%\tools\nssm.exe"

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

if not exist ".env" (
  if exist "env.example" copy /Y "env.example" ".env" >nul
  echo Created .env — edit CURSOR_API_KEY and ACESYS_FB_* before starting.
)

REM Load optional service-account overrides from .env into this shell
if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="ACESYS_SERVICE_USER" set "ACESYS_SERVICE_USER=%%B"
    if /I "%%A"=="ACESYS_SERVICE_PASSWORD" set "ACESYS_SERVICE_PASSWORD=%%B"
    if /I "%%A"=="CURSOR_API_KEY" set "HAS_CURSOR_KEY=1"
  )
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
"%NSSM%" set "%SVC%" Description "Outbound-only Agent SDK host; Firebird tools bridge local DB; playground on 127.0.0.1"
"%NSSM%" set "%SVC%" Start SERVICE_AUTO_START
"%NSSM%" set "%SVC%" AppStdout "%ROOT%\logs\service.out.log"
"%NSSM%" set "%SVC%" AppStderr "%ROOT%\logs\service.err.log"
"%NSSM%" set "%SVC%" AppRotateFiles 1
"%NSSM%" set "%SVC%" AppRotateBytes 2097152
"%NSSM%" set "%SVC%" AppExit Default Restart
"%NSSM%" set "%SVC%" AppRestartDelay 5000

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs"

REM Prefer interactive / logon user. Local System cannot use agent-sdk login profile.
if defined ACESYS_SERVICE_USER (
  if defined ACESYS_SERVICE_PASSWORD (
    echo Setting ObjectName to %ACESYS_SERVICE_USER% ...
    "%NSSM%" set "%SVC%" ObjectName "%ACESYS_SERVICE_USER%" "%ACESYS_SERVICE_PASSWORD%"
    if errorlevel 1 (
      echo Failed to set ObjectName. Falling back to Local System + AppEnvironmentExtra.
    )
  ) else (
    echo ACESYS_SERVICE_USER set but ACESYS_SERVICE_PASSWORD missing — keeping default account.
    echo Prefer: set both in .env, or run: nssm edit %SVC%
  )
) else (
  echo No ACESYS_SERVICE_USER in .env — service account stays Local System.
  echo Prefer the interactive Windows user via ACESYS_SERVICE_USER / ACESYS_SERVICE_PASSWORD,
  echo and always set CURSOR_API_KEY in .env ^(applied via AppEnvironmentExtra^).
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\apply-env-to-nssm.ps1" -Root "%ROOT%" -Service "%SVC%" -Nssm "%NSSM%"
if errorlevel 1 (
  echo WARNING: could not apply .env to AppEnvironmentExtra
)

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
echo OK. Playground ^(loopback only^): http://127.0.0.1:3000/playground
echo Service: %SVC%
echo Logs: %ROOT%\logs\
if not defined HAS_CURSOR_KEY echo Reminder: set CURSOR_API_KEY in %ROOT%\.env then re-run apply-env or install.bat
echo Firebird DSN stays in local .env — never commit .env
popd
endlocal
