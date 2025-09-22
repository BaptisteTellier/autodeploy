<#
.SYNOPSIS
Automates the customization of Veeam Backup & Replication appliance ISO files for unattended Rocky Linux deployment with comprehensive configuration management.

.DESCRIPTION
This advanced PowerShell script provides end-to-end automation for customizing Veeam Software Appliance ISO files to enable fully automated, unattended installations. The script extracts and modifies critical configuration files including GRUB bootloader settings and Kickstart configuration files, implementing enterprise-grade customizations for network configuration, regional settings, security parameters, and optional component deployment.

Key capabilities include:
- Network Configuration: Supports both DHCP and static IP configurations with comprehensive validation
- Regional Settings: Configures keyboard layouts and timezone settings with proper validation
- Veeam core configuration Management: Implements Veeam auto deploy  
- Component Integration: Optional deployment of node_exporter monitoring and Veeam license automation
- Service Provider Integration: Automated VCSP (Veeam Cloud Service Provider) connection and management agent installation
- Enterprise Logging: Comprehensive logging system with timestamped Info/Warn/Error levels for audit trails
- Error Handling: Robust error handling with proper exception management and rollback capabilities

The script utilizes WSL (Windows Subsystem for Linux) with xorriso for ISO manipulation, ensuring reliable and repeatable modifications.

.PARAMETER LocalISO
Specifies the path to the source Veeam Software Appliance ISO file to be customized.
Default: "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso"

.PARAMETER GrubTimeout
Sets the GRUB bootloader timeout value in seconds before automatic boot selection.
Default: 30 seconds

.PARAMETER KeyboardLayout
Defines the keyboard layout code for the installation (e.g., 'us', 'fr', 'de', 'uk').
Must match standard keyboard layout codes. Default: "fr"

.PARAMETER Timezone
Specifies the system timezone in standard format (e.g., 'Europe/Paris', 'America/New_York', 'Asia/Tokyo').
Must follow the format Continent/City. Default: "Europe/Paris"

.PARAMETER Hostname
Sets the hostname for the deployed Veeam appliance. Must be a valid hostname following RFC standards.
Default: "veeam-server"

.PARAMETER UseDHCP
Switch parameter to configure network interface for DHCP. When set, static IP parameters are ignored.
Default: $true 

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
Default: @("8.8.8.8", "8.8.4.4")

.PARAMETER NodeExporter
Boolean flag to enable Prometheus node_exporter deployment for monitoring integration.
Requires node_exporter folder with binaries. 
Default: $false

.PARAMETER LicenseVBRTune
Boolean flag to enable automatic Veeam license installation and configuration.
Requires license folder with .lic files. 
Default: $false

.PARAMETER VCSPConnection
Boolean flag to enable Veeam Cloud Service Provider connection and management agent installation.
Default: $false

