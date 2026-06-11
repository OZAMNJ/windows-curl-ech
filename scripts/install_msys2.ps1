$ErrorActionPreference = "Stop"
Write-Host "Downloading MSYS2 installer..."
Invoke-WebRequest -Uri "https://github.com/msys2/msys2-installer/releases/download/2024-01-13/msys2-x86_64-20240113.exe" -OutFile "C:\Users\PRAJA\.gemini\antigravity-ide\scratch\msys2-installer.exe"

Write-Host "Installing MSYS2 silently..."
Start-Process -FilePath "C:\Users\PRAJA\.gemini\antigravity-ide\scratch\msys2-installer.exe" -ArgumentList "in --confirm-command --accept-messages --root C:\msys64" -Wait -NoNewWindow

Write-Host "MSYS2 Installation complete."
