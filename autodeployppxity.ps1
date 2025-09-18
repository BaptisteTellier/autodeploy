<#
.SYNOPSIS
Automates customization of Veeam Appliance ISO: grub, kickstart, license, node_exporter with error handling, logging, and parameterization.

What you need before you run this script : 

If you want to tune VBR : 
"license" folder with .lic inside it

If you want to deploy node_exporter : 
"node_exporter" folder with extracted binary 'NOTICE' 'node_exporter' 'LICENSE'
https://github.com/prometheus/node_exporter/releases

VSA ISO : 
VeeamSoftwareAppliance_13.0.0.4967_20250822.iso

complete bellow parameters

 
#>

#region Parameters
param (
    [string]$LocalISO = "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso",
    [int]$GrubTimeout = 30,
    [string]$KeyboardLayout = "fr",
    [string]$Timezone = "Europe/Paris",
    [string]$VeeamAdminPassword = "123q123Q123!123",
    [string]$VeeamAdminMfaSecretKey = "JBSWY3DPEHPK3PXP",
    [string]$VeeamAdminIsMfaEnabled = "false",
    [string]$VeeamSoPassword = "123w123W123!123",
    [string]$VeeamSoMfaSecretKey = "JBSWY3DPEHPK3PXP",
    [string]$VeeamSoIsMfaEnabled = "true",
    [string]$VeeamSoRecoveryToken = "eb9fcbf4-2be6-e94d-4203-dded67c5a450",
    [string]$VeeamSoIsEnabled = "true",
    [string]$NtpServer = "time.nist.gov",
    [string]$NtpRunSync = "false",
    [bool]$NodeExporter = $true,
    [bool]$LicenseVBRTune = $true,
    [string]$LicenseFile = "Veeam-100instances-entplus-monitoring-nfr.lic",
    [string]$SyslogServer = "172.17.53.28"
)
#endregion

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Warn','Error')][string]$Level = 'Info'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        'Info'  { Write-Host "[$timestamp][INFO] $Message" -ForegroundColor Cyan }
        'Warn'  { Write-Warning "[$timestamp][WARN] $Message" }
        'Error' { Write-Host "[$timestamp][ERROR] $Message" -ForegroundColor Red }
    }
}

#endregion

#region Helper Functions

function Safe-ExternalCommand {
    param([string]$Command)
    try {
        Invoke-Expression $Command
        Write-Log "Succeeded: $Command" 'Info'
        return $true
    } catch {
        Write-Log "Failed: $Command - $($_.Exception.Message)" 'Error'
        return $false
    }
}

function Validate-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Log "File not found: $Path" 'Error'
        throw "File not found: $Path"
    }
}

function Replace-InFile {
    param(
        [string]$FilePath,
        [string]$Pattern,
        [string]$Replacement
    )
    try {
        $content = Get-Content $FilePath
        $content = $content -replace $Pattern, $Replacement
        Set-Content $FilePath $content
        Write-Log "Replaced pattern in $FilePath" 'Info'
    } catch {
        Write-Log "Replace in file failed: $($_.Exception.Message)" 'Error'
        throw
    }
}

function Insert-AfterLine {
    param(
        [string]$FilePath,
        [string]$TargetLine,
        [string[]]$LinesToInsert
    )
    try {
        $content = Get-Content $FilePath
        $idx = $content.IndexOf($TargetLine)
        if ($idx -ge 0) {
            $newContent = $content[0..$idx] + $LinesToInsert + $content[($idx+1)..($content.Count-1)]
            Set-Content $FilePath $newContent
            Write-Log "Inserted block after '$TargetLine' in $FilePath" 'Info'
        } else {
            Write-Log "Target line '$TargetLine' not found in $FilePath" 'Warn'
        }
    } catch {
        Write-Log "Insert after line failed: $($_.Exception.Message)" 'Error'
        throw
    }
}

#endregion

#region Main Script

