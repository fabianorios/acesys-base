@echo off
REM NSSM / interactive entry: decrypt DPAPI vault in-process, gate on :3000, agent on :3001.
cd /d "%~dp0"
where node >nul 2>&1 || (echo node not found & exit /b 1)
node "%~dp0scripts\host.mjs"
