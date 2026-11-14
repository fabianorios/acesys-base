@echo off
REM NSSM / Setup entry: decrypt DPAPI vault, gate on :3000, agent on :3001.
cd /d "%~dp0"
set "NODE_BIN=node"
if exist "%~dp0runtime\node.exe" set "NODE_BIN=%~dp0runtime\node.exe"
"%NODE_BIN%" -e "process.exit(0)" >nul 2>&1 || (
  echo Node.js not found. Reinstall with AcesysBaseSetup.exe or install Node 22+.
  exit /b 1
)
"%NODE_BIN%" "%~dp0scripts\host.mjs"