.EXAMPLE
Complete static IP configuration with all optional features disable
.\autodeployppxity.ps1 `
    -LocalISO "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" `
    -GrubTimeout 45 `
    -KeyboardLayout "us" `
    -Timezone "America/New_York" `
    -Hostname "veeam-backup-prod01" `
    -UseDHCP:$false `
    -StaticIP "10.50.100.150" `
    -Subnet "255.255.255.0" `
    -Gateway "10.50.100.1" `
    -DNSServers @("10.50.1.10", "10.50.1.11", "8.8.8.8") `
    -VeeamAdminPassword "P@ssw0rd2024!" `
    -VeeamAdminMfaSecretKey "ABCDEFGH12345678IJKLMNOP" `
    -VeeamAdminIsMfaEnabled "true" `
    -VeeamSoPassword "S3cur3P@ss!" `
    -VeeamSoMfaSecretKey "ZYXWVUTS87654321QPONMLKJ" `
    -VeeamSoIsMfaEnabled "true" `
    -VeeamSoRecoveryToken "12345678-90ab-cdef-1234-567890abcdef" `
    -VeeamSoIsEnabled "true" `
    -NtpServer "pool.ntp.org" `
    -NtpRunSync "true" `
    -NodeExporter $false `
    -LicenseVBRTune $false `
    -VCSPConnection $false

.EXAMPLE
Complete static IP configuration with all optional features enable
.\autodeployppxity.ps1 `
    -LocalISO "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" `
    -GrubTimeout 45 `
    -KeyboardLayout "us" `
    -Timezone "America/New_York" `
    -Hostname "veeam-backup-prod01" `
    -UseDHCP:$false `
    -StaticIP "10.50.100.150" `
    -Subnet "255.255.255.0" `
    -Gateway "10.50.100.1" `
    -DNSServers @("10.50.1.10", "10.50.1.11", "8.8.8.8") `
    -VeeamAdminPassword "P@ssw0rd2024!" `
    -VeeamAdminMfaSecretKey "ABCDEFGH12345678IJKLMNOP" `
    -VeeamAdminIsMfaEnabled "true" `
    -VeeamSoPassword "S3cur3P@ss!" `
    -VeeamSoMfaSecretKey "ZYXWVUTS87654321QPONMLKJ" `
    -VeeamSoIsMfaEnabled "true" `
    -VeeamSoRecoveryToken "12345678-90ab-cdef-1234-567890abcdef" `
    -VeeamSoIsEnabled "true" `
    -NtpServer "pool.ntp.org" `
    -NtpRunSync "true" `
    -NodeExporter $true `
    -LicenseVBRTune $true `
    -LicenseFile "Enterprise-Plus-License.lic" `
    -SyslogServer "10.50.1.20" `
    -VCSPConnection $true `
    -VCSPUrl "https://vcsp.company.com" `
    -VCSPLogin "serviceaccount" `
    -VCSPPassword "VCSPServiceP@ss!"

.EXAMPLE
Simple DHCP configuration for lab environment
.\autodeployppxity.ps1 `
    -LocalISO "VeeamAppliance-Lab.iso" `
    -GrubTimeout 10 `
    -KeyboardLayout "fr" `
    -Timezone "Europe/Paris" `
    -Hostname "veeam-lab-test" `
    -UseDHCP:$true `
    -VeeamAdminPassword "LabP@ss123" `
    -VeeamAdminIsMfaEnabled "false" `
    -VeeamSoPassword "SOLabP@ss123" `
    -VeeamSoIsMfaEnabled "false" `
    -VeeamSoIsEnabled "false" `
    -NodeExporter $false `
    -LicenseVBRTune $false `
    -VCSPConnection $false

.EXAMPLE
Enterprise deployment with German localization
.\autodeployppxity.ps1 `
    -LocalISO "C:\ISOs\VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" `
    -GrubTimeout 30 `
    -KeyboardLayout "de" `
    -Timezone "Europe/Berlin" `
    -Hostname "veeam-enterprise-de" `
    -UseDHCP:$false `
    -StaticIP "192.168.10.200" `
    -Subnet "255.255.255.0" `
    -Gateway "192.168.10.1" `
    -DNSServers @("192.168.10.10", "192.168.10.11") `
    -VeeamAdminPassword "EnterprisePw2024!" `
    -VeeamAdminMfaSecretKey "ENTERPRISE1234567890ABCD" `
    -VeeamAdminIsMfaEnabled "true" `
    -VeeamSoPassword "SOEnterprisePw!" `
    -VeeamSoMfaSecretKey "SOENTRPRS9876543210ZYXW" `
    -VeeamSoIsMfaEnabled "true" `
    -VeeamSoRecoveryToken "aaaabbbb-cccc-dddd-eeee-ffffgggghhh" `
    -VeeamSoIsEnabled "true" `
    -NtpServer "de.pool.ntp.org" `
    -NtpRunSync "true" `
    -NodeExporter $false `
    -LicenseVBRTune $true `
    -LicenseFile "Veeam-Enterprise-Germany.lic" `
    -SyslogServer "192.168.10.50" `
    -VCSPConnection $false

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
Customized IN PLACE ISO file with modified GRUB and Kickstart configurations. Generates detailed logs of all operations.

