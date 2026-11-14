# Acesys Base — instalação Windows

Fluxo canônico no Agent Store: ver também a cópia do projeto em docs do store.

**Setup.exe:** baixar `AcesysBaseSetup.exe` (CI artifact `AcesysBaseSetup` ou `installer\pack.ps1`) → next-next em `C:\acesys-base` → `scripts\vault.ps1 -Action Bootstrap` → ObjectName → `http://127.0.0.1:3000/login`.

Segredos **não** vão no instalador. Ver `installer/FIRST-RUN.txt` e o README.
