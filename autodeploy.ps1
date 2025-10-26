<#
.SYNOPSIS
Veeam Appliance ISO Automation Tool

.LICENSE
MIT License - see LICENSE file for details

.AUTHOR
Baptiste TELLIER

.COPYRIGHT
Copyright (c) 2025 Baptiste TELLIER

.VERSION 2.3

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
Path to JSON configuration file containing all script parameters. When specified, parameters from JSON file take precedence over default values.
Command line parameters will override JSON values. Example: "production-config.json"

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
Network Time Protocol (NTP) server for system time synchronization.
Accepts either fully qualified domain name (FQDN) or IP address.
Proper time synchronization is critical for Veeam operations, backup scheduling, and certificate validation.
Recommended to use your organization's internal NTP servers or reliable public pools.
Examples: "pool.ntp.org", "time.windows.com", "192.168.1.10"
Default: "time.nist.gov"

.PARAMETER NodeExporter
Boolean flag to enable node_exporter deployment. 
Default: $false

.PARAMETER NodeExporterDNF
Boolean flag to enable node_exporter deployment using DNF package manager.
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

.EXAMPLE
Using JSON configuration file with VSA appliance (Recommended)
.\autodeploy.ps1 -ConfigFile "production-config.json"

.NOTES
File Name      : autodeploy.ps1
Author         : Baptiste TELLIER
Prerequisite   : PowerShell 5.1+, WSL with xorriso installed
Version        : 2.3
Creation Date  : 24/09/2025
Last Modified  : 26/10/2025

REQUIREMENTS:
- Windows Subsystem for Linux (WSL) with xorriso package installed
- Source ISO file must be in the same directory as this script
- Optional: JSON configuration file for simplified parameter management
- Optional: 'license' folder with .lic files for license automation
- Optional: 'node_exporter' folder with binaries for monitoring deployment

USAGE:
- Place this script in the same directory as your ISO file
- Create a JSON configuration file with your desired settings
- Run the script with -ConfigFile and -ApplianceType parameters
- All operations happen in the current directory

JSON CONFIGURATION:
The script supports loading all parameters from a JSON configuration file. Command line parameters will override JSON values.
See example JSON file for proper structure and supported parameters.

OUTPUT:
- Customized ISO
- grub.cfg (optional)
- vbr-ks.cfg (optional)
- ISO_Customization.log

#>

