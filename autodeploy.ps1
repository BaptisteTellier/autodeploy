#Requires -Version 7.0
<#
.SYNOPSIS
Veeam Appliance ISO Automation Tool

.LICENSE
MIT License - see LICENSE file for details

.AUTHOR
Baptiste TELLIER

.COPYRIGHT
Copyright (c) 2025 Baptiste TELLIER

.VERSION 2.7

.DESCRIPTION
This PowerShell script provides automation for customizing Veeam Appliance ISO files to enable fully automated, unattended installations.
Now supports two appliance types: VSA (Veeam Software Appliance) and VIA (Veeam Infrastructure Appliance).

The script is designed to run in the same directory as the source ISO file and creates customized copies without complex path handling.

Enhanced Features:
- APPLIANCE TYPE SELECTION: Support for VSA, VIA, VIAVMware, and VIAHR appliances with dedicated deployment workflows
- JSON CONFIGURATION SUPPORT: Load all parameters from JSON configuration files for easy deployment management
- OUT-OF-PLACE ISO MODIFICATION: Creates customized copies without modifying the original ISO
- PATH HANDLING: Works ONLY in the current directory to avoid WSL path issues
- Network Configuration: Supports both DHCP and static IP configurations with comprehensive validation
- Regional Settings: Configures keyboard layouts and timezone settings with proper validation
- Veeam Configuration Management: Implements Veeam auto deploy 
- Component Integration: Optional deployment of node_exporter monitoring and Veeam license automation
- Service Provider Integration: Automated VCSP connection and management agent installation - v13.0.1 required
- Enterprise Logging: Comprehensive logging system with timestamped Info/Warn/Error levels + output log file in current folder

The script utilizes WSL (Windows Subsystem for Linux) with xorriso for ISO manipulation.

official Veeam documentation: https://helpcenter.veeam.com/docs/vbr/userguide/deployment_linux_silent_deploy_configure.html?ver=13

.PARAMETER ApplianceType
Specifies the type of Veeam appliance to customize. Valid values: "VSA", "VIA", "VIAVMware", "VIAHR"
- VSA: Veeam Software appliance (default behavior)
- VIA: Veeam Infrastructure Appliance (JeOS - Proxy)
- VIAVMware: Veeam Infrastructure Appliance (with iSCSI & NVMe/TCP)
- VIAHR: Veeam Hardened Repository (JeOS - Hardened Repository)
Default: "VSA"

.PARAMETER ConfigFile
Path to JSON configuration file. **MANDATORY** -- this is the ONLY CLI parameter accepted.
All other settings (ApplianceType, network, Veeam credentials, optional features, ...) MUST be defined in the JSON file.
Built-in defaults are applied first; any key present in the JSON overrides the corresponding default.
Example: "production-config.json"

.PARAMETER SourceISO
Specifies the filename of the source Veeam Software Appliance ISO file in the current directory.
Default: "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso"

.PARAMETER OutputISO
Specifies the filename for the customized ISO output in the current directory. 
If empty, creates a file with "_customized" suffix.
Example: "veeam-prod.iso"

.PARAMETER InPlace
Switch parameter to modify the original ISO file directly instead of creating a new one.
When $false (default), creates a new customized ISO preserving the original.
Default: $false

.PARAMETER CreateBackup
Switch parameter to create a timestamped backup when using InPlace modification.
Only effective when InPlace is $true. Default: $true

.PARAMETER CleanupCFGFiles
Switch parameter to keep grub.cfg and vbr-ks.cfg for debug
Default: $true

.PARAMETER CFGOnly
Switch parameter to only create grub.cfg and vbr-ks.cfg for debug
Default: $false

.PARAMETER GrubTimeout
Sets the GRUB bootloader timeout value in seconds. Default: 10

.PARAMETER KeyboardLayout
Keyboard layout code (e.g., 'us', 'fr', 'de', 'uk'). Default: "fr"

.PARAMETER Timezone
System timezone (e.g., 'Europe/Paris', 'America/New_York'). Default: "Europe/Paris"

.PARAMETER Hostname
Hostname for the deployed Veeam appliance. Default: "veeam-server"

.PARAMETER UseDHCP
Switch parameter to configure network interface for DHCP. When set, static IP parameters are ignored.
Default: $false

.PARAMETER StaticIP
IP address for static network configuration. Required when UseDHCP is $false.
Must be a valid IPv4 address format. Example: "192.168.1.100"

.PARAMETER Subnet
Subnet mask for static network configuration. Required when UseDHCP is $false.
Must be a valid IPv4 subnet mask format. Example: "255.255.255.0"

.PARAMETER Gateway
Gateway IP address for static network configuration. Required when UseDHCP is $false.
Must be a valid IPv4 address format. Example: "192.168.1.1"

.PARAMETER DNSServers
Array of DNS server IP addresses for static network configuration.
Default: @("192.168.1.64", "8.8.4.4")

.PARAMETER EnableIPv6
Enable IPv6 on the deployed appliance's network interface.
When set to $false, the kickstart `network` line gets `--noipv6` appended,
disabling IPv6 at install time on the appliance.
JSON note: must be a real boolean (`true` / `false`), not a string.
Default: $true

##### Veeam Security Configuration #####

.PARAMETER VeeamAdminPassword
Password for the Veeam Backup & Replication administrator account.
Must meet enterprise security complexity requirements: minimum 15 characters with uppercase, lowercase, numbers, and special characters.
This account provides full administrative access to the Veeam console and all backup operations.
Default: "123q123Q123!123"

.PARAMETER VeeamAdminMfaSecretKey
Base32-encoded secret key for multi-factor authentication (MFA) for the admin account.
Used for TOTP (Time-based One-Time Password) authentication with apps like Google Authenticator or Microsoft Authenticator.
Must be a valid Base32 string (A-Z, 2-7, no padding) between 16-32 characters.
Default: "JBSWY3DPEHPK3PXP"

.PARAMETER VeeamAdminIsMfaEnabled
Enable or disable multi-factor authentication for the administrator account.
Recommended setting is "true" for enhanced security in production environments.
When enabled, users must provide both password and TOTP code for console access.
Default: "true"

.PARAMETER VeeamSoPassword
Password for the Veeam Security Officer (SO) account.
The SO account provides service-level access separate from administrative functions for improved security separation.
Must meet the same complexity requirements as the admin password.
Default: "123w123W123!123"

.PARAMETER VeeamSoMfaSecretKey
Base32-encoded MFA secret key for the Security Officer account.
Follows the same format requirements as the admin MFA key.
Should be different from the admin account's MFA key for security isolation.
Used for TOTP authentication when SO account access is required.
Default: "JBSWY3DPEHPK3PXP"

.PARAMETER VeeamSoIsMfaEnabled
Enable or disable multi-factor authentication for the Security Officer account.
Recommended setting is "true" for production environments to secure service-level access.
When enabled, automated systems must provide TOTP codes for SO account operations.
Default: "true"

.PARAMETER VeeamSoRecoveryToken
GUID-format recovery token for Security Officer account emergency access.
Used for account recovery scenarios when MFA devices are unavailable or lost.
Must follow standard GUID format: 8-4-4-4-12 hexadecimal digits (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).
Store this token securely in your organization's password management system.
Default: "eb9fcbf4-2be6-e94d-4203-dded67c5a450"

.PARAMETER VeeamSoIsEnabled
Enable or disable the Security Officer account entirely.
When set to "true", creates and configures the SO account with specified security settings.
When set to "false", only the administrator account is configured.
Recommended setting is "true" for enterprise deployments requiring role separation.
Default: "true"

