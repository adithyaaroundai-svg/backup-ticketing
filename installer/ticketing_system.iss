; Inno Setup script for AroundTally Ticketing
#define MyAppName "AroundTally Ticketing"
#define MyAppPublisher "AroundTally"
#define MyAppVersion "1.0.0"
#define MyAppExeName "ticketing_system.exe"
#define BuildOutputDir "..\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{BE849E3B-94C4-4BC4-BD1D-7D63C01C2A83}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\\AroundTally\\Ticketing
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\\build\\windows\\installer
OutputBaseFilename=AroundTally_Ticketing_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\\{#MyAppExeName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#BuildOutputDir}\\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion createallsubdirs

[Icons]
Name: "{autoprograms}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"
Name: "{autodesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