.NOTES
File Name      : autodeployppxity.ps1
Author         : Baptiste TELLIER
Prerequisite   : PowerShell 5.1+, WSL with xorriso installed
Version        : 2.0
Creation Date  : 22/09/2025

REQUIREMENTS:
- Windows Subsystem for Linux (WSL) with xorriso package installed
- Source Veeam Software Appliance ISO file
- Optional: license folder with .lic files for license automation
- Optional: node_exporter folder with binaries for monitoring deployment
- Appropriate permissions to read source ISO and write modified files

SECURITY CONSIDERATIONS:
- Script handles sensitive information including passwords and MFA keys
- Transcript logging may contain sensitive data - secure log files appropriately
- License files are copied with restricted permissions (600)

.LINK
https://github.com/prometheus/node_exporter/releases
For node_exporter binary downloads

.LINK
https://www.veeam.com/kb4772
Official Veeam support policy for node_exporter integration
#>


#region Parameters
param (
    [string]$LocalISO = "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso",
    
    [int]$GrubTimeout = 30,
    ##### OS configuration #####
    [string]$KeyboardLayout = "fr", #Keyboard layout code (e.g., 'us', 'fr', 'de')
    [string]$Timezone = "Europe/Paris", #Timezone value (e.g., 'Europe/Paris', 'America/New_York')
    
    ##### Network configuration #####
    [string]$Hostname = "veeam-server",
    [switch]$UseDHCP = $true, #set to $true for DHCP
    [string]$StaticIP = "192.168.1.166", #optional, only if $UseDHCP = $false
    [string]$Subnet = "255.255.255.0", #optional, only if $UseDHCP = $false
    [string]$Gateway = "192.168.1.1", #optional, only if $UseDHCP = $false
    [string[]]$DNSServers = @("192.168.1.64", "8.8.4.4"), #optional, only if $UseDHCP = $false
    
    ##### Veeam configuration #####
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
    
    ##### optional Node Exporter : Not supported by veeam support #####
    [bool]$NodeExporter = $false, #optional
    
    ##### optional Veeam configuration #####
    [bool]$LicenseVBRTune = $false, #optional
    [string]$LicenseFile = "Veeam-100instances-entplus-monitoring-nfr.lic",
    [string]$SyslogServer = "172.17.53.28",
    
    ##### optional Veeam configuration #####
    [bool]$VCSPConnection = $false, #optional, works only for v13.0.1 and above
    [string]$VCSPUrl = "192.168.1.202",
    [string]$VCSPLogin = "v13",
    [string]$VCSPPassword = "Azerty123!"
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

#region Configuration Functions

function Set-KeyboardLayout {
    <#
    .SYNOPSIS
    Configures keyboard layout in the kickstart file
    
    .DESCRIPTION
    Sets the keyboard layout configuration in the kickstart file with proper validation and error handling
    
    .PARAMETER FilePath
    Path to the kickstart configuration file
    
    .PARAMETER Layout
    Keyboard layout code (e.g., 'us', 'fr', 'de')
    
    .EXAMPLE
    Set-KeyboardLayout -FilePath "vbr-ks.cfg" -Layout "fr"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "File path $_ does not exist"
            }
            return $true
        })]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z]{2}(-[a-z]{2})?$')]
        [string]$Layout
    )
    
    try {
        Write-Log "Setting keyboard layout to $Layout" 'Info'
        Replace-InFile -FilePath $FilePath -Pattern "keyboard --xlayouts='[^']*'" -Replacement "keyboard --xlayouts='$Layout'"
        Write-Log "Keyboard layout successfully set to $Layout" 'Info'
    }
    catch {
        Write-Log "Failed to set keyboard layout: $($_.Exception.Message)" 'Error'
        throw "Keyboard layout configuration failed: $($_.Exception.Message)"
    }
}

