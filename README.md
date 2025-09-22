# Veeam Appliance ISO Automation Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2BWSL-lightgrey.svg)](https://docs.microsoft.com/en-us/windows/wsl/)
[![Veeam](https://img.shields.io/badge/Veeam-v13.0-00B336.svg)](https://www.veeam.com/)

> 🚀 **Enterprise-grade PowerShell automation tool for customizing Veeam Backup & Replication appliance ISO files with comprehensive Rocky Linux deployment automation.**

## Overview

This advanced PowerShell script provides end-to-end automation for customizing Veeam Software Appliance ISO files, enabling fully automated, unattended installations with enterprise-grade configurations. The tool extracts and modifies critical configuration files including GRUB bootloader settings and Kickstart configuration files, implementing comprehensive customizations for network configuration, regional settings, security parameters, and optional component deployment.

### Why Use This Tool?

- ✅ **Zero-Touch Deployment**: Fully automated Veeam appliance installations with pre-configured settings
- ✅ **Network Flexibility**: Comprehensive support for both DHCP and static IP configurations with validation
- ✅ **Enterprise Security**: Multi-factor authentication, secure password management, and recovery tokens
- ✅ **Monitoring Ready**: Optional Prometheus node_exporter integration for enterprise monitoring
- ✅ **Service Provider Ready**: Automated VCSP connection and management agent deployment
- ✅ **In-Place Modification**: Direct ISO modification without creating new files

## Key Features

### 🔧 Core Functionality
- **In-Place ISO Modification**: Directly modifies source ISO files using WSL xorriso integration
- **GRUB Configuration**: Automated bootloader timeout, default boot selection, and installation parameters
- **Kickstart Automation**: Complete unattended Rocky Linux installation configuration

### 🌐 Network Configuration
- **DHCP Support**: Automatic network configuration with hostname assignment
- **Static IP Configuration**: Full static network setup with comprehensive IPv4 validation
- **Multi-DNS Support**: Configurable DNS server arrays with validation
- **Advanced Validation**: Regex-based IP address, subnet mask, and gateway validation

### 🌍 Regional & System Settings
- **Keyboard Layouts**: Multi-language keyboard layout support (US, FR, DE, UK, etc.)
- **Timezone Configuration**: Comprehensive timezone support with proper continent/city validation
- **NTP Integration**: Network time synchronization with configurable NTP servers
- **Hostname Management**: RFC-compliant hostname configuration with validation

### 🔐 Security & Authentication
- **Multi-Factor Authentication**: Base32 encoded MFA secret key generation and management
- **Dual Account Management**: Separate admin and service account configurations
- **Recovery Token System**: Automated GUID-based recovery token generation
- **Permission Management**: Secure file permissions (600) for sensitive configuration files

### 📊 Enterprise Monitoring & Management
- **Node Exporter Integration**: Optional Prometheus monitoring agent with systemd service setup
- **Firewall Configuration**: Automatic firewall rule creation for monitoring endpoints
- **Syslog Integration**: Centralized logging configuration with UDP syslog support
- **License Automation**: Automated Veeam license installation and activation

### ☁️ Service Provider Features
- **VCSP Integration**: Automated Veeam Cloud Service Provider connection (v13.0.1+)
- **Management Agent**: Automatic installation and configuration of VCSP management agents
- **Credential Management**: Secure credential handling and PowerShell module integration

### 🛠️ Advanced Automation
- **PowerShell Integration**: Embedded PowerShell commands for post-installation configuration
- **Systemd Service Creation**: Automated service creation for one-shot configuration tasks
- **Configuration File Templates**: Dynamic generation of configuration files with variable substitution

## Prerequisites

### System Requirements
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher
- **WSL**: Windows Subsystem for Linux (Ubuntu/Debian recommended)
- **Memory**: Minimum 4GB RAM (8GB recommended for large ISOs)
- **Storage**: At least 10GB free space for ISO manipulation

### Software Dependencies
Install xorriso in WSL (Ubuntu/Debian)

`sudo apt-get update
sudo apt-get install xorriso`

For RHEL/CentOS/Rocky Linux

`sudo yum install xorriso`

### PowerShell Configuration

Set appropriate execution policy

Verify WSL is accessible

`wsl --version`

## Quick Start

# Example 2 : Complete static IP configuration with all optional features enable

.\autodeployppxity.ps1 `
    -LocalISO "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" 
    -GrubTimeout 45 
    -KeyboardLayout "us" 
    -Timezone "America/New_York" 
    -Hostname "veeam-backup-prod01" 
    -UseDHCP:$false 
    -StaticIP "10.50.100.150" 
    -Subnet "255.255.255.0" 
    -Gateway "10.50.100.1" 
    -DNSServers @("10.50.1.10", "10.50.1.11", "8.8.8.8") 
    -VeeamAdminPassword "P@ssw0rd2024!" 
    -VeeamAdminMfaSecretKey "ABCDEFGH12345678IJKLMNOP" 
    -VeeamAdminIsMfaEnabled "true" 
    -VeeamSoPassword "S3cur3P@ss!" 
    -VeeamSoMfaSecretKey "ZYXWVUTS87654321QPONMLKJ" 
    -VeeamSoIsMfaEnabled "true" 
    -VeeamSoRecoveryToken "12345678-90ab-cdef-1234-567890abcdef" 
    -VeeamSoIsEnabled "true" 
    -NtpServer "pool.ntp.org" 
    -NtpRunSync "true" 
    -NodeExporter $true 
    -LicenseVBRTune $true 
    -LicenseFile "Enterprise-Plus-License.lic" 
    -SyslogServer "10.50.1.20" 
    -VCSPConnection $true 
    -VCSPUrl "https://vcsp.company.com" 
    -VCSPLogin "serviceaccount" 
    -VCSPPassword "VCSPServiceP@ss!" `

# Example 2 : Simple DHCP configuration for lab environment with all optional features disable

.\autodeployppxity.ps1 `
    -LocalISO "VeeamAppliance-Lab.iso" 
    -GrubTimeout 10 
    -KeyboardLayout "fr" 
    -Timezone "Europe/Paris" 
    -Hostname "veeam-lab-test" 
    -UseDHCP:$true 
    -VeeamAdminPassword "LabP@ss123" 
    -VeeamAdminIsMfaEnabled "false" 
    -VeeamSoPassword "SOLabP@ss123" 
    -VeeamSoIsMfaEnabled "false" 
    -VeeamSoIsEnabled "false" 
    -NodeExporter $false 
    -LicenseVBRTune $false 
    -VCSPConnection $false ` 

# Example 3: Enterprise deployment with German localization

.\autodeployppxity.ps1 `
    -LocalISO "C:\ISOs\VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" 
    -GrubTimeout 30 
    -KeyboardLayout "de" 
    -Timezone "Europe/Berlin" 
    -Hostname "veeam-enterprise-de" 
    -UseDHCP:$false 
    -StaticIP "192.168.10.200" 
    -Subnet "255.255.255.0" 
    -Gateway "192.168.10.1" 
    -DNSServers @("192.168.10.10", "192.168.10.11") 
    -VeeamAdminPassword "EnterprisePw2024!" 
    -VeeamAdminMfaSecretKey "ENTERPRISE1234567890ABCD" 
    -VeeamAdminIsMfaEnabled "true" 
    -VeeamSoPassword "SOEnterprisePw!" 
    -VeeamSoMfaSecretKey "SOENTRPRS9876543210ZYXW" 
    -VeeamSoIsMfaEnabled "true" 
    -VeeamSoRecoveryToken "aaaabbbb-cccc-dddd-eeee-ffffgggghhh" 
    -VeeamSoIsEnabled "true" 
    -NtpServer "de.pool.ntp.org" 
    -NtpRunSync "true" 
    -NodeExporter $false 
    -LicenseVBRTune $true 
    -LicenseFile "Veeam-Enterprise-Germany.lic" 
    -SyslogServer "192.168.10.50" 
    -VCSPConnection $false `

## Configuration Parameters

### Core System Parameters
| Parameter | Type | Description | Default | Required |
|-----------|------|-------------|---------|----------|
| `LocalISO` | String | Path to source Veeam ISO file | `VeeamSoftwareAppliance_13.0.0.4967_20250822.iso` | ✅ |
| `GrubTimeout` | Integer | GRUB timeout in seconds | `30` | ❌ |
| `KeyboardLayout` | String | Keyboard layout code | `fr` | ❌ |
| `Timezone` | String | System timezone | `Europe/Paris` | ❌ |
| `Hostname` | String | System hostname | `veeam-server` | ❌ |

### Network Configuration
| Parameter | Type | Description | Default | Notes |
|-----------|------|-------------|---------|-------|
| `UseDHCP` | Switch | Enable DHCP configuration | `$false` | When true, static params ignored |
| `StaticIP` | String | Static IP address | `192.168.1.166` | Required when DHCP disabled |
| `Subnet` | String | Subnet mask | `255.255.255.0` | Required when DHCP disabled |
| `Gateway` | String | Gateway IP address | `192.168.1.1` | Required when DHCP disabled |
| `DNSServers` | Array | DNS server addresses | `@("192.168.1.64", "8.8.4.4")` | Optional for static config |

### Veeam Security Configuration
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `VeeamAdminPassword` | String | Admin account password | `123q123Q123!123` |
| `VeeamAdminMfaSecretKey` | String | Admin MFA secret (Base32) | `JBSWY3DPEHPK3PXP` |
| `VeeamAdminIsMfaEnabled` | String | Enable admin MFA | `false` |
| `VeeamSoPassword` | String | Service account password | `123w123W123!123` |
| `VeeamSoMfaSecretKey` | String | Service MFA secret (Base32) | `JBSWY3DPEHPK3PXP` |
| `VeeamSoIsMfaEnabled` | String | Enable service MFA | `true` |
| `VeeamSoRecoveryToken` | String | Recovery token (GUID) | `aaaabbbb-cccc-dddd-eeee-ffffgggghhh` |
| `VeeamSoIsEnabled` | String | Enable service account | `true` |

### Optional Features
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `NodeExporter` | Boolean | Deploy Prometheus monitoring | `$true` |
| `LicenseVBRTune` | Boolean | Auto-install license | `$true` |
| `LicenseFile` | String | License filename | `Veeam-100instances-entplus-monitoring-nfr.lic` |
| `SyslogServer` | String | Syslog server IP | `172.17.53.28` |
| `VCSPConnection` | Boolean | Connect to VCSP | `$false` |
| `VCSPUrl` | String | VCSP server URL | `192.168.1.202` |
| `VCSPLogin` | String | VCSP login | `v13` |
| `VCSPPassword` | String | VCSP password | `Azerty123!` |

## Security Considerations

### Password Security
- **Complexity Requirements**: Use passwords with minimum 15 characters including uppercase, lowercase, numbers, and special characters
- **MFA Integration**: Base32 encoded secret keys (16-32 characters) for TOTP authentication
- **Recovery Tokens**: GUID format tokens for account recovery scenarios

### Network Security
- **IP Validation**: Comprehensive IPv4 address format validation using regex patterns
- **DNS Configuration**: Support for multiple DNS servers with individual validation
- **Static Configuration**: Complete network parameter validation for enterprise deployments

### File Security
- **Transcript Logging**: Comprehensive logging with timestamp and severity levels

## Advanced Features

### Automated Service Creation
The script automatically creates systemd services for:
- **Node Exporter**: Prometheus monitoring with firewall configuration
- **Veeam Initialization**: One-shot service for post-boot configuration
- **Firewall Management**: Automatic port opening for monitoring services (TCP/9100)

### PowerShell Integration
- **Module Loading**: Automatic Veeam PowerShell module import
- **License Installation**: Automated license deployment and activation  
- **VCSP Connection**: Cloud service provider integration with credential management

### Configuration Management
- **Template Generation**: Dynamic configuration file creation with variable substitution
- **Init Wizard Disable**: Automatic UI initialization bypass for unattended deployment
- **Post-Installation Scripts**: Embedded bash and PowerShell scripts for system configuration

## Troubleshooting

### Common Issues

#### WSL/xorriso Configuration
Verify WSL installation

`wsl --list --verbose`

Install xorriso if missing

`wsl sudo apt-get update
wsl sudo apt-get install xorriso`

Test xorriso functionality

`wsl xorriso --version`

#### Network Configuration Validation
- **IP Format**: Ensure IP addresses match IPv4 format (xxx.xxx.xxx.xxx)
- **Subnet Masks**: Use standard subnet mask formats
- **DNS Arrays**: Provide DNS servers as PowerShell arrays: `@("8.8.8.8", "8.8.4.4")`

#### ISO File Access
- **File Locks**: Ensure ISO files aren't mounted or locked by other applications
- **Permissions**: Verify read/write access to ISO file location
- **Path Format**: Use full paths for ISO files in different directories

### Debug and Logging
- **Verbose Logging**: All operations include timestamped logging with severity levels
- **Error Handling**: Comprehensive try-catch blocks with detailed error messages
- **Command Validation**: Safe external command execution with success/failure tracking

## Contributing

We welcome contributions from the community!

### Reporting Issues
Please use the [GitHub Issues](https://github.com/PleXi00/autodeploy/issues) page to report bugs or request features.

## TO DO

- [x] Parameters to change Hostname ✅ **Completed**
- [x] Function to change IP / DHCP ✅ **Completed**
- [ ] Move away from WSL and use oscdimg.exe
- [ ] Support for multiple ISO formats (JEoS & VSA)
- [ ] Automated backup creation before modification

## Support

### Documentation Resources
- [Veeam Backup & Replication Documentation](https://helpcenter.veeam.com/docs/backup/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Rocky Linux Kickstart Guide](https://docs.rockylinux.org/guides/automation/kickstart/)
- [Node Exporter Releases](https://github.com/prometheus/node_exporter/releases)

### Community Support
- [GitHub Issues](https://github.com/PleXi00/autodeploy/issues) - Bug reports and feature requests
- [GitHub Discussions](https://github.com/PleXi00/autodeploy/discussions) - Community discussions

### Author Information
- **Author**: Baptiste TELLIER
- **Version**: 2.0
- **Creation Date**: September 22, 2025
- **Prerequisites**: PowerShell 5.1+, WSL with xorriso

---

## Project Stats

![GitHub stars](https://img.shields.io/github/stars/PleXi00/autodeploy)
![GitHub forks](https://img.shields.io/github/forks/PleXi00/autodeploy)
![GitHub issues](https://img.shields.io/github/issues/PleXi00/autodeploy)
![GitHub last commit](https://img.shields.io/github/last-commit/PleXi00/autodeploy)

**Made with ❤️ for the Veeam community by Baptiste TELLIER**

---

*⭐ If this project helped automate your Veeam deployments, please consider giving it a star on GitHub!*

---

Readme made with the help of AI
