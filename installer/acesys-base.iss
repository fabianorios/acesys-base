; Acesys Base — Inno Setup (Admin). Secrets are NEVER baked into this Setup.
; Build: powershell -File installer\pack.ps1   (requires Inno Setup 6 + staged payload)
; Output: installer\dist\AcesysBaseSetup.exe

#define MyAppName "Acesys Base"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Acesys"

[Setup]
AppId={{B7E2C8A1-4F3D-4E9A-9C12-A1B2C3D4E5F6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName=C:\acesys-base
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=dist
OutputBaseFilename=AcesysBaseSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
InfoBeforeFile=FIRST-RUN.txt
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "service"; Description: "Register Windows service AcesysBase (NSSM, auto-start)"; Flags: checkedonce
Name: "watchdog"; Description: "Schedule 2-minute watchdog task"; Flags: checkedonce
Name: "desktopicon"; Description: "Desktop shortcut (local login URL)"; Flags: unchecked

[Files]
; Payload from pack.ps1 — must not contain .env / *.dpapi / secrets
Source: "staging\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Acesys Login"; Filename: "{cmd}"; Parameters: "/c start http://127.0.0.1:3000/login"; WorkingDir: "{app}"
Name: "{group}\Bootstrap vault (DPAPI)"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\vault.ps1"" -Action Bootstrap"; WorkingDir: "{app}"
Name: "{group}\Uninstall service"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\uninstall-service.ps1"""; WorkingDir: "{app}"
Name: "{commondesktop}\Acesys Login"; Filename: "{cmd}"; Parameters: "/c start http://127.0.0.1:3000/login"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\post-install.ps1"" -AppDir ""{app}"" -RegisterService ""{code:TaskFlag|service}"" -RegisterWatchdog ""{code:TaskFlag|watchdog}"""; \
  StatusMsg: "Configuring AcesysBase service..."; \
  Flags: runhidden waituntilterminated

; Do NOT run vault Bootstrap from elevated Setup — CurrentUser DPAPI would bind to Admin.
; Use Start Menu "Bootstrap vault" (or FIRST-RUN.txt) as the interactive Windows user.

Filename: "{cmd}"; \
  Parameters: "/c notepad.exe ""{app}\installer\FIRST-RUN.txt"""; \
  Description: "Open first-run instructions (vault Bootstrap as interactive user)"; \
  Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\installer\uninstall-service.ps1"" -AppDir ""{app}"""; \
  RunOnceId: "StopAcesysService"; \
  Flags: runhidden waituntilterminated

[Code]
function TaskFlag(Param: String): String;
begin
  if WizardIsTaskSelected(Param) then
    Result := '1'
  else
    Result := '0';
end;
