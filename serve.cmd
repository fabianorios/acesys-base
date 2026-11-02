@echo off
cd /d C:\acesys-base
npx --yes "@grok/agent-sdk@0.3.0" serve --dir . --mode single --dev