#region Parameters
param (
    # Appliance Type Selection
    [ValidateSet("VSA", "VIA", "VIAVMware", "VIAHR")]
    [string]$ApplianceType = "VSA",

    # JSON Configuration File
    [string]$ConfigFile = "",

    # Core Parameters
    [string]$SourceISO = "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso",
    [string]$OutputISO = "",
    [switch]$InPlace = $false,
    [bool]$CreateBackup = $true,

    ##DEBUG### 
    [bool]$CleanupCFGFiles = $true,
    [bool]$CFGOnly = $false,

    ##### GRUB Configuration #####
    [int]$GrubTimeout = 10,

    ##### OS configuration #####
    [string]$KeyboardLayout = "fr",
    [string]$Timezone = "Europe/Paris",

    ##### Network configuration #####
    [string]$Hostname = "veeam-server",
    [switch]$UseDHCP = $false,
    [string]$StaticIP = "192.168.1.166",
    [string]$Subnet = "255.255.255.0",
    [string]$Gateway = "192.168.1.1",
    [string[]]$DNSServers = @("192.168.1.64", "8.8.4.4"),

    ##### Veeam configuration #####
    [string]$VeeamAdminPassword = "123q123Q123!123",
    [string]$VeeamAdminMfaSecretKey = "JBSWY3DPEHPK3PXP",
    [string]$VeeamAdminIsMfaEnabled = "true",
    [string]$VeeamSoPassword = "123w123W123!123",
    [string]$VeeamSoMfaSecretKey = "JBSWY3DPEHPK3PXP",
    [string]$VeeamSoIsMfaEnabled = "true",
    [string]$VeeamSoRecoveryToken = "eb9fcbf4-2be6-e94d-4203-dded67c5a450",
    [string]$VeeamSoIsEnabled = "true",
    [string]$NtpServer = "time.nist.gov",
    [string]$NtpRunSync = "true",

    ##### optional features #####
    [bool]$NodeExporter = $false,
    [bool]$NodeExporterDNF = $false,
    [bool]$LicenseVBRTune = $false,
    [string]$LicenseFile = "Veeam-100instances-entplus-monitoring-nfr.lic",
    [string]$SyslogServer = "",
    [bool]$VCSPConnection = $false,
    [string]$VCSPUrl = "",
    [string]$VCSPLogin = "",
    [string]$VCSPPassword = "",
    [bool]$RestoreConfig = $false,
    [string]$ConfigPasswordSo = ""
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

function Update-ParametersFromJSON {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    Write-Log "Applying JSON configuration..." 'Info'
    
    $parametersUpdated = 0
    
    if ($Config.PSObject.Properties['ApplianceType'] -and -not $PSBoundParameters.ContainsKey('ApplianceType')) {
        $script:ApplianceType = $Config.ApplianceType
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['SourceISO'] -and -not $PSBoundParameters.ContainsKey('SourceISO')) {
        $script:SourceISO = $Config.SourceISO
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['OutputISO'] -and -not $PSBoundParameters.ContainsKey('OutputISO')) {
        $script:OutputISO = $Config.OutputISO
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['InPlace'] -and -not $PSBoundParameters.ContainsKey('InPlace')) {
        $script:InPlace = $Config.InPlace
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['CreateBackup'] -and -not $PSBoundParameters.ContainsKey('CreateBackup')) {
        $script:CreateBackup = $Config.CreateBackup
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['CleanupCFGFiles'] -and -not $PSBoundParameters.ContainsKey('CleanupCFGFiles')) {
        $script:CleanupCFGFiles = $Config.CleanupCFGFiles
        $parametersUpdated++
    }

    if ($Config.PSObject.Properties['CFGOnly'] -and -not $PSBoundParameters.ContainsKey('CFGOnly')) {
        $script:CFGOnly = $Config.CFGOnly
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['GrubTimeout'] -and -not $PSBoundParameters.ContainsKey('GrubTimeout')) {
        $script:GrubTimeout = $Config.GrubTimeout
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['KeyboardLayout'] -and -not $PSBoundParameters.ContainsKey('KeyboardLayout')) {
        $script:KeyboardLayout = $Config.KeyboardLayout
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Timezone'] -and -not $PSBoundParameters.ContainsKey('Timezone')) {
        $script:Timezone = $Config.Timezone
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Hostname'] -and -not $PSBoundParameters.ContainsKey('Hostname')) {
        $script:Hostname = $Config.Hostname
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['UseDHCP'] -and -not $PSBoundParameters.ContainsKey('UseDHCP')) {
        $script:UseDHCP = $Config.UseDHCP
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['StaticIP'] -and -not $PSBoundParameters.ContainsKey('StaticIP')) {
        $script:StaticIP = $Config.StaticIP
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Subnet'] -and -not $PSBoundParameters.ContainsKey('Subnet')) {
        $script:Subnet = $Config.Subnet
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Gateway'] -and -not $PSBoundParameters.ContainsKey('Gateway')) {
        $script:Gateway = $Config.Gateway
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['DNSServers'] -and -not $PSBoundParameters.ContainsKey('DNSServers')) {
        $script:DNSServers = $Config.DNSServers
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamAdminPassword'] -and -not $PSBoundParameters.ContainsKey('VeeamAdminPassword')) {
        $script:VeeamAdminPassword = $Config.VeeamAdminPassword
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamAdminMfaSecretKey'] -and -not $PSBoundParameters.ContainsKey('VeeamAdminMfaSecretKey')) {
        $script:VeeamAdminMfaSecretKey = $Config.VeeamAdminMfaSecretKey
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamAdminIsMfaEnabled'] -and -not $PSBoundParameters.ContainsKey('VeeamAdminIsMfaEnabled')) {
        $script:VeeamAdminIsMfaEnabled = $Config.VeeamAdminIsMfaEnabled
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoPassword'] -and -not $PSBoundParameters.ContainsKey('VeeamSoPassword')) {
        $script:VeeamSoPassword = $Config.VeeamSoPassword
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoMfaSecretKey'] -and -not $PSBoundParameters.ContainsKey('VeeamSoMfaSecretKey')) {
        $script:VeeamSoMfaSecretKey = $Config.VeeamSoMfaSecretKey
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoIsMfaEnabled'] -and -not $PSBoundParameters.ContainsKey('VeeamSoIsMfaEnabled')) {
        $script:VeeamSoIsMfaEnabled = $Config.VeeamSoIsMfaEnabled
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoRecoveryToken'] -and -not $PSBoundParameters.ContainsKey('VeeamSoRecoveryToken')) {
        $script:VeeamSoRecoveryToken = $Config.VeeamSoRecoveryToken
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoIsEnabled'] -and -not $PSBoundParameters.ContainsKey('VeeamSoIsEnabled')) {
        $script:VeeamSoIsEnabled = $Config.VeeamSoIsEnabled
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['NtpServer'] -and -not $PSBoundParameters.ContainsKey('NtpServer')) {
        $script:NtpServer = $Config.NtpServer
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['NtpRunSync'] -and -not $PSBoundParameters.ContainsKey('NtpRunSync')) {
        $script:NtpRunSync = $Config.NtpRunSync
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['NodeExporter'] -and -not $PSBoundParameters.ContainsKey('NodeExporter')) {
        $script:NodeExporter = $Config.NodeExporter
        $parametersUpdated++
    }

    if ($Config.PSObject.Properties['NodeExporterDNF'] -and -not $PSBoundParameters.ContainsKey('NodeExporterDNF')) {
        $script:NodeExporterDNF = $Config.NodeExporterDNF
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['LicenseVBRTune'] -and -not $PSBoundParameters.ContainsKey('LicenseVBRTune')) {
        $script:LicenseVBRTune = $Config.LicenseVBRTune
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['LicenseFile'] -and -not $PSBoundParameters.ContainsKey('LicenseFile')) {
        $script:LicenseFile = $Config.LicenseFile
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['SyslogServer'] -and -not $PSBoundParameters.ContainsKey('SyslogServer')) {
        $script:SyslogServer = $Config.SyslogServer
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPConnection'] -and -not $PSBoundParameters.ContainsKey('VCSPConnection')) {
        $script:VCSPConnection = $Config.VCSPConnection
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPUrl'] -and -not $PSBoundParameters.ContainsKey('VCSPUrl')) {
        $script:VCSPUrl = $Config.VCSPUrl
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPLogin'] -and -not $PSBoundParameters.ContainsKey('VCSPLogin')) {
        $script:VCSPLogin = $Config.VCSPLogin
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPPassword'] -and -not $PSBoundParameters.ContainsKey('VCSPPassword')) {
        $script:VCSPPassword = $Config.VCSPPassword
        $parametersUpdated++
    }

    if ($Config.PSObject.Properties['RestoreConfig'] -and -not $PSBoundParameters.ContainsKey('RestoreConfig')) {
        $script:RestoreConfig = $Config.RestoreConfig
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['ConfigPasswordSo'] -and -not $PSBoundParameters.ContainsKey('ConfigPasswordSo')) {
        $script:ConfigPasswordSo = $Config.ConfigPasswordSo
        $parametersUpdated++
    }
    
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
        IsInPlace = $InPlace.IsPresent
        Mode = if ($CFGOnly) {"CFG ONLY"} elseif ($InPlace) { "In-Place" } else { "Out-of-Place" }
        RestoreConfig = $RestoreConfig
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

    $summary += ""
    $summary += "OPTIONAL FEATURES:"
    $summary += "  Node Exporter Local: $(if ($NodeExporter) { 'Enabled' } else { 'Disabled' })"
    $summary += "  Node Exporter Online: $(if ($NodeExporterDNF) { 'Enabled' } else { 'Disabled' })"
    if($ApplianceType -eq "VSA"){
    $summary += "  License Auto-Install: $(if ($LicenseVBRTune) { 'Enabled' } else { 'Disabled' })"
    $summary += "  VCSP Connection: $(if ($VCSPConnection) { 'Enabled' } else { 'Disabled' })"
    $summary += "  Restore Config: $(if ($ISOInfo.RestoreConfig) { 'Enabled' } else { 'Disabled' })"
    }
    $summary += "=================================================================================================="

    return $summary -join "`n"
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
        $newContent = @()

        foreach ($line in $content) {
            $newContent += $line
            if ($line -like "*$TargetLine*") {
                $newContent += $NewLines
                Write-Log "Added content after line: $TargetLine" 'Info'
            }
        }

        Set-Content $FilePath $newContent
    }
    catch {
        Write-Log "Failed to add content to $FilePath`: $($_.Exception.Message)" 'Error'
        throw
    }
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
        [string[]]$DNSServers
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

#endregion

#region Dynamic Configuration Block Functions

function Get-CustomVBRBlock {
    $block = @(
        "echo 'Applying license file...'",
        "pwsh -Command '",
        "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
        "Install-VBRLicense -Path /etc/veeam/license/$LicenseFile"
    )
    
    # Ajouter la ligne syslog seulement si SyslogServer a une valeur
    if ($SyslogServer) {
        $block += "Set-VBRServerSyslog -SyslogServer '$SyslogServer' -SyslogPort 514 -Protocol UDP"
    }
    $block += "echo 'License file applied successfully'"
    $block += "'"
    
    return $block
}

function Get-CustomVCSPBlock {
    return @(
        "# Connect to Service Provider with Mgmt Agent",
        "pwsh -Command '",
        "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
        "Add-VBRCloudProviderCredentials -Name '$VCSPLogin' -Password '$VCSPPassword'",
        "`$credentials = Get-VBRCloudProviderCredentials -Name '$VCSPLogin'",
        "Add-VBRCloudProvider -Address '$VCSPUrl' -Credentials `$credentials -InstallManagementAgent",
        "'"
    )
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

function Get-CopyNodeExporterBlock {
    return @(
        "# Copy node_exporter files to OS",
        "log 'starting node_exporter files copy'",
        "mkdir -p /mnt/sysimage/etc/node_exporter",
        "if [ -d /mnt/install/repo/node_exporter ]; then",
        "    cp -r /mnt/install/repo/node_exporter /mnt/sysimage/etc/",
        "fi",
        "log 'node_exporter files copy completed'"
    )
}

function Get-NodeExporterSetupBlock {
    return @(
        "# Setup node_exporter service",
        "log 'starting node_exporter installation'",
        "groupadd -f node_exporter",
        "useradd -g node_exporter --no-create-home --shell /bin/false node_exporter",
        "chown node_exporter:node_exporter /etc/node_exporter",
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
        "chmod 664 /etc/systemd/system/node_exporter.service",
        "systemctl daemon-reload",
        "systemctl enable node_exporter.service",
        "log 'node_exporter installation completed'"
    )
}

function Get-NodeExporterFirewallBlock {
    return @(
        "# Configure firewall for node_exporter",
        "firewall-cmd --permanent --zone=drop --add-port=9100/tcp",
        "firewall-cmd --reload"
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
        "ntp.servers=$NtpServer",
        "ntp.runSync=$NtpRunSync",
        "vbr_control.runInitIso=true",
        "vbr_control.runStart=true",
        "EOF",
        "###############################################################################",
        "#  Automatic Host Manager configuration TRIGGER AFTER REBOOT",
        "###############################################################################",
        "log 'starting /etc/veeam/veeam-init.sh'",
        "cat << EOF >> /etc/veeam/veeam-init.sh",
        "#!/bin/bash",
        "set -eE -u -o pipefail",
        "# Configuration logging",
        "exec > >(tee -a '/var/log/veeam_init.log') 2>&1",
        "echo 'Applying initial Veeam configuration...'",
        "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg",
        "echo 'Disabling veeam-init service...'",
        "systemctl disable veeam-init",
        "echo 'OK : Service disabled'",
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

function Get-NodeExporterDNFBlock {
    return @(
        "log '[1/4] Enabling Rocky Linux repos and EPEL...'",
        "rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm",
        "dnf clean all && dnf -y makecache",
        "dnf -y install dnf-plugins-core || true",
        "dnf -y config-manager --set-enabled crb || true",
        "dnf -y install epel-release",
        "dnf -y makecache",

        "log '[2/4] Installing node_exporter...'",
        "dnf -y install node_exporter",

        "log '[3/4] Configuring /etc/sysconfig/node_exporter ...'",
        'bash -c ''echo OPTIONS="--web.listen-address=0.0.0.0:9100" > /etc/sysconfig/node_exporter''',

        "log '[4/4] Enabling and starting node_exporter...'",
        "systemctl daemon-reload",
        "systemctl enable node_exporter.service",
        "log 'node_exporter installation completed'"
    )
}

function Get-InstalloathtoolBlock {
    return @(
        "log '[1/2] Enabling Rocky Linux repos and EPEL...'",
        "rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm",
        "dnf clean all && dnf -y makecache",
        "log '[2/2] Installing oathtool and curl...'",
        "dnf -y install oathtool",
        "dnf -y install curl",
        "log 'oathtool and curl installation completed'"
    )
}

function Get-VeeamRestoreConfigBlock {
   
    return @(
        "sleep 10s",
        "echo 'Configuring SO backup password'",
        "chmod +x '/etc/veeam/veeam_addsoconfpw.sh'",
        "/bin/bash /etc/veeam/veeam_addsoconfpw.sh '$script:ConfigPasswordSo' '$script:VeeamSoMfaSecretKey' '$script:VeeamSoPassword'",
        "echo 'OK : Configuration SO password set'",
        "sleep 10s",
        "echo 'Restoring configuration...'",
        "dotnet /opt/veeam/vbr/Veeam.Backup.Configuration.UnattendedRestore.dll /file:/var/lib/veeam/unattended.xml 2>&1 | tee -a /var/log/veeam_configrestore.log",
        "echo 'OK : Configuration restored'",
        "echo 'Additional logs:'",
        "echo '  - Password SO config: /var/log/veeam_addsoconfpw.log'",
        "echo '  - Config restore: /var/log/veeam_configrestore.log'",
        "echo 'Cleaning up oathtool curl and rm unattended.xml veeam_addsoconfpw.sh ...'",
        "dnf -y remove oathtool curl",
        "rm -f /var/lib/veeam/unattended.xml",
        "rm -f /etc/veeam/veeam_addsoconfpw.sh"
        )
        #need remove own script after run and uninstall oathtool and curl and unattended.xml
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

#endregion

#region VSA Region Function

function Invoke-VSA {
    Write-Log "=================================================================================================="
    Write-Log "                         VSA WORKFLOW - VEEAM SOFTWARE APPLIANCE"
    Write-Log "=================================================================================================="

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
    Read-Host

    Write-Log "Extracting configuration files from ISO..." 'Info'

    $extractCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract vbr-ks.cfg vbr-ks.cfg",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract /EFI/BOOT/grub.cfg grub.cfg"
    )

    foreach ($cmd in $extractCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Extract configuration files")) {
            throw "Failed to extract files from ISO"
        }
    }

    @("vbr-ks.cfg", "grub.cfg") | ForEach-Object {
        if (-not (Test-Path $_)) {
            throw "Required file not extracted: $_"
        }
        Write-Log "File extracted: $_" 'Info'
    }

    Write-Log "Configuring GRUB bootloader..." 'Info'
    Update-FileContent -FilePath "grub.cfg" -Pattern '^(.*LABEL=Rocky-9-2-x86_64:/vbr-ks.cfg quiet.*)$' -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Backup & Replication v13.0>Install - fresh install, wipes everything (including local backups)"'
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set default=.*' -Replacement "set default=$newDefault"
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set timeout=.*' -Replacement "set timeout=$GrubTimeout"

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "vbr-ks.cfg" -Layout $KeyboardLayout
    Set-Timezone -FilePath "vbr-ks.cfg" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -UseDHCP:$true
    } else {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers
    }

    Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)

        if ($RestoreConfig) {
        Write-Log "Adding restore configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-RestoreFileCopyBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-VeeamRestoreConfigBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-InstalloathtoolBlock)

        if (Test-Path "conf") {
            $confCmd = "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map conf /conf"
            Invoke-WSLCommand -Command $confCmd -Description "Add conf folder to ISO" | Out-Null
        }
    }

    if ($LicenseVBRTune) {
        Write-Log "Adding license configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-CustomVBRBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-CopyLicenseBlock)

        if (Test-Path "license") {
            $licenseCmd = "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map license /license"
            Invoke-WSLCommand -Command $licenseCmd -Description "Add license folder to ISO" | Out-Null
        }
    }

    if ($VCSPConnection) {
        Write-Log "Adding VCSP configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-CustomVCSPBlock)
    }

    if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-NodeExporterSetupBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-CopyNodeExporterBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)

        if (Test-Path "node_exporter") {
            $nodeCmd = "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map node_exporter /node_exporter"
            Invoke-WSLCommand -Command $nodeCmd -Description "Add node_exporter folder to ISO" | Out-Null
        }
    }

    if ($NodeExporterDNF){
        Write-Log "Adding node_exporter with DNF configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-NodeExporterDNFBlock)
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)
    }



    Write-Log "Normalizing line endings..." 'Info'
    @("vbr-ks.cfg", "grub.cfg") | ForEach-Object {
        $content = Get-Content $_ -Raw
        $content = $content.Replace("`r`n", "`n")
        Set-Content $_ $content -NoNewline
    }
    
    if(-not $CFGOnly){
        Write-Log "Committing changes to ISO..." 'Info'

        $commitCommands = @(
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm vbr-ks.cfg",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map vbr-ks.cfg vbr-ks.cfg",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm /EFI/BOOT/grub.cfg",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map grub.cfg /EFI/BOOT/grub.cfg"
        )

        foreach ($cmd in $commitCommands) {
            if (-not (Invoke-WSLCommand -Command $cmd -Description "Commit changes to ISO")) {
                throw "Failed to commit changes to ISO"
            }
        }

        Write-Log "ISO customization completed successfully!" 'Info'
    }

    Write-Host "`n==================================================================================================" -ForegroundColor Green
    Write-Host "                                        SUCCESS!" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green
    Write-Host "Customized ISO: $($isoInfo.TargetISO)" -ForegroundColor Green
    if ($isoInfo.BackupPath) {
        Write-Host "Backup created: $($isoInfo.BackupPath)" -ForegroundColor Green
    }
    Write-Host "Mode: $($isoInfo.Mode)" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green

    if($CleanupCFGFiles){
        @("vbr-ks.cfg", "grub.cfg") | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force
            }
        }
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
    Read-Host

    Write-Log "Extracting configuration files from ISO..." 'Info'

    $extractCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract $CFGname $CFGname",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract /EFI/BOOT/grub.cfg grub.cfg"
    )

    foreach ($cmd in $extractCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Extract configuration files")) {
            throw "Failed to extract files from ISO"
        }
    }

    @("$CFGname", "grub.cfg") | ForEach-Object {
        if (-not (Test-Path $_)) {
            throw "Required file not extracted: $_"
        }
        Write-Log "File extracted: $_" 'Info'
    }

    Write-Log "Configuring GRUB bootloader..." 'Info'
    $pattern = "^(.*LABEL=Rocky-9-2-x86_64:/$CFGname quiet.*)$"
    Update-FileContent -FilePath "grub.cfg" -Pattern $pattern -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Infrastructure Appliance>Install - fresh install, wipes everything (including local backups)"'
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set default=.*' -Replacement "set default=$newDefault"
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set timeout=.*' -Replacement "set timeout=$GrubTimeout"

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "$CFGname" -Layout $KeyboardLayout
    Set-Timezone -FilePath "$CFGname" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -UseDHCP:$true
    } else {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers
    }

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)

     if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-NodeExporterSetupBlock)
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-CopyNodeExporterBlock)
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)

        if (Test-Path "node_exporter") {
            $nodeCmd = "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map node_exporter /node_exporter"
            Invoke-WSLCommand -Command $nodeCmd -Description "Add node_exporter folder to ISO" | Out-Null
        }
    }

    if ($NodeExporterDNF){
        Write-Log "Adding node_exporter with DNF configuration..." 'Info'
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-NodeExporterDNFBlock)
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)
    }

    Write-Log "Normalizing line endings..." 'Info'
    @("$CFGname", "grub.cfg") | ForEach-Object {
        $content = Get-Content $_ -Raw
        $content = $content.Replace("`r`n", "`n")
        Set-Content $_ $content -NoNewline
    }
    
    if(-not $CFGOnly){
        Write-Log "Committing changes to ISO..." 'Info'

        $commitCommands = @(
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm $CFGname",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map $CFGname $CFGname",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm /EFI/BOOT/grub.cfg",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map grub.cfg /EFI/BOOT/grub.cfg"
        )

        foreach ($cmd in $commitCommands) {
            if (-not (Invoke-WSLCommand -Command $cmd -Description "Commit changes to ISO")) {
                throw "Failed to commit changes to ISO"
            }
        }

        Write-Log "ISO customization completed successfully!" 'Info'
    }

    Write-Host "`n==================================================================================================" -ForegroundColor Green
    Write-Host "                                        SUCCESS!" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green
    Write-Host "Customized ISO: $($isoInfo.TargetISO)" -ForegroundColor Green
    if ($isoInfo.BackupPath) {
        Write-Host "Backup created: $($isoInfo.BackupPath)" -ForegroundColor Green
    }
    Write-Host "Appliance Type: $($ApplianceType)" -ForegroundColor Green
    Write-Host "Mode: $($isoInfo.Mode)" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green

    if($CleanupCFGFiles){
        @("$CFGname", "grub.cfg") | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force
            }
        }
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
    Read-Host

    Write-Log "Extracting configuration files from ISO..." 'Info'

    $extractCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract $CFGname $CFGname",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract /EFI/BOOT/grub.cfg grub.cfg"
    )

    foreach ($cmd in $extractCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Extract configuration files")) {
            throw "Failed to extract files from ISO"
        }
    }

    @("$CFGname", "grub.cfg") | ForEach-Object {
        if (-not (Test-Path $_)) {
            throw "Required file not extracted: $_"
        }
        Write-Log "File extracted: $_" 'Info'
    }

    Write-Log "Configuring GRUB bootloader..." 'Info'
    $pattern = "^(.*LABEL=Rocky-9-2-x86_64:/$CFGname quiet.*)$"
    Update-FileContent -FilePath "grub.cfg" -Pattern $pattern -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Infrastructure Appliance (with iSCSI & NVMe/TCP)>Install - fresh install, wipes everything (including local backups)"'
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set default=.*' -Replacement "set default=$newDefault"
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set timeout=.*' -Replacement "set timeout=$GrubTimeout"

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "$CFGname" -Layout $KeyboardLayout
    Set-Timezone -FilePath "$CFGname" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -UseDHCP:$true
    } else {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers
    }

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)

     if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-NodeExporterSetupBlock)
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines (Get-CopyNodeExporterBlock)
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)

        if (Test-Path "node_exporter") {
            $nodeCmd = "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map node_exporter /node_exporter"
            Invoke-WSLCommand -Command $nodeCmd -Description "Add node_exporter folder to ISO" | Out-Null
        }
    }

    if ($NodeExporterDNF){
        Write-Log "Adding node_exporter with DNF configuration..." 'Info'
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines (Get-NodeExporterDNFBlock)
        Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines (Get-NodeExporterFirewallBlock)
    }

    Write-Log "Normalizing line endings..." 'Info'
    @("$CFGname", "grub.cfg") | ForEach-Object {
        $content = Get-Content $_ -Raw
        $content = $content.Replace("`r`n", "`n")
        Set-Content $_ $content -NoNewline
    }
    
    if(-not $CFGOnly){
        Write-Log "Committing changes to ISO..." 'Info'

        $commitCommands = @(
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm $CFGname",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map $CFGname $CFGname",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm /EFI/BOOT/grub.cfg",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map grub.cfg /EFI/BOOT/grub.cfg"
        )

        foreach ($cmd in $commitCommands) {
            if (-not (Invoke-WSLCommand -Command $cmd -Description "Commit changes to ISO")) {
                throw "Failed to commit changes to ISO"
            }
        }

        Write-Log "ISO customization completed successfully!" 'Info'
    }

    Write-Host "`n==================================================================================================" -ForegroundColor Green
    Write-Host "                                        SUCCESS!" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green
    Write-Host "Customized ISO: $($isoInfo.TargetISO)" -ForegroundColor Green
    if ($isoInfo.BackupPath) {
        Write-Host "Backup created: $($isoInfo.BackupPath)" -ForegroundColor Green
    }
    Write-Host "Appliance Type: $($ApplianceType)" -ForegroundColor Green
    Write-Host "Mode: $($isoInfo.Mode)" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green

    if($CleanupCFGFiles){
        @("$CFGname", "grub.cfg") | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force
            }
        }
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
    Read-Host

    Write-Log "Extracting configuration files from ISO..." 'Info'

    $extractCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract $CFGname $CFGname",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract /EFI/BOOT/grub.cfg grub.cfg"
    )

    foreach ($cmd in $extractCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Extract configuration files")) {
            throw "Failed to extract files from ISO"
        }
    }

    @("$CFGname", "grub.cfg") | ForEach-Object {
        if (-not (Test-Path $_)) {
            throw "Required file not extracted: $_"
        }
        Write-Log "File extracted: $_" 'Info'
    }

    Write-Log "Configuring GRUB bootloader..." 'Info'
    $pattern = "^(.*LABEL=Rocky-9-2-x86_64:/$CFGname quiet.*)$"
    Update-FileContent -FilePath "grub.cfg" -Pattern $pattern -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Hardened Repository>Install - fresh install, wipes everything (including local backups)"'
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set default=.*' -Replacement "set default=$newDefault"
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set timeout=.*' -Replacement "set timeout=$GrubTimeout"

    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "$CFGname" -Layout $KeyboardLayout
    Set-Timezone -FilePath "$CFGname" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -UseDHCP:$true
    } else {
        Set-NetworkConfiguration -FilePath "$CFGname" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers
    }

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    Add-ContentAfterLine -FilePath "$CFGname" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines (Get-VeeamHostConfigBlock)

    Write-Log "Normalizing line endings..." 'Info'
    @("$CFGname", "grub.cfg") | ForEach-Object {
        $content = Get-Content $_ -Raw
        $content = $content.Replace("`r`n", "`n")
        Set-Content $_ $content -NoNewline
    }
    
    if(-not $CFGOnly){
        Write-Log "Committing changes to ISO..." 'Info'

        $commitCommands = @(
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm $CFGname",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map $CFGname $CFGname",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm /EFI/BOOT/grub.cfg",
            "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map grub.cfg /EFI/BOOT/grub.cfg"
        )

        foreach ($cmd in $commitCommands) {
            if (-not (Invoke-WSLCommand -Command $cmd -Description "Commit changes to ISO")) {
                throw "Failed to commit changes to ISO"
            }
        }

        Write-Log "ISO customization completed successfully!" 'Info'
    }

    Write-Host "`n==================================================================================================" -ForegroundColor Green
    Write-Host "                                        SUCCESS!" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green
    Write-Host "Customized ISO: $($isoInfo.TargetISO)" -ForegroundColor Green
    if ($isoInfo.BackupPath) {
        Write-Host "Backup created: $($isoInfo.BackupPath)" -ForegroundColor Green
    }
    Write-Host "Appliance Type: $($ApplianceType)" -ForegroundColor Green
    Write-Host "Mode: $($isoInfo.Mode)" -ForegroundColor Green
    Write-Host "==================================================================================================" -ForegroundColor Green

    if($CleanupCFGFiles){
        @("$CFGname", "grub.cfg") | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force
            }
        }
    }

    return $isoInfo
}

