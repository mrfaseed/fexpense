; Inno Setup Script for FExpense
; Generates a professional Windows Setup Wizard with custom directory selection

#define MyAppName "FExpense"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Faseed"
#define MyAppURL "https://github.com/faseed/fexpense"
#define MyAppExeName "fexpense.exe"

[Setup]
; AppId uniquely identifies this application in Windows registry for updates & uninstall
AppId={{D81977D1-9D29-4506-9EEB-C7A70498F1D2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Default directory (C:\Program Files\FExpense) - User is prompted and can change this
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

; Explicitly show the folder selection page so user can choose C:\ or another drive
DisableDirPage=no
DisableProgramGroupPage=no

; Output settings
OutputDir=..\..\build\installer
OutputBaseFilename=FExpense_Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; Branding & Icons
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Privileges
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; Release executable and all dependencies from Flutter build
Source: "..\..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\{#MyAppName}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