function Set-Timezone {
    <#
    .SYNOPSIS
    Configures timezone in the kickstart file
    
    .DESCRIPTION
    Sets the timezone configuration in the kickstart file with proper validation and error handling
    
    .PARAMETER FilePath
    Path to the kickstart configuration file
    
    .PARAMETER TimezoneValue
    Timezone value (e.g., 'Europe/Paris', 'America/New_York')
    
    .EXAMPLE
    Set-Timezone -FilePath "vbr-ks.cfg" -TimezoneValue "Europe/Paris"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "File path $_ does not exist"
            }
            return $true
        })]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z_]+/[A-Za-z_]+$')]
        [string]$TimezoneValue
    )
    
    try {
        Write-Log "Setting timezone to $TimezoneValue" 'Info'
        Replace-InFile -FilePath $FilePath -Pattern "timezone [^\s]+ --utc" -Replacement "timezone $TimezoneValue --utc"
        Write-Log "Timezone successfully set to $TimezoneValue" 'Info'
    }
    catch {
        Write-Log "Failed to set timezone: $($_.Exception.Message)" 'Error'
        throw "Timezone configuration failed: $($_.Exception.Message)"
    }
}

function Set-NetworkConfiguration {
    <#
    .SYNOPSIS
    Configures network settings in the kickstart file
    
    .DESCRIPTION
    Sets network configuration in the kickstart file, supporting both DHCP and static IP configurations
    with proper validation and error handling following PowerShell best practices
    
    .PARAMETER FilePath
    Path to the kickstart configuration file
    
    .PARAMETER Hostname
    Hostname for the system
    
    .PARAMETER UseDHCP
    Switch parameter to use DHCP configuration (default)
    
    .PARAMETER StaticIP
    Static IP address (required when not using DHCP)
    
    .PARAMETER Subnet
    Subnet mask for static configuration
    
    .PARAMETER Gateway
    Gateway address for static configuration
    
    .PARAMETER DNSServers
    Array of DNS servers for static configuration
    
    .EXAMPLE
    Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname "veeam-server" -UseDHCP
    
    .EXAMPLE
    Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname "veeam-server" -StaticIP "192.168.1.100" -Subnet "255.255.255.0" -Gateway "192.168.1.1" -DNSServers @("8.8.8.8", "8.8.4.4")
    #>
    
    [CmdletBinding(DefaultParameterSetName = 'DHCP')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "File path $_ does not exist"
            }
            return $true
        })]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$')]
        [ValidateLength(1, 63)]
        [string]$Hostname,
        
        [Parameter(ParameterSetName = 'DHCP')]
        [switch]$UseDHCP,
        
        [Parameter(ParameterSetName = 'Static', Mandatory = $true)]
        [ValidateScript({
            if ($_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
                return $true
            }
            throw "Invalid IP address format: $_"
        })]
        [string]$StaticIP,
        
        [Parameter(ParameterSetName = 'Static', Mandatory = $true)]
        [ValidateScript({
            if ($_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
                return $true
            }
            throw "Invalid subnet mask format: $_"
        })]
        [string]$Subnet,
        
        [Parameter(ParameterSetName = 'Static', Mandatory = $true)]
        [ValidateScript({
            if ($_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
                return $true
            }
            throw "Invalid gateway address format: $_"
        })]
        [string]$Gateway,
        
        [Parameter(ParameterSetName = 'Static')]
        [ValidateScript({
            foreach ($dns in $_) {
                if ($dns -notmatch '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
                    throw "Invalid DNS server format: $dns"
                }
            }
            return $true
        })]
        [string[]]$DNSServers = @("8.8.8.8", "8.8.4.4")
    )
    
    try {
        Write-Log "Configuring network settings in kickstart file" 'Info'
        
        # Build network configuration line based on parameters
        if ($UseDHCP -or $PSCmdlet.ParameterSetName -eq 'DHCP') {
            $networkLine = "network --bootproto=dhcp --nodns --hostname=$Hostname"
            Write-Log "Configuring DHCP network with hostname: $Hostname" 'Info'
        }
        else {
            # Join DNS servers with commas for static configuration
            $DNSList = $DNSServers -join ","
            $networkLine = "network --bootproto=static --ip=$StaticIP --netmask=$Subnet --gateway=$Gateway --nameserver=$DNSList --hostname=$Hostname"
            Write-Log "Configuring static IP: $StaticIP with hostname: $Hostname" 'Info'
        }
        
        # Find and replace existing network configuration or add new one
        $content = Get-Content $FilePath
        $networkLineFound = $false
        
        for ($i = 0; $i -lt $content.Count; $i++) {
            if ($content[$i] -match '^network\s+') {
                $content[$i] = $networkLine
                $networkLineFound = $true
                Write-Log "Replaced existing network configuration" 'Info'
                break
            }
        }
        
        # If no existing network line found, add it after timezone configuration
        if (-not $networkLineFound) {
            $timezoneIndex = -1
            for ($i = 0; $i -lt $content.Count; $i++) {
                if ($content[$i] -match '^timezone\s+') {
                    $timezoneIndex = $i
                    break
                }
            }
            
            if ($timezoneIndex -ge 0) {
                $newContent = $content[0..$timezoneIndex] + $networkLine + $content[($timezoneIndex + 1)..($content.Count - 1)]
                $content = $newContent
                Write-Log "Added network configuration after timezone setting" 'Info'
            }
            else {
                # Fallback: add after keyboard configuration
                Insert-AfterLine -FilePath $FilePath -TargetLine "keyboard --xlayouts=" -LinesToInsert @($networkLine)
                Write-Log "Added network configuration after keyboard setting" 'Info'
                return
            }
        }
        
        # Write the modified content back to file
        Set-Content $FilePath $content
        Write-Log "Network configuration successfully applied to $FilePath" 'Info'
        
    }
    catch {
        Write-Log "Failed to configure network settings: $($_.Exception.Message)" 'Error'
        throw "Network configuration failed: $($_.Exception.Message)"
    }
}

