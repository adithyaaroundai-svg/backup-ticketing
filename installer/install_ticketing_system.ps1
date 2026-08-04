# Run this script as Administrator.
# It installs the bundled test certificate and then installs the MSIX package.

param(
    [string]$InstallerFolder = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

$certPath = Join-Path $InstallerFolder 'test_certificate.cer'
$msixPath = Join-Path $InstallerFolder 'ticketing_system.msix'

if (-not (Test-Path $certPath)) {
    throw "Certificate file not found: $certPath"
}

if (-not (Test-Path $msixPath)) {
    throw "MSIX file not found: $msixPath"
}

Write-Host "Importing certificate $certPath into LocalMachine/TrustedPeople..."
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null

Write-Host "Installing MSIX package $msixPath..."
Add-AppxPackage -Path $msixPath -ForceApplicationShutdown

Write-Host 'Installation completed successfully.'