#endregion

#region Main Script Entry Point

try {
    $logFile = "ISO_Customization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Start-Transcript -Path $logFile -Append

    Write-Log "=================================================================================================="
    Write-Log "Veeam ISO Customization Script - Version 2.3"
    Write-Log "=================================================================================================="

    if (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
        $jsonConfig = Import-JSONConfig -ConfigFilePath $ConfigFile
        Update-ParametersFromJSON -Config $jsonConfig
        Write-Log "Configuration loaded from JSON file: $ConfigFile" 'Info'
    } else {
        Write-Log "Using default parameters (no JSON configuration file specified)" 'Info'
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
        default {
            throw "Invalid ApplianceType: $ApplianceType. Valid values are 'VSA', 'VIA', 'VIAVMware', or 'VIAHR'."
        }
    }

    Write-Log "Script execution completed successfully" 'Info'

} catch {
    Write-Log "Script failed: $($_.Exception.Message)" 'Error'

    Write-Host "`n==================================================================================================" -ForegroundColor Red
    Write-Host "                                        FAILURE!" -ForegroundColor Red
    Write-Host "==================================================================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check log file: $logFile" -ForegroundColor Red
    Write-Host "==================================================================================================" -ForegroundColor Red

    if($CleanupCFGFiles){
        @("vbr-ks.cfg", "proxy-ks.cfg", "vmware-proxy-ks.cfg", "hardened-repo-ks.cfg", "grub.cfg") | ForEach-Object {
            if (Test-Path $_ -ErrorAction SilentlyContinue) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }

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