.PARAMETER NtpServer
Network Time Protocol (NTP) server(s) for system time synchronization.
Accepts EITHER a single string OR an array of strings (FQDN or IP address).
- Single server (string form, backward-compatible): "time.nist.gov"
- Multiple servers (array form):                  ["ntp1.example.local", "ntp2.example.local"]
When multiple servers are provided, they are rendered as `ntp.servers=ntp1;ntp2;...` (semicolon-separated)
in /etc/veeam/vbr_init.cfg, matching the Veeam host manager format.
Proper time synchronization is critical for Veeam operations, backup scheduling, and certificate validation.
Recommended to use your organization's internal NTP servers or reliable public pools.
Default: @("time.nist.gov")

.PARAMETER NodeExporter
Boolean flag to enable node_exporter deployment. 
Default: $false

.PARAMETER LicenseVBRTune
Boolean flag to enable automatic Veeam license installation. Default: $false

.PARAMETER SyslogServer
Syslog server IP address.
Default: ""

.PARAMETER VCSPConnection
Boolean flag to enable VCSP connection. 
Default: $false

.PARAMETER RestoreConfig
Boolean flag to enable restoration of the configuration from backup.
Default: $false

.PARAMETER ConfigPasswordSo
Security Officer Configuration Password for decrypting the configuration backup during restore.

.PARAMETER Debug
Enable debug mode for SSH access during installation. When enabled:
- Keeps SSH service enabled  
- Sets root password to plaintext (123q123Q123!123)
- Enables root SSH login
- Opens SSH port (22) in firewall temporarily
WARNING: Only use in test/development environments. Do not use in production.
Default: $false

.EXAMPLE
Run the script (JSON-only mode -- this is the only supported invocation):
.\autodeploy.ps1 -ConfigFile "production-config.json"

.NOTES
File Name      : autodeploy.ps1
Author         : Baptiste TELLIER
Prerequisite   : PowerShell 7+, WSL with xorriso installed
Version        : 2.7
Creation Date  : 24/09/2025
Last Modified  : 26/11/2025

REQUIREMENTS:
- Windows Subsystem for Linux (WSL) with xorriso package installed
- Source ISO file must be in the same directory as this script
- Optional: JSON configuration file for simplified parameter management
- Optional: 'license' folder with .lic files for license automation
- Optional: 'node_exporter' folder with binaries for monitoring deployment
- Optional: 'conf' folder for unattended configuration restore

USAGE:
- Place this script in the same directory as your ISO file
- Create a JSON configuration file with your desired settings (ApplianceType included)
- Run the script with -ConfigFile (the ONLY accepted CLI parameter)
- All operations happen in the current directory

JSON CONFIGURATION:
The script is JSON-only. All parameters MUST come from the JSON config file (CLI overrides are no longer supported).
Built-in defaults apply for any key omitted from the JSON. See example JSON file for the full schema.

OUTPUT:
- Customized ISO
- grub.cfg (optional)
- vbr-ks.cfg (optional)
- ISO_Customization.log

#>

#region Parameters
# JSON-ONLY MODE: all settings are loaded from the JSON config file.
# The only CLI parameter accepted is -ConfigFile (path to the JSON).
# Defaults are applied first by Set-DefaultParameter, then overridden by JSON.
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the JSON configuration file containing all script settings.")]
    [string]$ConfigFile
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

#region JSON Configuration Functions

function Import-JSONConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFilePath
    )
    
    try {
        if (-not (Test-Path $ConfigFilePath)) {
            throw "Configuration file not found: $ConfigFilePath"
        }
        
        Write-Log "Loading configuration from: $ConfigFilePath" 'Info'
        $jsonContent = Get-Content $ConfigFilePath -Raw -ErrorAction Stop
        $config = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        Write-Log "JSON configuration loaded successfully" 'Info'
        return $config
    }
    catch {
        Write-Log "Failed to load JSON configuration: $($_.Exception.Message)" 'Error'
        throw "JSON configuration error: $($_.Exception.Message)"
    }
}

# WHY: list of all settings the script reads from script-scope.
# Single source of truth -- used both by Set-DefaultParameter (defaults) and Update-ParametersFromJSON (overrides).
$script:KnownParameters = @(
    'ApplianceType', 'SourceISO', 'OutputISO', 'InPlace', 'CreateBackup',
    'CleanupCFGFiles', 'CFGOnly', 'GrubTimeout', 'KeyboardLayout', 'Timezone',
    'Hostname', 'UseDHCP', 'StaticIP', 'Subnet', 'Gateway', 'DNSServers', 'EnableIPv6',
    'VeeamAdminPassword', 'VeeamAdminMfaSecretKey', 'VeeamAdminIsMfaEnabled',
    'VeeamSoPassword', 'VeeamSoMfaSecretKey', 'VeeamSoIsMfaEnabled',
    'VeeamSoRecoveryToken', 'VeeamSoIsEnabled', 'NtpServer', 'NtpRunSync',
    'NodeExporter', 'LicenseVBRTune', 'LicenseFile', 'SyslogServer',
    'VCSPConnection', 'VCSPUrl', 'VCSPLogin', 'VCSPPassword',
    'RestoreConfig', 'ConfigPasswordSo', 'Debug'
)

function Set-DefaultParameter {
    # JSON-ONLY MODE: defaults are applied first, then JSON values override per-key.
    # Any key omitted from the JSON keeps its default value below.
    $defaults = [ordered]@{
        ApplianceType            = "VSA"
        SourceISO                = "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso"
        OutputISO                = ""
        InPlace                  = $false
        CreateBackup             = $true
        CleanupCFGFiles          = $true
        CFGOnly                  = $false
        GrubTimeout              = 10
        KeyboardLayout           = "fr"
        Timezone                 = "Europe/Paris"
        Hostname                 = "veeam-server"
        UseDHCP                  = $false
        StaticIP                 = "192.168.1.166"
        Subnet                   = "255.255.255.0"
        Gateway                  = "192.168.1.1"
        DNSServers               = @("192.168.1.64", "8.8.4.4")
        EnableIPv6               = $true
        VeeamAdminPassword       = "123q123Q123!123"
        VeeamAdminMfaSecretKey   = "JBSWY3DPEHPK3PXP"
        VeeamAdminIsMfaEnabled   = "true"
        VeeamSoPassword          = "123w123W123!123"
        VeeamSoMfaSecretKey      = "JBSWY3DPEHPK3PXP"
        VeeamSoIsMfaEnabled      = "true"
        VeeamSoRecoveryToken     = "eb9fcbf4-2be6-e94d-4203-dded67c5a450"
        VeeamSoIsEnabled         = "true"
        NtpServer                = @("time.nist.gov")
        NtpRunSync               = "true"
        NodeExporter             = $false
        LicenseVBRTune           = $false
        LicenseFile              = "Veeam-100instances-entplus-monitoring-nfr.lic"
        SyslogServer             = ""
        VCSPConnection           = $false
        VCSPUrl                  = ""
        VCSPLogin                = ""
        VCSPPassword             = ""
        RestoreConfig            = $false
        ConfigPasswordSo         = ""
        Debug                    = $false
    }
    foreach ($name in $defaults.Keys) {
        Set-Variable -Name $name -Value $defaults[$name] -Scope Script
    }
    Write-Log "Default parameters initialized ($($defaults.Count) keys)" 'Info'
}

