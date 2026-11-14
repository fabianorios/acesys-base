@echo off
REM Acesys v2 — client reverse tunnel (template; no secrets)
REM Forwards local Firebird 3050 to VPS loopback 13050.
REM Replace placeholders before use. Do not commit filled copies.
setlocal EnableExtensions

set "VPS_HOST=REPLACE_WITH_VPS_HOST"
set "VPS_USER=acesys-tunnel"
set "LOCAL_FB_HOST=127.0.0.1"
set "LOCAL_FB_PORT=3050"
set "REMOTE_LISTEN=127.0.0.1:13050"
REM Optional: set "IDENTITY=-i C:\path\to\tunnel_key"

where ssh >nul 2>&1
if errorlevel 1 (
  echo OpenSSH client not found. Install "OpenSSH Client" optional feature, then retry.
  exit /b 1
)

echo Opening tunnel: VPS %REMOTE_LISTEN% -^> %LOCAL_FB_HOST%:%LOCAL_FB_PORT%
echo Leave this window open while using the agent on the VPS. Ctrl+C to close.
ssh -N -R %REMOTE_LISTEN%:%LOCAL_FB_HOST%:%LOCAL_FB_PORT% %IDENTITY% %VPS_USER%@%VPS_HOST%
set "EC=%ERRORLEVEL%"
echo Tunnel exited with code %EC%.
exit /b %EC%