try {
    #region Validate Inputs
    Validate-File -Path $LocalISO
    #endregion

    #region Extract Files from ISO
    $extractCmds = @(
        "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -osirrox on -extract vbr-ks.cfg vbr-ks.cfg *> `$null",
        "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -osirrox on -extract /EFI/BOOT/grub.cfg grub.cfg *> `$null"
    )
    foreach ($cmd in $extractCmds) {
        if (-not (Safe-ExternalCommand $cmd)) { throw "Failed ISO extraction." }
    }
    Validate-File -Path "vbr-ks.cfg"
    Validate-File -Path "grub.cfg"
    #endregion

    #region Edit grub.cfg
    # Add inst.assumeyes
    Replace-InFile -FilePath "grub.cfg" -Pattern '^(.*LABEL=Rocky-9-2-x86_64:/vbr-ks.cfg quiet.*)$' -Replacement '${1} inst.assumeyes'
    # Set default boot option
    $newDefault = '"Veeam Backup & Replication v13.0>Install - fresh install, wipes everything (including local backups)"'
    Replace-InFile -FilePath "grub.cfg" -Pattern 'set default=.*' -Replacement "set default=$newDefault"
    # Set GRUB timeout
    Replace-InFile -FilePath "grub.cfg" -Pattern 'set timeout=.*' -Replacement "set timeout=$GrubTimeout"
    #endregion

    #region Edit vbr-ks.cfg
    # Set Keyboard layout
    Replace-InFile -FilePath "vbr-ks.cfg" -Pattern "keyboard --xlayouts='us'" -Replacement "keyboard --xlayouts='$KeyboardLayout'"
    # Set Timezone
    Replace-InFile -FilePath "vbr-ks.cfg" -Pattern "timezone Etc/UTC --utc" -Replacement "timezone $Timezone --utc"
    # Disable init wizard in Kickstart
    Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine 'mkdir -p /var/log/veeam/' -LinesToInsert @('touch /etc/veeam/cockpit_auto_test_disable_init')
    Write-Log "Kickstart disable init wizard added" 'Info'
    #endregion

    #region Blocks for string to add to kickstart

    $CustomVBRBlock = @(
        "# Custom VBR config",
        "pwsh -Command '",
        "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
        "Install-VBRLicense -Path /etc/veeam/license/$LicenseFile",
        "Add-VBRSyslogServer -ServerHost '$SyslogServer' -Port 514 -Protocol Udp",
        "'"
    )
    $CopyLicBlock = @(
        "# Copy Veeam license file from ISO to OS /etc/veeam/license/",
        "mkdir -p /mnt/sysimage/etc/veeam/license/",
        "if [ -f /mnt/install/repo/license/$LicenseFile ]; then",
        "  cp -f /mnt/install/repo/license/$LicenseFile /mnt/sysimage/etc/veeam/license/$LicenseFile",
        "  chmod 600 /mnt/sysimage/etc/veeam/license/$LicenseFile",
        "  chown root:root /mnt/sysimage/etc/veeam/license/$LicenseFile",
        "fi"
    )
    $CopyNodeExporterBlock = @(
        "# Create directory for node_exporter and move to OS /etc/node_exporter",
        "mkdir -p /mnt/sysimage/etc/node_exporter",
        "if [ -d /mnt/install/re po/node_exporter ]; then",
        "    cp -r /mnt/install/repo/node_exporter /mnt/sysimage/etc/",
        "fi"
    )
    $NodeExporterSetupBlock = @(
        "#node_exporter",
        "",
        "sudo groupadd -f node_exporter",
        "sudo useradd -g node_exporter --no-create-home --shell /bin/false node_exporter",
        "sudo chown node_exporter:node_exporter /etc/node_exporter",
        "",
        "cat << EOF >> /etc/systemd/system/node_exporter.service",
        "[Unit]",
        "Description=Node Exporter",
        "Documentation=https://prometheus.io/docs/guides/node-exporter/",
        "Wants=network-online.target",
        "After=network-online.target",
        "",
        "[Service]",
        "User=node_exporter",
        "Group=node_exporter",
        "Type=simple",
        "Restart=on-failure",
        "ExecStart=/etc/node_exporter/node_exporter --web.listen-address=:9100",
        "",
        "[Install]",
        "WantedBy=multi-user.target",
        "EOF",
        "",
        "sudo chmod 664 /etc/systemd/system/node_exporter.service",
        "",
        "#config and setup Node_exporter",
        "sudo systemctl daemon-reload",
        "sudo systemctl start node_exporter",
        "sudo systemctl enable node_exporter.service"
    )
    $Node_ExporterFWBlock = @(
        "#Add Node_Exporter to FW",
        "sudo firewall-cmd --permanent --zone=drop --add-port=9100/tcp",
        "sudo firewall-cmd --reload"
    )
    $HostConfigBlock = @(
        "###############################################################################",
        "# Automatic Host Manager configuration file",
        "###############################################################################",
        "cat << EOF >> /etc/veeam/vbr_init.cfg",
        "veeamadmin.password=$VeeamAdminPassword",
        "veeamadmin.mfaSecretKey=$VeeamAdminMfaSecretKey",
        "veeamadmin.isMfaEnabled=$VeeamAdminIsMfaEnabled",
        "veeamso.password=$VeeamSoPassword",
        "veeamso.mfaSecretKey=$VeeamSoMfaSecretKey",
        "veeamso.isMfaEnabled=$VeeamSoIsMfaEnabled",
        "veeamso.recoveryToken=$VeeamSoRecoveryToken",
        "veeamso.isEnabled=$VeeamSoIsEnabled",
        "ntp.servers=$NtpServer",
        "ntp.runSync=$NtpRunSync",
        "vbr_control.runInitIso=true",
        "vbr_control.runStart=true",
        "EOF",
        "###############################################################################",
        "# Automatic Host Manager configuration TRIGGER AFTER REBOOT",
        "###############################################################################",
        "set -e",
        "cat << EOF >> /etc/veeam/veeam-init.sh",
        "#!/bin/bash",
        "set -eE -u -o pipefail",
        "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg",
        "systemctl disable veeam-init",
        "EOF",
        "chmod +x /etc/veeam/veeam-init.sh",
        "cat << EOF >> /etc/systemd/system/veeam-init.service",
        "[Unit]",
        "Description=One-shot daemon to run /opt/veeam/hostmanager/veeamhostmanager at next boot",
        "[Service]",
        "Type=oneshot",
        "ExecStart=/etc/veeam/veeam-init.sh",
        "RemainAfterExit=no",
        "[Install]",
        "WantedBy=multi-user.target",
        "EOF",
        "# Enable the service for next boot",
        "systemctl enable veeam-init.service",
        "###############################################################################"
    )
    

    #endregion

    #region Insert Blocks into vbr-ks.cfg
    
    # Insert Host Configuration block
    Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -LinesToInsert $HostConfigBlock

    if ($LicenseVBRTune) {
        Write-Log "License VBR tuning block insert enabled" 'Info'
        Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -LinesToInsert $CustomVBRBlock
        Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -LinesToInsert $CopyLicBlock
        Safe-ExternalCommand "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -map license /license *> `$null"
        Write-Log "License folder copied to ISO" 'Info'
    }

    if ($NodeExporter) {
        Write-Log "Node exporter block insert enabled" 'Info'
        Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -LinesToInsert $NodeExporterSetupBlock
        Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -LinesToInsert $CopyNodeExporterBlock
        Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -LinesToInsert $Node_ExporterFWBlock
        Safe-ExternalCommand "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -map node_exporter /node_exporter *> `$null"
        Write-Log "Node exporter folder copied to ISO" 'Info'
    }


    #endregion

    #region Normalize Line Endings
    (Get-Content "vbr-ks.cfg" -Raw).Replace("`r`n", "`n") | Set-Content "vbr-ks.cfg"
    (Get-Content "grub.cfg" -Raw).Replace("`r`n", "`n") | Set-Content "grub.cfg"
    Write-Log "Normalized line endings." 'Info'
    #endregion

    #region Commit Changes Into ISO
    Write-Log "Merging custom kickstart and grub into ISO" 'Info'
    $commitCmds = @(
        "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -rm vbr-ks.cfg *> `$null",
        "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -map vbr-ks.cfg vbr-ks.cfg *> `$null",
        "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -rm /EFI/BOOT/grub.cfg *> `$null",
        "wsl xorriso -boot_image any keep -dev `"$LocalISO`" -map grub.cfg /EFI/BOOT/grub.cfg *> `$null"
    )
    foreach ($cmd in $commitCmds) {
        if (-not (Safe-ExternalCommand $cmd)) { throw "ISO update failed." }
    }
    Write-Log "ISO customization completed successfully." 'Info'
    Read-Host -Prompt "Press Enter to exit"
    #endregion

} catch {
    Write-Log "Process failed: $($_.Exception.Message)" 'Error'
    exit 1
}

#endregion