function Update-ParametersFromJSON {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    Write-Log "Applying JSON configuration..." 'Info'

    # JSON is the single source of truth. Any key present in the JSON overrides the default.
    $parametersUpdated = 0
    foreach ($name in $script:KnownParameters) {
        if ($Config.PSObject.Properties[$name]) {
            Set-Variable -Name $name -Value $Config.$name -Scope Script
            $parametersUpdated++
        }
    }

    # Warn about unknown keys in the JSON (typos, deprecated settings, ...).
    $unknown = $Config.PSObject.Properties.Name | Where-Object { $_ -notin $script:KnownParameters }
    if ($unknown) {
        Write-Log "JSON contains unknown keys (ignored): $($unknown -join ', ')" 'Warn'
    }

    # Backward-compat: NtpServer accepts either a string ("a") or an array (["a","b","c"]).
    # Normalize to array form so Get-VeeamHostConfigBlock can always use $NtpServer -join ';'.
    if ($script:NtpServer -isnot [array]) { $script:NtpServer = @($script:NtpServer) }

    Write-Log "Applied $parametersUpdated parameters from JSON configuration" 'Info'
}

#endregion

#region Helper Functions

function Test-Prerequisites {
    Write-Log "Testing prerequisites..." 'Info'

    try {
        $wslTest = & wsl echo "test" 2>$null
        if ($wslTest -ne "test") {
            throw "WSL is not available or not responding correctly"
        }
        Write-Log "WSL is available" 'Info'
    }
    catch {
        Write-Log "WSL test failed: $($_.Exception.Message)" 'Error'
        return $false
    }

    try {
        $xorrisoTest = & wsl which xorriso 2>$null
        if ([string]::IsNullOrWhiteSpace($xorrisoTest)) {
            throw "xorriso not found. Install with: wsl sudo apt-get install xorriso"
        }
        Write-Log "xorriso is available at: $xorrisoTest" 'Info'
    }
    catch {
        Write-Log "xorriso test failed: $($_.Exception.Message)" 'Error'
        Write-Log "Please install xorriso: wsl sudo apt-get update && wsl sudo apt-get install xorriso" 'Error'
        return $false
    }

    if (-not (Test-Path $SourceISO)) {
        Write-Log "Source ISO not found in current directory: $SourceISO" 'Error'
        Write-Log "Please ensure the ISO file is in the same directory as this script" 'Error'
        return $false
    }

    Write-Log "All prerequisites validated successfully" 'Info'
    return $true
}

function Initialize-ISOOperation {
    $currentDir = Get-Location
    Write-Log "Working in directory: $currentDir" 'Info'

    if ($InPlace) {
        $targetISO = $SourceISO
        Write-Log "In-place modification mode: will modify $SourceISO directly" 'Info'

        if ($CreateBackup) {
            $sourceBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceISO)
            $sourceExtension = [System.IO.Path]::GetExtension($SourceISO)
            $backupName = "$sourceBaseName`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')$sourceExtension"

            Write-Log "Creating backup: $backupName" 'Info'
            Copy-Item $SourceISO $backupName -Force
            Write-Log "Backup created successfully" 'Info'
            $backupPath = $backupName
        } else {
            $backupPath = $null
        }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($OutputISO)) {
            $sourceBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceISO)
            $sourceExtension = [System.IO.Path]::GetExtension($SourceISO)
            $targetISO = "$sourceBaseName`_customized$sourceExtension"
        } else {
            $targetISO = $OutputISO
        }

        Write-Log "Out-of-place modification mode: creating $targetISO" 'Info'
        Copy-Item $SourceISO $targetISO -Force
        Write-Log "Working copy created: $targetISO" 'Info'
        $backupPath = $null
    }

    return @{
        SourceISO = $SourceISO
        TargetISO = $targetISO
        BackupPath = $backupPath
        IsInPlace = [bool]$InPlace
        Mode = if ($CFGOnly) {"CFG ONLY"} elseif ($InPlace) { "In-Place" } else { "Out-of-Place" }
        RestoreConfig = $RestoreConfig
        Debug = $Debug
    }
}

function Invoke-WSLCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(Mandatory = $false)]
        [string]$Description = "WSL Command"
    )

    try {
        Write-Log "Executing: $Description" 'Info'
        Write-Log "Command: $Command" 'Info'

        $output = & cmd /c $Command 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Log "Command failed with exit code $exitCode" 'Warn'
            if ($output) {
                Write-Log "Output: $output" 'Warn'
            }
        } else {
            Write-Log "$Description completed successfully" 'Info'
        }

        return ($exitCode -eq 0)
    }
    catch {
        Write-Log "$Description failed: $($_.Exception.Message)" 'Error'
        return $false
    }
}

function Get-ModificationSummary {
    param([hashtable]$ISOInfo)

    $summary = @()
    $summary += "=================================================================================================="
    $summary += "                                    ISO MODIFICATION SUMMARY"
    $summary += "=================================================================================================="
    $summary += "Appliance Type: $ApplianceType"
    $summary += "Source ISO: $($ISOInfo.SourceISO)"
    $summary += "Target ISO: $($ISOInfo.TargetISO)"
    $summary += "Mode: $($ISOInfo.Mode)"

    if ($ISOInfo.BackupPath) {
        $summary += "Backup: $($ISOInfo.BackupPath)"
    }

    $summary += ""
    $summary += "CONFIGURATION:"
    $summary += "  GRUB Timeout: $GrubTimeout seconds"
    $summary += "  Keyboard: $KeyboardLayout"
    $summary += "  Timezone: $Timezone"
    $summary += "  Hostname: $Hostname"

    if ($UseDHCP) {
        $summary += "  Network: DHCP"
    } else {
        $summary += "  Network: Static IP ($StaticIP/$Subnet via $Gateway)"
        $summary += "  DNS: $($DNSServers -join ', ')"
    }
    if (-not $EnableIPv6) {
        $summary += "  IPv6: Disabled (--noipv6)"
    }

    $summary += ""
    $summary += "OPTIONAL FEATURES:"
    $summary += "  Node Exporter: $(if ($NodeExporter) { 'Enabled' } else { 'Disabled' })"
    $summary += "  Debug: $(if ($ISOInfo.Debug) { 'Enabled' } else { 'Disabled' })"
    if($ApplianceType -eq "VSA"){
    $summary += "  License Auto-Install: $(if ($LicenseVBRTune) { 'Enabled' } else { 'Disabled' })"
    $summary += "  VCSP Connection: $(if ($VCSPConnection) { 'Enabled' } else { 'Disabled' })"
    $summary += "  Restore Config: $(if ($ISOInfo.RestoreConfig) { 'Enabled' } else { 'Disabled' })"
    }
    $summary += "=================================================================================================="

    return $summary -join "`n"
}

function Show-SuccessSummary {
    # Unified success banner -- called once from the main entry after the workflow switch.
    # Replaces the 4 duplicated blocks that lived at the end of each Invoke-* function.
    param([Parameter(Mandatory)][hashtable]$ISOInfo)

    Write-Host "`n==================================================================================================" -ForegroundColor Green
    Write-Host "                                        SUCCESS!" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green
    Write-Host "Customized ISO: $($ISOInfo.TargetISO)" -ForegroundColor Green
    if ($ISOInfo.BackupPath) {
        Write-Host "Backup created: $($ISOInfo.BackupPath)" -ForegroundColor Green
    }
    Write-Host "Appliance Type: $ApplianceType" -ForegroundColor Green
    Write-Host "Mode: $($ISOInfo.Mode)" -ForegroundColor Green
    if ($ISOInfo.RestoreConfig) {
        Write-Host "Backup Configuration Restore : $($ISOInfo.RestoreConfig)" -ForegroundColor DarkYellow
    }
    Write-Host "Debug mode : $($ISOInfo.Debug)" -ForegroundColor DarkYellow
    Write-Host "==================================================================================================" -ForegroundColor Green
}

