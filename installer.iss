[Setup]
AppId={{5D0E1A7B-D544-4632-9F9C-B3026368C488}
AppName=Ticketing System
AppVersion=1.0
AppPublisher=Ticketing System
DefaultDirName={autopf}\Ticketing System
DisableProgramGroupPage=yes
; To generate a setup executable in the "installer" folder of your project
OutputDir=installer
OutputBaseFilename=TicketingSystem_Installer
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\ticketing_system.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "build\windows\x64\runner\Release\native_assets.json"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Ticketing System"; Filename: "{app}\ticketing_system.exe"
Name: "{autodesktop}\Ticketing System"; Filename: "{app}\ticketing_system.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ticketing_system.exe"; Description: "{cm:LaunchProgram,Ticketing System}"; Flags: nowait postinstall skipifsilent