#endregion

#region Main Script

try {
    #region Validate Inputs
    Validate-File -Path $LocalISO
    
    # Validate network configuration parameters
    if (-not $UseDHCP) {
        if ([string]::IsNullOrWhiteSpace($StaticIP) -or 
            [string]::IsNullOrWhiteSpace($Subnet) -or 
            [string]::IsNullOrWhiteSpace($Gateway)) {
            throw "Static IP configuration requires StaticIP, Subnet, and Gateway parameters"
        }
    }
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

    #region Edit vbr-ks.cfg using dedicated functions
    # Set Keyboard layout
    Set-KeyboardLayout -FilePath "vbr-ks.cfg" -Layout $KeyboardLayout
    
    # Set Timezone
    Set-Timezone -FilePath "vbr-ks.cfg" -TimezoneValue $Timezone
    
    # Set Network Configuration
    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -UseDHCP
    }
    else {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers
    }
    
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
    $CustomVCSPBlock = @(
        "# Connect to Service Provider with Mgmt Agent",
        "pwsh -Command '",
        "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
        "Add-VBRCloudProviderCredentials -Name '$VCSPLogin' -Password '$VCSPPassword'",
        "`$credentials = Get-VBRCloudProviderCredentials -Name '$VCSPLogin'",
        "Add-VBRCloudProvider -Address '$VCSPConnection' -Credentials `$credentials -InstallManagementAgent",
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
        "if [ -d /mnt/install/repo/node_exporter ]; then",
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

    if ($VCSPConnection) {
        Write-Log "Adding service provider to config file" 'Info'
        Insert-AfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -LinesToInsert $CustomVCSPBlock
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