function Remove-TempCfgFile {
    # Unified cleanup of kickstart + grub.cfg working copies.
    # Used both by the success path (main entry) and the catch block (error path).
    # Relies on $script:ActiveCfgFile set at the top of each Invoke-* workflow.
    if (-not $CleanupCFGFiles) { return }
    @($script:ActiveCfgFile, "grub.cfg") | Where-Object { $_ } | ForEach-Object {
        if (Test-Path $_ -ErrorAction SilentlyContinue) {
            Remove-Item $_ -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-FileContent {
    param(
        [string]$FilePath,
        [string]$Pattern,
        [string]$Replacement
    )

    try {
        $content = Get-Content $FilePath 
        $content = $content -replace $Pattern, $Replacement
        Set-Content $FilePath $content 
        Write-Log "Updated with $Replacement in $FilePath" 'Info'
    }
    catch {
        Write-Log "Failed to update $FilePath`: $($_.Exception.Message)" 'Error'
        throw
    }
}

function Add-ContentAfterLine {
    param(
        [string]$FilePath,
        [string]$TargetLine,
        [string[]]$NewLines
    )

    try {
        $content = Get-Content $FilePath
        $newContent = [System.Collections.Generic.List[string]]::new($content.Count + $NewLines.Count)

        foreach ($line in $content) {
            $newContent.Add($line)
            if ($line -like "*$TargetLine*") {
                $newContent.AddRange([string[]]$NewLines)
                Write-Log "Added content after line: $TargetLine" 'Info'
            }
        }

        Set-Content -Path $FilePath -Value $newContent.ToArray()
    }
    catch {
        Write-Log "Failed to add content to $FilePath`: $($_.Exception.Message)" 'Error'
        throw
    }
}

function ConvertTo-LFLineEnding {
    param([Parameter(Mandatory)][string[]]$Files)

    Write-Log "Normalizing line endings..." 'Info'
    foreach ($file in $Files) {
        $content = Get-Content $file -Raw
        $content = $content.Replace("`r`n", "`n")
        Set-Content $file $content -NoNewline
    }
}

function Invoke-ISOExtractConfig {
    param(
        [Parameter(Mandatory)][string]$TargetISO,
        [Parameter(Mandatory)][string]$KickstartName
    )

    $extractCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$TargetISO`" -osirrox on -extract $KickstartName $KickstartName",
        "wsl xorriso -boot_image any keep -dev `"$TargetISO`" -osirrox on -extract /EFI/BOOT/grub.cfg grub.cfg"
    )

    foreach ($cmd in $extractCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Extract configuration files")) {
            throw "Failed to extract files from ISO"
        }
    }

    @($KickstartName, "grub.cfg") | ForEach-Object {
        if (-not (Test-Path $_)) {
            throw "Required file not extracted: $_"
        }
        Write-Log "File extracted: $_" 'Info'
    }
}

function Invoke-ISOCommit {
    param(
        [Parameter(Mandatory)][string]$TargetISO,
        [Parameter(Mandatory)][string]$KickstartName
    )

    Write-Log "Committing changes to ISO..." 'Info'

    $commitCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$TargetISO`" -rm $KickstartName",
        "wsl xorriso -boot_image any keep -dev `"$TargetISO`" -map $KickstartName $KickstartName",
        "wsl xorriso -boot_image any keep -dev `"$TargetISO`" -rm /EFI/BOOT/grub.cfg",
        "wsl xorriso -boot_image any keep -dev `"$TargetISO`" -map grub.cfg /EFI/BOOT/grub.cfg"
    )

    foreach ($cmd in $commitCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Commit changes to ISO")) {
            throw "Failed to commit changes to ISO"
        }
    }

    Write-Log "ISO customization completed successfully!" 'Info'
}

function Set-GrubDefaultAndTimeout {
    param(
        [Parameter(Mandatory)][string]$DefaultLabel,
        [Parameter(Mandatory)][int]$Timeout
    )

    Update-FileContent -FilePath "grub.cfg" -Pattern 'set default=.*' -Replacement "set default=$DefaultLabel"
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set timeout=.*' -Replacement "set timeout=$Timeout"
}

