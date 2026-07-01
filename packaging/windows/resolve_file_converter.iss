#define AppVersion GetStringFileInfo("C:\resolve_file_converter\build\windows\x64\runner\Release\resolve_file_converter.exe", "ProductVersion")

[Setup]
AppName=Resolve Media Converter
AppVersion={#AppVersion}
AppPublisher=Resolve Media Converter
AppPublisherURL=https://github.com/rsevero/resolve_file_converter
DefaultDirName={commonpf}\Resolve Media Converter
DefaultGroupName=Resolve Media Converter
OutputDir=C:\resolve_file_converter\build\windows-installer
OutputBaseFilename=Resolve-Media-Converter-v{#AppVersion}-windows-x64
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "C:\resolve_file_converter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Resolve Media Converter"; Filename: "{app}\resolve_file_converter.exe"
Name: "{group}\Uninstall Resolve Media Converter"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\resolve_file_converter.exe"; Description: "Launch Resolve Media Converter"; Flags: nowait postinstall skipifsilent
