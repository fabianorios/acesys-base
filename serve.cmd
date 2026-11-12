@echo off
REM Entry point for NSSM / interactive start. Loopback only; secrets from .env.
cd /d "%~dp0"
if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if not "%%A"=="" set "%%A=%%B"
  )
)
if not defined CURSOR_API_KEY (
  echo WARNING: CURSOR_API_KEY missing. Set it in .env for model turns under the service account.
)
npx --yes "@grok/agent-sdk@0.3.0" serve --dir . --mode single --dev --host 127.0.0.1 --port 3000