function Add-FolderToISO {
    param(
        [Parameter(Mandatory)][string]$TargetISO,
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$ISOPath
    )

    if (-not (Test-Path $LocalPath)) { return }
    $cmd = "wsl xorriso -boot_image any keep -dev `"$TargetISO`" -map $LocalPath $ISOPath"
    Invoke-WSLCommand -Command $cmd -Description "Add $LocalPath folder to ISO" | Out-Null
}

#endregion

#region Configuration Functions

function Set-KeyboardLayout {
    param([string]$FilePath, [string]$Layout)

    Write-Log "Setting keyboard layout to $Layout" 'Info'
    Update-FileContent -FilePath $FilePath -Pattern "keyboard --xlayouts='[^']*'" -Replacement "keyboard --xlayouts='$Layout'"
}

function Set-Timezone {
    param([string]$FilePath, [string]$TimezoneValue)

    Write-Log "Setting timezone to $TimezoneValue" 'Info'
    Update-FileContent -FilePath $FilePath -Pattern "timezone [^\s]+ --utc" -Replacement "timezone $TimezoneValue --utc"
}

function Set-NetworkConfiguration {
    param(
        [string]$FilePath,
        [string]$Hostname,
        [switch]$UseDHCP,
        [string]$StaticIP,
        [string]$Subnet,
        [string]$Gateway,
        [string[]]$DNSServers,
        [bool]$EnableIPv6 = $true
    )

    Write-Log "Configuring network settings" 'Info'

    if ($UseDHCP) {
        $networkLine = "network --bootproto=dhcp --nodns --hostname=$Hostname"
        Write-Log "Using DHCP configuration" 'Info'
    } else {
        $DNSList = $DNSServers -join ","
        $networkLine = "network --bootproto=static --ip=$StaticIP --netmask=$Subnet --gateway=$Gateway --nameserver=$DNSList --hostname=$Hostname"
        Write-Log "Using static IP configuration: $StaticIP" 'Info'
    }

    if (-not $EnableIPv6) {
        $networkLine += " --noipv6"
        Write-Log "IPv6 disabled (--noipv6 appended)" 'Info'
    }
    
    $content = Get-Content $FilePath
    $found = $false

    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i] -match '^network\s') {
            $content[$i] = $networkLine
            $found = $true
            break
        }
    }

    if (-not $found) {
        for ($i = 0; $i -lt $content.Count; $i++) {
            if ($content[$i] -match '^timezone\s+') {
                $newContent = $content[0..$i] + $networkLine + $content[($i+1)..($content.Count-1)]
                $content = $newContent
                break
            }
        }
    }
    
    Set-Content $FilePath $content 
    Write-Log "Network configuration applied" 'Info'
}

function Set-DebugSSHModifications {
    param([string]$FilePath)

    if (-not $Debug) {
        return
    }

    Write-Log "Applying DEBUG mode SSH modifications..." 'Warn'

    # Single-pass refactor: 1 read + in-memory regex replaces + 1 line-pass + 1 write
    # (was 6 reads + 6 writes across separate blocks)
    $raw = [System.IO.File]::ReadAllText($FilePath)

    $raw = $raw -replace 'rootpw --iscrypted --lock \*', 'rootpw --allow-ssh --plaintext 123q123Q123!123'
    Write-Log "Changed root password to plaintext" 'Info'

    $raw = $raw -replace 'user --name root --shell /sbin/nologin.*', 'user --name root --shell /bin/bash'
    Write-Log "Removed root user nologin configuration" 'Info'

    $sshRootBlock = "`$1`n`nlog 'Temporary enable ssh root access in testing purposes'`ncat > /etc/ssh/sshd_config.d/00-complianceascode-hardening.conf << EOF`nAllowGroups veeam-grp-admin root`nPermitRootLogin yes`nEOF`nsystemctl restart sshd"
    $raw = $raw -replace 'echo "AllowGroups veeam-grp-admin".*', $sshRootBlock
    Write-Log "Added SSH root access configuration" 'Info'

    $sourceLines = $raw -split "`r?`n"
    $lines = [System.Collections.Generic.List[string]]::new($sourceLines.Count + 16)
    $foundVHM = $false
    foreach ($line in $sourceLines) {
        if ($line -like "*systemctl disable sshd.service*") { continue }

        if ($line -like "*log 'Install static packages'*" -or $line -like '*log "Install static packages"*') {
            $lines.Add("log 'Temporary allow 22 port in kickstart in debug purposes'")
            $lines.Add("cp /usr/lib/firewalld/zones/drop.xml /etc/firewalld/zones/drop.xml")
            $lines.Add('sed -i "/<forward\/>/i \  <service name=\"ssh\"/>" /etc/firewalld/zones/drop.xml')
        }

        $lines.Add($line)

        if (-not $foundVHM -and $line -like '*systemctl enable veeamhostmanager.service*') {
            $lines.Add('chage -d $(date +%Y-%m-%d) root')
            $lines.Add('chage -d $(date +%Y-%m-%d) veeamadmin')
            $lines.Add('chage -d $(date +%Y-%m-%d) veeamso')
            $lines.Add('chage -d $(date +%Y-%m-%d) veeamtui')
            $lines.Add('usermod -s /bin/bash root')
            $foundVHM = $true
        }
    }
    Write-Log "Removed systemctl disable sshd.service lines" 'Info'
    Write-Log "Added SSH firewall rule before static packages" 'Info'
    Write-Log "reset password expiration for users" 'Info'

    Set-Content -Path $FilePath -Value $lines.ToArray()

    Write-Log "DEBUG mode SSH modifications completed" 'Warn'
}

#endregion

#region Dynamic Configuration Block Functions

function Get-CustomVBRBlock {
    $block = @(
        "echo 'Applying license file...'",
        "pwsh -Command '",
        "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
        "Install-VBRLicense -Path /etc/veeam/license/$LicenseFile"
    )
    
    if ($SyslogServer) {
        $block += "Set-VBRServerSyslog -SyslogServer '$SyslogServer' -SyslogPort 514 -Protocol UDP"
    }
    $block += "'"
    $block += "echo 'License file applied successfully'"
   
    return $block
}

function Get-CustomVCSPBlock3 {
$bashScript = 
@"
#==============================================================================
# enable external managers installation
#==============================================================================
echo 'enabling external managers installation...'
touch /etc/veeam/allow_external_managers_installation
echo 'external managers installation enabled'
sleep 2

#==============================================================================
# Add to Service Provider
#==============================================================================
echo 'Adding to Service Provider with Mgmt Agent'

ATTEMPT=1
SUCCESS=0
while [ `$ATTEMPT -le 3 ]; do
    echo "[Attempt `$ATTEMPT/3] Running Powershell to add cloud provider"
    if pwsh -Command '
        Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1
        `$credentials = Get-VBRCloudProviderCredentials -Name "$VCSPLogin"
        if (-not `$credentials) {
            write-Host "Credentials not found, adding new credentials"
            Add-VBRCloudProviderCredentials -Name "$VCSPLogin" -Password "$VCSPPassword"
            `$credentials = Get-VBRCloudProviderCredentials -Name "$VCSPLogin"
        }
        else {
            write-Host "Credentials found"
        }
        write-Host "adding cloud provider..."
        Add-VBRCloudProvider -Address "$VCSPUrl" -Credentials `$credentials -InstallManagementAgent -Force
        write-Host "Cloud provider added successfully"
        '; then
        echo "[SUCCESS] Powershell add provider worked on attempt number `$ATTEMPT"
        SUCCESS=1
        break
    else
        echo "[FAILED] adding cloud provider `$ATTEMPT"
        if [ `$ATTEMPT -lt 3 ]; then
            echo "Waiting 15 seconds before retry..."
            sleep 15
        fi
    fi
    ATTEMPT=`$((ATTEMPT + 1))
done

if [ `$SUCCESS -eq 0 ]; then
    echo '[ERROR] Failed to add service provider after 3 attempts'
    exit 1
fi

echo 'OK : Added to Service Provider successfully'
sleep 2
echo 'disable allow_external_managers_installation flag'
rm -f /etc/veeam/allow_external_managers_installation
echo 'flag disabled successfully'
"@
    return $bashScript -replace "`r`n", "`n"
}

function Get-CopyLicenseBlock {
    return @(
        "# Copy Veeam license file from ISO to OS",
        "log 'starting license file copy'",
        "mkdir -p /mnt/sysimage/etc/veeam/license/",
        "if [ -f /mnt/install/repo/license/$LicenseFile ]; then",
        "  cp -f /mnt/install/repo/license/$LicenseFile /mnt/sysimage/etc/veeam/license/$LicenseFile",
        "  chmod 600 /mnt/sysimage/etc/veeam/license/$LicenseFile",
        "  chown root:root /mnt/sysimage/etc/veeam/license/$LicenseFile",
        "fi",
        "log 'license file copy completed'"
    )
}

function Get-NodeExporterFirewallBlock {
    return @(
        "echo 'Configure firewall for node_exporter'",
        "firewall-cmd --permanent --zone=drop --add-port=9100/tcp",
        "firewall-cmd --reload"
        "echo 'Firewall configured for node_exporter 9100/tcp'"
    )
}

function Get-VeeamHostConfigBlock {
    return @(
        "log 'starting Veeam Host Manager configuration'",
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
        "ntp.servers=$($NtpServer -join ';')",
        "ntp.runSync=$NtpRunSync",
        "vbr_control.runInitIso=true",
        "vbr_control.runStart=true",
        "EOF",
        "###############################################################################",
        "#  Automatic Host Manager configuration TRIGGER AFTER REBOOT",
        "###############################################################################",
        "log 'starting /etc/veeam/veeam-init.sh'",
        "cat << 'EOF' >> /etc/veeam/veeam-init.sh",
        "#!/bin/bash",
        "set -eE -u -o pipefail",
        "# Configuration logging",
        "exec > >(tee -a '/var/log/veeam_init.log') 2>&1",
        "echo 'Applying initial Veeam configuration...'",
        "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg",
        "echo 'Disabling veeam-init service...'",
        "systemctl disable veeam-init",
        "echo 'OK : Service disabled'",
        "echo 'removing offline repo /tmp/offline_repo if exists'",
        "rm /tmp/offline_repo -rf"
        "echo 'Restarting getty services...'",
        "systemctl restart getty@tty1.service",
        "systemctl restart getty@tty2.service",
        "systemctl restart getty@tty3.service",
        "systemctl restart getty@tty4.service",
        "systemctl restart getty@tty5.service",
        "echo 'OK : Getty services restarted'",
        "echo '==========================================='",
        "echo 'Veeam VSA Initialization Completed Successfully'",
        "echo '==========================================='",
        "echo 'All logs consolidated in: /var/log/veeam_init.log'",
        "echo '==========================================='",
        "EOF",
        "log 'end of /etc/veeam/veeam-init.sh'",
        "chmod +x /etc/veeam/veeam-init.sh",
        "log 'creation of /etc/systemd/system/veeam-init.service'",
        "# Create systemd service",
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
        "systemctl enable veeam-init.service",
        "log 'Veeam Host Manager configuration completed'",
        "log 'end of log /var/log/appliance-installation-logs/post-install.log'"
    )
}

function Get-OfflineRepoEnableLine {
    return @(
        "cat << EOF >> /etc/yum.repos.d/local-offline.repo",
        "[local-offline]",
        "name=Local Offline Repository for oathtool and curl",
        "enabled=1",
        "gpgcheck=0",
        "baseurl=file:///tmp/offline_repo",
        "EOF"
    )
}

function Get-NodeExporterOfflineBlock {
    return @(
        "# Install node_exporter from offline repo",
        "log '[1/4] Enabling offline repository...'"
    ) + (Get-OfflineRepoEnableLine) + @(
        "log '[2/4] Installing node_exporter from offline repo...'",
        "dnf clean all --releasever 9",
        "dnf --disablerepo='*' --enablerepo='local-offline' install -y node_exporter --releasever 9",
        "log 'node_exporter installation completed'",
        "log 'removing offline repository /etc/yum.repos.d/local-offline.repo'",
        "rm -f /etc/yum.repos.d/local-offline.repo",
        "dnf clean all",
        "dnf config-manager --set-enabled '*'",

        "log '[3/4] Configuring /etc/sysconfig/node_exporter ...'",
        'bash -c ''echo OPTIONS="--web.listen-address=0.0.0.0:9100" > /etc/sysconfig/node_exporter''',

        "log '[4/4] Enabling and starting node_exporter...'",
        "systemctl daemon-reload",
        "systemctl enable node_exporter.service",
        "log 'node_exporter installation completed'"
    )
}

function Get-InstalloathtoolOfflineBlock {
    return @(
        "log '[1/2] Enabling offline repository...'"
    ) + (Get-OfflineRepoEnableLine) + @(
        "log '[2/2] Installing oathtool and curl from RPMs...'",
        "dnf clean all --releasever 9",
        "dnf --disablerepo='*' --enablerepo='local-offline' install -y oathtool curl --releasever 9",
        "log 'oathtool and curl installation completed'",
        "log 'removing offline repository /etc/yum.repos.d/local-offline.repo'",
        "rm -f /etc/yum.repos.d/local-offline.repo",
        "dnf config-manager --set-enabled '*'"
    )
}

function Get-VeeamRestoreConfigBlock {
   
$commands = @(
    "sleep 10s"
)

if ($VeeamSoIsEnabled -eq $true) {
    $commands += @(
        "echo 'Configuring SO backup password'",
        "chmod +x '/etc/veeam/veeam_addsoconfpw.sh'",
        "/bin/bash /etc/veeam/veeam_addsoconfpw.sh '$ConfigPasswordSo' '$VeeamSoMfaSecretKey' '$VeeamSoPassword'",
        "echo 'OK : Configuration SO password set'",
        "sleep 10s"
    )
}

$commands += @(
    "echo 'Restoring configuration...'",
    '# Temporarily disable pipefail for retry logic',
    'set +e',
    'set +o pipefail', 
    '',
    "dotnet /opt/veeam/vbr/Veeam.Backup.Configuration.UnattendedRestore.dll /file:/var/lib/veeam/unattended.xml 2>&1 | tee -a /var/log/veeam_configrestore.log",
    'if [ ${PIPESTATUS[0]} -ne 0 ]; then',
    '    echo "First attempt failed, retrying in 60 seconds..."',
    '    sleep 60',
    '    dotnet /opt/veeam/vbr/Veeam.Backup.Configuration.UnattendedRestore.dll /file:/var/lib/veeam/unattended.xml 2>&1 | tee -a /var/log/veeam_configrestore.log',
    'fi'
    '',
    '# Re-enable strict mode',
    'set -e',
    'set -o pipefail',
    '',
    'if [ ${PIPESTATUS[0]} -eq 0 ]; then',
    "echo 'OK : Configuration restored'",
    "else",
    "echo 'ERROR : Configuration restore failed 2/2 attempts'",
    'exit 1',
    'fi',
    "echo 'Additional logs:'"
    )

if ($VeeamSoIsEnabled -eq $true) {
    $commands += @(  
    "echo '  - Password SO config: /var/log/veeam_addsoconfpw.log'"
    ) 
}
$commands += @(
    "echo '  - Config restore: /var/log/veeam_configrestore.log'"
)
if ($VeeamSoIsEnabled -eq $true) {
    $commands += @(  
    "echo 'Cleaning up oathtool and rm unattended.xml veeam_addsoconfpw.sh ...'",
    "dnf -y remove oathtool",
    "dnf clean all",
    "rm -f /etc/veeam/veeam_addsoconfpw.sh"
    )
}

$commands += @(
    "rm -f /var/lib/veeam/unattended.xml"
    )

return $commands
}

function Get-RestoreFileCopyBlock {
    return @(
        "# Copy Restore configuration file",
        "log 'starting restore configuration file copy'",
        "cp -f /mnt/install/repo/conf/conftoresto.bco /mnt/sysimage/var/lib/veeam/backup/conftoresto.bco",
        "chmod 600 /mnt/sysimage/var/lib/veeam/backup/conftoresto.bco",
        "chown root:root /mnt/sysimage/var/lib/veeam/backup/conftoresto.bco",
        "log 'restore configuration file copy completed'"
        
        "# Copy unattended.xml file",
        "log 'starting unattended.xml file copy'",
        "cp -f /mnt/install/repo/conf/unattended.xml /mnt/sysimage/var/lib/veeam/unattended.xml",
        "chmod 600 /mnt/sysimage/var/lib/veeam/unattended.xml",
        "chown root:root /mnt/sysimage/var/lib/veeam/unattended.xml",
        "log 'unattended.xml file copy completed'"

        "# Copy veeam_addsoconfpw.sh file",
        "log 'starting veeam_addsoconfpw.sh file copy'",
        "cp -f /mnt/install/repo/conf/veeam_addsoconfpw.sh /mnt/sysimage/etc/veeam/veeam_addsoconfpw.sh",
        "chmod 600 /mnt/sysimage/etc/veeam/veeam_addsoconfpw.sh",
        "chown root:root /mnt/sysimage/etc/veeam/veeam_addsoconfpw.sh",
        "log 'veeam_addsoconfpw.sh file copy completed'"
    )
}

function Get-OfflineRepoFileCopyBlock {
    return @(
        "# Copy Offline Repo files",
        "log 'starting offline repo copy'",
        "cp -fr /mnt/install/repo/offline_repo /mnt/sysimage/tmp/offline_repo",
        "log 'copy offline repo completed'"
    )
}

#endregion

#region VSA Region Function

function Invoke-VSA {
    Write-Log "=================================================================================================="
    Write-Log "                         VSA WORKFLOW - VEEAM SOFTWARE APPLIANCE"
    Write-Log "=================================================================================================="

    $script:ActiveCfgFile = "vbr-ks.cfg"

    Write-Log "Config only set to $CFGOnly" 'Info'
    if($CFGOnly){
        $script:CleanupCFGFiles=$false
        $script:InPlace=$true
        $script:CreateBackup=$false
    }

    if (-not (Test-Prerequisites)) {
        throw "Prerequisites check failed. Please resolve the issues above."
    }

    if (-not $UseDHCP) {
        if ([string]::IsNullOrWhiteSpace($StaticIP) -or 
            [string]::IsNullOrWhiteSpace($Subnet) -or 
            [string]::IsNullOrWhiteSpace($Gateway)) {
            throw "Static IP configuration requires StaticIP, Subnet, and Gateway parameters"
        }
    }

    $isoInfo = Initialize-ISOOperation
    
    Write-Host "`n$(Get-ModificationSummary -ISOInfo $isoInfo)" -ForegroundColor Yellow
    Write-Host "`nPress Enter to continue or Ctrl+C to abort..." -ForegroundColor Cyan
    $null = Read-Host  # discard return value -- otherwise it pollutes the function pipeline

    Write-Log "Extracting configuration files from ISO..." 'Info'

    Invoke-ISOExtractConfig -TargetISO $isoInfo.TargetISO -KickstartName "vbr-ks.cfg"

    #####
    #GRUB
    #####

    Write-Log "Configuring GRUB bootloader..." 'Info'
    Update-FileContent -FilePath "grub.cfg" -Pattern '^(.*inst.ks=hd:LABEL=VeeamSA:/vbr-ks.cfg quiet.*)$' -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Backup & Replication v13.0>Install - fresh install, wipes everything (including local backups)"'
    Set-GrubDefaultAndTimeout -DefaultLabel $newDefault -Timeout $GrubTimeout

    #####
    #KSICKSTART
    #####

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "vbr-ks.cfg" -Layout $KeyboardLayout
    Set-Timezone -FilePath "vbr-ks.cfg" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -UseDHCP:$true -EnableIPv6 $EnableIPv6
    } else {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers -EnableIPv6 $EnableIPv6
    }

    Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)
 
    #####
    #Optional Modifications 
    #####

    #####
    #SSh modifications for DEBUG mode
    #####

    if ($Debug) {
        Set-DebugSSHModifications -FilePath "vbr-ks.cfg"
    }
    
    #####
    #Restore Configuration
    #####
    
    if ($RestoreConfig) {
        Write-Log "Adding restore configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-RestoreFileCopyBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-OfflineRepoFileCopyBlock)

        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-VeeamRestoreConfigBlock)
        if ($VeeamSoIsEnabled -eq $true) {
            Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-InstalloathtoolOfflineBlock)
        }
        if (-not $CFGOnly) {
            Add-FolderToISO -TargetISO $isoInfo.TargetISO -LocalPath "conf" -ISOPath "/conf"
            Add-FolderToISO -TargetISO $isoInfo.TargetISO -LocalPath "offline_repo" -ISOPath "/offline_repo"
        }
    }

    #####
    #VCSP Configuration
    #####

    if ($VCSPConnection) {
        Write-Log "Adding VCSP configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-CustomVCSPBlock3)
    }

    #####
    #VBR License Configuration
    #####

    if ($LicenseVBRTune) {
        Write-Log "Adding license configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-CustomVBRBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-CopyLicenseBlock)
        if (-not $CFGOnly) {
            Add-FolderToISO -TargetISO $isoInfo.TargetISO -LocalPath "license" -ISOPath "/license"
        }
    }

    #####
    #Node Exporter Configuration
    #####

    if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-OfflineRepoFileCopyBlock)

        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)

        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm" -NewLines (Get-NodeExporterOfflineBlock)

        if (-not $CFGOnly) {
            Add-FolderToISO -TargetISO $isoInfo.TargetISO -LocalPath "offline_repo" -ISOPath "/offline_repo"
        }
    } 

    #####
    ##Normalize line endings & commit changes to ISO
    #####

    ConvertTo-LFLineEnding -Files @("vbr-ks.cfg", "grub.cfg")

    if(-not $CFGOnly){
        Invoke-ISOCommit -TargetISO $isoInfo.TargetISO -KickstartName "vbr-ks.cfg"
    }

    return $isoInfo
}

