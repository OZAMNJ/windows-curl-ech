$ErrorActionPreference = "Stop"
Write-Host "Downloading MSYS2 installer..."
$installerPath = Join-Path $env:TEMP "msys2-installer.exe"
Invoke-WebRequest -Uri "https://github.com/msys2/msys2-installer/releases/download/2024-05-07/msys2-x86_64-20240507.exe" -OutFile $installerPath

Write-Host "Installing MSYS2 silently..."
Start-Process -FilePath $installerPath -ArgumentList "in", "--confirm-command", "--accept-messages", "--root", "C:\msys64" -Wait -NoNewWindow

Write-Host "MSYS2 Installation complete."
