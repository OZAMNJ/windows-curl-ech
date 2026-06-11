$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

$MsysVersion = "20240507"
$InstallerUrl = "https://github.com/msys2/msys2-installer/releases/download/2024-05-07/msys2-x86_64-$MsysVersion.exe"
$HashUrl = "https://github.com/msys2/msys2-installer/releases/download/2024-05-07/msys2-x86_64-$MsysVersion.exe.sha256"

$installerPath = Join-Path $env:TEMP "msys2-installer.exe"
$hashPath = Join-Path $env:TEMP "msys2-installer.exe.sha256"

function Log-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Log-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

try {
    Log-Info "Downloading MSYS2 installer version $MsysVersion..."
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerPath -UseBasicParsing
    
    Log-Info "Downloading MSYS2 SHA256 checksum..."
    Invoke-WebRequest -Uri $HashUrl -OutFile $hashPath -UseBasicParsing
    
    # Validation
    if (!(Test-Path $installerPath) -or (Get-Item $installerPath).Length -eq 0) {
        throw "Installer download failed or file is empty."
    }

    Log-Info "Verifying SHA256 Checksum..."
    $expectedHashLine = Get-Content $hashPath | Select-Object -First 1
    $expectedHash = $expectedHashLine.Split(' ')[0].Trim().ToUpper()
    $actualHash = (Get-FileHash -Path $installerPath -Algorithm SHA256).Hash.ToUpper()

    if ($expectedHash -ne $actualHash) {
        throw "Hash mismatch! Expected: $expectedHash, Got: $actualHash"
    }
    Log-Info "Hash verification successful!"

    Log-Info "Installing MSYS2 silently to C:\msys64..."
    $process = Start-Process -FilePath $installerPath -ArgumentList "in", "--confirm-command", "--accept-messages", "--root", "C:\msys64" -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        throw "Installer exited with non-zero code: $($process.ExitCode)"
    }
    
    Log-Info "MSYS2 Installation complete."
}
catch {
    Log-Error $_.Exception.Message
    exit 1
}
finally {
    if (Test-Path $installerPath) { Remove-Item $installerPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $hashPath) { Remove-Item $hashPath -Force -ErrorAction SilentlyContinue }
}