#endregion

#region VIA Region Function

function Invoke-VIA {
    Write-Log "=================================================================================================="
    Write-Log "                         VIA WORKFLOW - VEEAM INFRASTRUCTURE APPLIANCE"
    Write-Log "=================================================================================================="

    $CFGname = "proxy-ks.cfg"
    $script:ActiveCfgFile = $CFGname

    Write-Log "Config only set to $CFGOnly" 'Info'
    if($CFGOnly){
        $script:CleanupCFGFiles=$false
        $script:InPlace=$true
        $script:CreateBackup=$false
    }

    if (-not (Test-Prerequisites)) {
        throw "Prerequisites check failed. Please resolve the issues above."
    }

    if (-not $UseDHCP) {
        if ([string]::IsNullOrWhiteSpace($StaticIP) -or 
            [string]::IsNullOrWhiteSpace($Subnet) -or 
            [string]::IsNullOrWhiteSpace($Gateway)) {
            throw "Static IP configuration requires StaticIP, Subnet, and Gateway parameters"
        }
    }

    $isoInfo = Initialize-ISOOperation
    
    Write-Host "`n$(Get-ModificationSummary -ISOInfo $isoInfo)" -ForegroundColor Yellow
    Write-Host "`nPress Enter to continue or Ctrl+C to abort..." -ForegroundColor Cyan
    $null = Read-Host  # discard return value -- otherwise it pollutes the function pipeline

    Write-Log "Extracting configuration files from ISO..." 'Info'

    Invoke-ISOExtractConfig -TargetISO $isoInfo.TargetISO -KickstartName $CFGname

    Write-Log "Configuring GRUB bootloader..." 'Info'
    $pattern = "^(.*LABEL=VeeamJeOS:/$CFGname quiet.*)$"
    Update-FileContent -FilePath "grub.cfg" -Pattern $pattern -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Infrastructure Appliance>Install - fresh install, wipes everything (including local backups)"'
    Set-GrubDefaultAndTimeout -DefaultLabel $newDefault -Timeout $GrubTimeout

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "$CFGname" -Layout $KeyboardLayout
    Set-Timezone -FilePath "$CFGname" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -UseDHCP:$true -EnableIPv6 $EnableIPv6
    } else {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers -EnableIPv6 $EnableIPv6
    }

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)
    #####
    #Optional Modifications 
    #####

    #####
    #SSh modifications for DEBUG mode
    #####
    if ($Debug) {
        Set-DebugSSHModifications -FilePath "$CFGname"
    }

    #####
    #Node Exporter Configuration
    #####

    if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-OfflineRepoFileCopyBlock)
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-NodeExporterOfflineBlock)
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)
        if (-not $CFGOnly) {
            Add-FolderToISO -TargetISO $isoInfo.TargetISO -LocalPath "offline_repo" -ISOPath "/offline_repo"
        }
    } 

    ConvertTo-LFLineEnding -Files @($CFGname, "grub.cfg")

    if(-not $CFGOnly){
        Invoke-ISOCommit -TargetISO $isoInfo.TargetISO -KickstartName $CFGname
    }

    return $isoInfo
}

