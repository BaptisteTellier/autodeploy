# Veeam Backup & Replication - Install License, Add Linux Proxy & Hardened Repository (PowerShell Module)
# VBR Server: 192.168.11.129
# Linux Proxy (JeOS): 192.168.11.130
# Linux Hardened Repository (JeOS): 192.168.11.131

# Variables
$vbrServer = "192.168.11.129"
$username = "veeamadmin"
$password = "123q123Q123!123"
$proxyIP = "192.168.11.130"
$proxyName = "LinuxProxy-130"
$repositoryIP = "192.168.11.131"
$repositoryName = "JeOSHardenedRepo-131"
$licenseFilePath = "K:\autodeploy vsa\packer\Veeam-100instances-entplus-monitoring-nfr.lic"

# Pairing codes from JeOS consoles (mettre les codes réels)
$pairingCodeProxy = "000000"       # Remplacer par le vrai code du proxy Linux
$pairingCodeRepo = "000000"        # Remplacer par le vrai code du repository hardened Linux
$linuxUsername = "veeamadmin"      # Utilisateur standard pour JeOS

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Veeam B&R - JeOS Proxy & Hardened Repository Deployment" -ForegroundColor Cyan
Write-Host "  Using PowerShell Module" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ==========================================
# STEP 1: LOAD VEEAM POWERSHELL MODULE
# ==========================================
Write-Host "`n[1/7] Loading Veeam PowerShell module..." -ForegroundColor Cyan

$VBRPSFolder = "C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell"

try {
    if (-not (Test-Path $VBRPSFolder)) { throw "Veeam PowerShell folder not found at: $VBRPSFolder" }
    Write-Host "  Loading Veeam assemblies..." -ForegroundColor Gray
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.Core.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.Core.Common.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.Common.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.Model.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.VimService.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.VimService.XmlSerializers.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.SpsService.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.SpsService.XmlSerializers.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.InvService.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.InvService.XmlSerializers.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.PbmService.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.VMware.VimApi.PbmService.XmlSerializers.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Rebex.Networking.dll" -ErrorAction Stop
    Add-Type -Path "$VBRPSFolder\..\Veeam.Backup.AzureAPI.dll" -ErrorAction Stop

    Write-Host "  Importing Veeam PowerShell module..." -ForegroundColor Gray
    Import-Module "$VBRPSFolder\..\Veeam.Backup.PowerShell.dll" -DisableNameChecking -ErrorAction Stop

    Write-Host "✓ Veeam PowerShell module loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load Veeam PowerShell module: $_" -ForegroundColor Red
    exit
}

# ==========================================
# STEP 2: CONNECT TO VBR SERVER
# ==========================================
Write-Host "`n[2/7] Connecting to VBR server..." -ForegroundColor Cyan
try {
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    Connect-VBRServer -Server $vbrServer -User $username -Password $password -ForceAcceptTlsCertificate -ErrorAction Stop
    Write-Host "✓ Connected to VBR server: $vbrServer" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to VBR server: $_" -ForegroundColor Red
    exit
}