#endregion

#region VIAVMware Region Function

function Invoke-VIAVMware {
    Write-Log "=================================================================================================="
    Write-Log "                         VIA WORKFLOW - Veeam Infrastructure Appliance (with iSCSI & NVMe/TCP)"
    Write-Log "=================================================================================================="

    $CFGname = "vmware-proxy-ks.cfg"
    $script:ActiveCfgFile = $CFGname

    Write-Log "Config only set to $CFGOnly" 'Info'
    if($CFGOnly){
        $script:CleanupCFGFiles=$false
        $script:InPlace=$true
        $script:CreateBackup=$false
    }

    if (-not (Test-Prerequisites)) {
        throw "Prerequisites check failed. Please resolve the issues above."
    }

    if (-not $UseDHCP) {
        if ([string]::IsNullOrWhiteSpace($StaticIP) -or 
            [string]::IsNullOrWhiteSpace($Subnet) -or 
            [string]::IsNullOrWhiteSpace($Gateway)) {
            throw "Static IP configuration requires StaticIP, Subnet, and Gateway parameters"
        }
    }

    $isoInfo = Initialize-ISOOperation
    
    Write-Host "`n$(Get-ModificationSummary -ISOInfo $isoInfo)" -ForegroundColor Yellow
    Write-Host "`nPress Enter to continue or Ctrl+C to abort..." -ForegroundColor Cyan
    $null = Read-Host  # discard return value -- otherwise it pollutes the function pipeline

    Write-Log "Extracting configuration files from ISO..." 'Info'

    Invoke-ISOExtractConfig -TargetISO $isoInfo.TargetISO -KickstartName $CFGname

    Write-Log "Configuring GRUB bootloader..." 'Info'
    $pattern = "^(.*LABEL=VeeamJeOS:/$CFGname quiet.*)$"
    Update-FileContent -FilePath "grub.cfg" -Pattern $pattern -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Infrastructure Appliance (with iSCSI & NVMe/TCP)>Install - fresh install, wipes everything (including local backups)"'
    Set-GrubDefaultAndTimeout -DefaultLabel $newDefault -Timeout $GrubTimeout

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "$CFGname" -Layout $KeyboardLayout
    Set-Timezone -FilePath "$CFGname" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -UseDHCP:$true -EnableIPv6 $EnableIPv6
    } else {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers -EnableIPv6 $EnableIPv6
    }

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)
    #####
    #Optional Modifications 
    #####

    #####
    #SSh modifications for DEBUG mode
    #####
    if ($Debug) {
        Set-DebugSSHModifications -FilePath "$CFGname"
    }

    if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-OfflineRepoFileCopyBlock)
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-NodeExporterOfflineBlock)
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)
        if (-not $CFGOnly) {
            Add-FolderToISO -TargetISO $isoInfo.TargetISO -LocalPath "offline_repo" -ISOPath "/offline_repo"
        }
    }

    ConvertTo-LFLineEnding -Files @($CFGname, "grub.cfg")

    if(-not $CFGOnly){
        Invoke-ISOCommit -TargetISO $isoInfo.TargetISO -KickstartName $CFGname
    }

    return $isoInfo
}

#endregion

#region VIAHR Region Function

function Invoke-VIAHR {
    Write-Log "=================================================================================================="
    Write-Log "                         VIA WORKFLOW - Veeam Hardened Repository"
    Write-Log "=================================================================================================="

    $CFGname = "hardened-repo-ks.cfg"
    $script:ActiveCfgFile = $CFGname

    Write-Log "Config only set to $CFGOnly" 'Info'
    if($CFGOnly){
        $script:CleanupCFGFiles=$false
        $script:InPlace=$true
        $script:CreateBackup=$false
    }

    if (-not (Test-Prerequisites)) {
        throw "Prerequisites check failed. Please resolve the issues above."
    }

    if (-not $UseDHCP) {
        if ([string]::IsNullOrWhiteSpace($StaticIP) -or 
            [string]::IsNullOrWhiteSpace($Subnet) -or 
            [string]::IsNullOrWhiteSpace($Gateway)) {
            throw "Static IP configuration requires StaticIP, Subnet, and Gateway parameters"
        }
    }

    $isoInfo = Initialize-ISOOperation
    
    Write-Host "`n$(Get-ModificationSummary -ISOInfo $isoInfo)" -ForegroundColor Yellow
    Write-Host "`nPress Enter to continue or Ctrl+C to abort..." -ForegroundColor Cyan
    $null = Read-Host  # discard return value -- otherwise it pollutes the function pipeline

    Write-Log "Extracting configuration files from ISO..." 'Info'

    Invoke-ISOExtractConfig -TargetISO $isoInfo.TargetISO -KickstartName $CFGname

    Write-Log "Configuring GRUB bootloader..." 'Info'
    $pattern = "^(.*LABEL=VeeamJeOS:/$CFGname quiet.*)$"
    Update-FileContent -FilePath "grub.cfg" -Pattern $pattern -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Hardened Repository>Install - fresh install, wipes everything (including local backups)"'
    Set-GrubDefaultAndTimeout -DefaultLabel $newDefault -Timeout $GrubTimeout

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "$CFGname" -Layout $KeyboardLayout
    Set-Timezone -FilePath "$CFGname" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -UseDHCP:$true -EnableIPv6 $EnableIPv6
    } else {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers -EnableIPv6 $EnableIPv6
    }

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)
    ### 2.6.1 fix - hardened repo secret token not pairing automaticly
    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine '/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg' -NewLines ('export VEEAM_SECRETTOKEN="000000" && /opt/veeam/deployment/veeamdeploymentsvc --start-pairing --timeout -1')
    #####
    #Optional Modifications 
    #####

    #####
    #SSh modifications for DEBUG mode
    #####
    if ($Debug) {
        Set-DebugSSHModifications -FilePath "$CFGname"
    }

        if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-OfflineRepoFileCopyBlock)
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-NodeExporterOfflineBlock)
        Add-ContentAfterLine -FilePath $CFGname -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)
        if (-not $CFGOnly) {
            Add-FolderToISO -TargetISO $isoInfo.TargetISO -LocalPath "offline_repo" -ISOPath "/offline_repo"
        }
    } 

    ConvertTo-LFLineEnding -Files @($CFGname, "grub.cfg")

    if(-not $CFGOnly){
        Invoke-ISOCommit -TargetISO $isoInfo.TargetISO -KickstartName $CFGname
    }

    return $isoInfo
}

#endregion

#region Main Script Entry Point

try {
    $logFile = "ISO_Customization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Start-Transcript -Path $logFile -Append

    Write-Log "=================================================================================================="
    Write-Log "Veeam ISO Customization Script - Version 2.7"
    Write-Log "=================================================================================================="

    # JSON-ONLY MODE: defaults first, JSON wins for any key it defines.
    Set-DefaultParameter
    $jsonConfig = Import-JSONConfig -ConfigFilePath $ConfigFile
    Update-ParametersFromJSON -Config $jsonConfig
    Write-Log "Configuration loaded from JSON file: $ConfigFile" 'Info'

    # Post-load validation (ValidateSet was on the param block, now gone).
    $validApplianceTypes = @('VSA', 'VIA', 'VIAVMware', 'VIAHR')
    if ($ApplianceType -notin $validApplianceTypes) {
        throw "Invalid ApplianceType '$ApplianceType' in JSON. Must be one of: $($validApplianceTypes -join ', ')"
    }

    Write-Log "Selected Appliance Type: $ApplianceType" 'Info'

    switch ($ApplianceType) {
        "VSA" {
            Write-Log "Invoking VSA (Veeam Software Appliance) workflow..." 'Info'
            $resultISO = Invoke-VSA
        }
        "VIA" {
            Write-Log "Invoking Veeam Infrastructure Appliance workflow..." 'Info'
            $resultISO = Invoke-VIA
        }
        "VIAVMware" {
            Write-Log "Invoking Veeam Infrastructure Appliance (with iSCSI & NVMe/TCP) workflow..." 'Info'
            $resultISO = Invoke-VIAVMware
        }
        "VIAHR" {
            Write-Log "Invoking Veeam Hardened Repository workflow..." 'Info'
            $resultISO = Invoke-VIAHR
        }
    }

    # Unified success + cleanup (replaces the 4 duplicated blocks that previously
    # lived at the end of each Invoke-* function).
    Show-SuccessSummary -ISOInfo $resultISO
    Remove-TempCfgFile

    Write-Log "Script execution completed successfully" 'Info'

} catch {
    Write-Log "Script failed: $($_.Exception.Message)" 'Error'

    Write-Host "`n==================================================================================================" -ForegroundColor Red
    Write-Host "                                        FAILURE!" -ForegroundColor Red
    Write-Host "==================================================================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check log file: $logFile" -ForegroundColor Red
    Write-Host "==================================================================================================" -ForegroundColor Red

    Remove-TempCfgFile

    if ($isoInfo -and -not $isoInfo.IsInPlace -and (Test-Path $isoInfo.TargetISO -ErrorAction SilentlyContinue)) {
        Write-Log "Cleaning up failed working copy" 'Info'
        Remove-Item $isoInfo.TargetISO -Force -ErrorAction SilentlyContinue
    }

    exit 1
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue
}

#endregion

# End of script