# ==========================================
# STEP 3: INSTALL LICENSE
# ==========================================
Write-Host "`n[3/7] Installing license..." -ForegroundColor Cyan
if (Test-Path $licenseFilePath) {
    try {
        Install-VBRLicense -Path $licenseFilePath
        $license = Get-VBRInstalledLicense
        Write-Host "✓ License installed successfully!" -ForegroundColor Green
        Write-Host "  Licensed To: $($license.LicensedTo)" -ForegroundColor Gray
        Write-Host "  Edition: $($license.Edition)" -ForegroundColor Gray
        Write-Host "  Status: $($license.Status)" -ForegroundColor Gray
        Write-Host "  Expiration: $($license.ExpirationDate)" -ForegroundColor Gray
    } catch {
        Write-Host "⚠ License installation failed: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "⊘ License file not found, skipping license installation..." -ForegroundColor Yellow
}

# ==========================================
# STEP 5: ADD LINUX HOSTS
# ==========================================
Write-Host "`n[5/7] Adding Linux hosts with pairing code authentication..." -ForegroundColor Cyan

function Add-JeOSLinuxHost($ip, $pairing, $desc) {
    $existing = Get-VBRServer | Where-Object { $_.Name -eq $ip }
    if ($existing) {
        Write-Host "⊘ Linux host $ip already exists, skipping add." -ForegroundColor Yellow
        return $existing
    }
    else {
        Write-Host "  Adding Linux host: $ip" -ForegroundColor Gray
        return Add-VBRLinux -Name $ip -UseCertificate -HandshakeCode $pairing -ForceDeployerFingerprint -Description $desc
    }
}

$linuxProxy = Add-JeOSLinuxHost -ip $proxyIP -pairing $pairingCodeProxy -desc "Linux Proxy (JeOS)"
$linuxRepo = Add-VBRLinux -Name $repositoryIP -UseCertificate -HandshakeCode "000000" -ForceDeployerFingerprint -desc "Hardened Repository (JeOS)"

# Wait a moment for initialization
Write-Host "  Waiting for hosts to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# ==========================================
# STEP 6: CONFIGURE BACKUP PROXY
# ==========================================
Write-Host "`n[6/7] Configuring backup proxy role..." -ForegroundColor Cyan
try {
    $linuxProxy = Get-VBRServer | Where-Object { $_.Name -eq $proxyIP }
    if (-not $linuxProxy) { throw "Linux Proxy host not found in infrastructure" }

    # Check existing proxy
    $existingProxy = Get-VBRViProxy | Where-Object { $_.Host.Name -eq $proxyIP }
    if ($existingProxy) {
        Write-Host "⊘ Proxy already configured for $proxyIP" -ForegroundColor Yellow
    }
    else {
        Add-VBRViLinuxProxy -Server $linuxProxy -Description "Linux Backup Proxy (JeOS)" -MaxTasks 4
        Write-Host "✓ Proxy configured for $proxyIP" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Failed to configure backup proxy: $_" -ForegroundColor Yellow
}

# ==========================================
# STEP 7: CONFIGURE HARDENED REPOSITORY
# ==========================================
Write-Host "`n[7/7] Configuring hardened repository..." -ForegroundColor Cyan
try {
    $linuxRepo = Get-VBRServer | Where-Object { $_.Name -eq $repositoryIP }
    if (-not $linuxRepo) { throw "Linux Repository host not found in infrastructure" }

    # Check for existing hardened repo by name
    $existingRepo = Get-VBRBackupRepository | Where-Object { $_.Name -eq $repositoryName }
    if ($existingRepo) {
        Write-Host "⊘ Hardened repository '$repositoryName' already exists" -ForegroundColor Yellow
    }
    else {
        # Create new Linux Hardened Repository
        Add-VBRBackupRepository -Folder "/home/Admin/backups/" -Type Hardened -Name "Hardened Repository" -Server $linuxRepo -AutoSelectGateway -MountServer $linuxProxy -UsePerVMFile -EnableXFSFastClone -EnableBackupImmutability -ImmutabilityPeriod 21 -Force
        Write-Host "✓ Hardened repository '$repositoryName' created" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Failed to configure hardened repository: $_" -ForegroundColor Yellow
}

# ==========================================
# FINAL SUMMARY & CLEANUP
# ==========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $linuxServers = Get-VBRServer | Where-Object { $_.Type -eq "Linux" }
    Write-Host "`nLinux Hosts in infrastructure: $($linuxServers.Count)" -ForegroundColor Gray
    foreach ($s in $linuxServers) { Write-Host "  - $($s.Name)" -ForegroundColor Gray }

    $proxies = Get-VBRViProxy
    Write-Host "`nBackup Proxies: $($proxies.Count)" -ForegroundColor Gray
    foreach ($p in $proxies) {
        $status = if ($p.IsDisabled) { "[Disabled]" } else { "[Enabled]" }
        Write-Host "  - $($p.Name) $status" -ForegroundColor Gray
    }

    $repositories = Get-VBRBackupRepository
    Write-Host "`nBackup Repositories: $($repositories.Count)" -ForegroundColor Gray
    foreach ($r in $repositories) {
        Write-Host "  - $($r.Name)" -ForegroundColor Gray
    }

    Write-Host "`n✓ Deployment completed!" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not retrieve deployment summary" -ForegroundColor Yellow
}

# Disconnect from VBR
Disconnect-VBRServer

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Script execution completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
