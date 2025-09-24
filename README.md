# Veeam Appliance ISO Automation Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2BWSL-lightgrey.svg)](https://docs.microsoft.com/en-us/windows/wsl/)
[![Veeam](https://img.shields.io/badge/Veeam-v13.0-00B336.svg)](https://www.veeam.com/)

> 🚀 **Enterprise-grade PowerShell automation tool for customizing Veeam Software Appliance ISO files.**

## Overview

This advanced PowerShell script automates the customization of Veeam Software Appliance ISO files, enabling fully automated, unattended appliance deployments with enterprise-grade, reusable configurations. It supports JSON configuration loading, out-of-place ISO modification, path-safe working in the current directory, advanced logging, and optional backup creation. Network, security, and monitoring details can be configured to fit enterprise environments.

---

## What's New (v2.0)

- JSON configuration support for all parameters
- Out-of-place ISO customization by default
- Optional backup creation for in-place editing
- Improved script logging and in VSA logging
- Legacy and command-line overrides still supported

---

## Features

- Load configuration from JSON for reproducible deployments
- Modify ISO files (create custom copies or modify in place)
- Automated GRUB and Kickstart configuration injection
- DHCP and static IP support, validated in script
- Regional keyboard & timezone settings
- Secure password and MFA configuration for Veeam accounts
- Prometheus node_exporter optional deployment
- Service Provider (VCSP) integration for v13.0.1+
- VBR tunning exemple such as Syslog server addition
- Enterprise-level logging and error handling

---

## Prerequisites

### System Requirements
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher
- **WSL**: Windows Subsystem for Linux (Ubuntu/Debian recommended)
- **Memory**: Minimum 4GB RAM (8GB recommended for large ISOs)
- **Storage**: At least 14GB free space for ISO manipulation

### Software Dependencies
**Software dependencies:**
- `xorriso` installed in WSL
    `
    sudo apt-get update
    sudo apt-get install xorriso
    `
- For RHEL/CentOS/Rocky:
    `
    sudo yum install xorriso
    `

**PowerShell configuration:**
- Run with an appropriate execution policy
- Confirm WSL is accessible:
    `
    wsl --version
    `

---

## Quick Start

## Quick Start

### Using JSON Configuration (Recommended)

1. Create a JSON configuration file like the example below or download it from the repo :

    ```
    {
      "SourceISO": "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso",
      "OutputISO": "",
      "InPlace": false,
      "CreateBackup": true,
      "CleanupCFGFiles": true,
      "GrubTimeout": 15,
      "KeyboardLayout": "us",
      "Timezone": "America/New_York",
      "Hostname": "veeam-backup-prod",
      "UseDHCP": false,
      "StaticIP": "192.168.1.166",
      "Subnet": "255.255.255.0",
      "Gateway": "192.168.1.1",
      "DNSServers": ["192.168.1.64", "8.8.4.4", "8.8.8.8"],
      "VeeamAdminPassword": "123q123Q123!123",
      "VeeamAdminMfaSecretKey": "JBSWY3DPEHPK3PXP",
      "VeeamAdminIsMfaEnabled": "true",
      "NodeExporter": true,
      "LicenseVBRTune": true,
      "VCSPConnection": false
    }
    ```

2. Place the script, ISO, and JSON in the same directory.

3. Run:
    `
    .\autodeployppxity.ps1 -ConfigFile "production-config.json"
    `

### Command Line Overrides

Any parameter specified on the command line will override the value in JSON.

    `
    .\autodeployppxity.ps1 -ConfigFile "base-config.json" -Hostname "custom-host" -OutputISO "custom-output.iso"
    `

### Legacy Usage (all parameters on command line)

    `
    .\autodeployppxity.ps1 `
        -SourceISO "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" `
        -GrubTimeout 45 `
        -KeyboardLayout "us" `
        -Timezone "America/New_York" `
        -Hostname "veeam-backup-prod01" `
        -UseDHCP:$false `
        -StaticIP "10.50.100.150" `
        -Subnet "255.255.255.0" `
        -Gateway "10.50.100.1" `
        -DNSServers @("10.50.1.10", "10.50.1.11", "8.8.8.8") `
        -VeeamAdminPassword "P@ssw0rd2024!123" `
        -NodeExporter $true `
        -LicenseVBRTune $true `
        -VCSPConnection $true
    `

---

## Configuration Parameters

### Core Parameters

| Parameter | Type   | Description                      | Default                                   | Required     |
|-----------|--------|----------------------------------|-------------------------------------------|-------------|
| ConfigFile    | String | Path to JSON file                 | ""                                        | No          |
| SourceISO     | String | Source ISO filename (required)    | VeeamSoftwareAppliance_13.0.0.4967_20250822.iso | Yes         |
| OutputISO     | String | Customized ISO filename           | auto (adds _customized)                   | No          |
| InPlace       | Bool   | Modify original ISO directly      | false                                     | No          |
| CreateBackup  | Bool   | Create backup for InPlace changes | true                                      | No          |
| CleanupCFGFiles| Bool  | Clean temp config files           | true                                      | No          |
| GrubTimeout   | Int    | GRUB timeout (seconds)            | 10                                        | No          |
| KeyboardLayout| String | Keyboard code                     | fr                                        | No          |
| Timezone      | String | System timezone                   | Europe/Paris                              | No          |
| Hostname      | String | Hostname for appliance            | veeam-server                              | No          |

### Network Parameters

| Parameter   | Type     | Description                     | Default         |
|-------------|----------|---------------------------------|-----------------|
| UseDHCP     | Bool     | Use DHCP for network config     | false           |
| StaticIP    | String   | Static IP address               | 192.168.1.166   |
| Subnet      | String   | Subnet mask                     | 255.255.255.0   |
| Gateway     | String   | Gateway IP                      | 192.168.1.1     |
| DNSServers  | Array    | DNS servers (comma-separated)   | ["192.168.1.64", "8.8.4.4"] |

### Veeam Security Appliance Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| VeeamAdminPassword | String | Password for Veeam admin account. Must meet complexity requirements (15+ chars with mixed case, numbers, symbols) | `123q123Q123!123` |
| VeeamAdminMfaSecretKey | String | Base32-encoded MFA secret key for admin account TOTP authentication (16-32 characters) | `JBSWY3DPEHPK3PXP` |
| VeeamAdminIsMfaEnabled | String | Enable/disable multi-factor authentication for admin account ("true"/"false") | `"true"` |
| VeeamSoPassword | String | Password for Veeam Security Officer (SO) account. Must meet same complexity requirements as admin | `123w123W123!123` |
| VeeamSoMfaSecretKey | String | Base32-encoded MFA secret key for SO account TOTP authentication | `JBSWY3DPEHPK3PXP` |
| VeeamSoIsMfaEnabled | String | Enable/disable multi-factor authentication for SO account ("true"/"false") | `"true"` |
| VeeamSoRecoveryToken | String | GUID-format recovery token for SO account emergency access and recovery scenarios | `eb9fcbf4-2be6-e94d-4203-dded67c5a450` |
| VeeamSoIsEnabled | String | Enable/disable the Security Officer account entirely ("true"/"false") | `"true"` |
| NtpServer | String | Network Time Protocol server for time synchronization (FQDN or IP address) | `time.nist.gov` |
| NtpRunSync | String | Enable automatic time synchronization on boot ("true"/"false") | `"false"` |

### Optional Features

| Parameter           | Type    | Description                      | Default                                   |
|---------------------|---------|----------------------------------|-------------------------------------------|
| NodeExporter        | Bool    | Deploy Prometheus node_exporter  | false                                     |
| LicenseVBRTune      | Bool    | Auto-install Veeam license       | false                                     |
| LicenseFile         | String  | License filename                 | Veeam-100instances-entplus-monitoring-nfr.lic |
| SyslogServer        | String  | Syslog server IP                 | 172.17.53.28                              |
| VCSPConnection      | Bool    | Connect to VCSP                  | false                                     |
| VCSPUrl             | String  | VCSP server URL                  | ""                                        |
| VCSPLogin           | String  | VCSP login                       | ""                                        |
| VCSPPassword        | String  | VCSP password                    | ""                                        |

---

### Security Notes

- **Password Requirements**: Both admin and SO passwords should be at least 15 characters long with uppercase, lowercase, numbers, and special characters for enterprise security
- **MFA Secret Keys**: Must be valid Base32-encoded strings (A-Z, 2-7, no padding) for compatibility with TOTP authenticators like Google Authenticator or Microsoft Authenticator
- **Recovery Tokens**: Should follow standard GUID format (8-4-4-4-12 hexadecimal digits) for account recovery scenarios
- **Security Officer Account**: The SO account provides service-level access separate from the administrative account for improved security separation
- **NTP Configuration**: Proper time synchronization is critical for Veeam operations, especially in distributed environments

### Network Security
- **IP Validation**: Comprehensive IPv4 address format validation using regex patterns
- **DNS Configuration**: Support for multiple DNS servers with individual validation
- **Static Configuration**: Complete network parameter validation for enterprise deployments

### File Security
- **Transcript Logging**: Comprehensive logging with timestamp and severity levels

---

## Optional feature

### Node_Exporter
The script automatically creates systemd services for:
- **Node Exporter**: Prometheus monitoring with firewall configuration 9100
- **Veeam Initialization**: One-shot service for post-boot configuration

### VBR Tunning
- **License Installation**: Automated license deployment and activation
- **Run custom script** : Exemple PS script run Add Syslog Server

### VCSP Connection
- **VCSP Connection**: Veeam Service service provider integration with credential management

---

## Troubleshooting

- Ensure WSL is installed and available (`wsl --list --verbose`)
- Install `xorriso` in WSL (`sudo apt-get install xorriso`)
- Confirm ISO file is located in the same directory as the script
- Use correct JSON structure; command parameters override JSON if specified
- Check log file `ISO_Customization.log` for timestamped error messages

#### Network Configuration Validation
- **IP Format**: Ensure IP addresses match IPv4 format (xxx.xxx.xxx.xxx)
- **Subnet Masks**: Use standard subnet mask formats
- **DNS Arrays**: Provide DNS servers as PowerShell arrays: `@("8.8.8.8", "8.8.4.4")`

#### ISO File Access
- **File Locks**: Ensure ISO files aren't mounted or locked by other applications
- **Permissions**: Verify read/write access to ISO file location
- **Path Format**: Use full paths for ISO files in different directories

---

## Contributing

1. Fork this repo and create a pull request to suggest improvements.
2. Use [GitHub Issues](https://github.com/PleXi00/autodeploy/issues) for bugs or feature requests.

---

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


## Author & Stats

**Author**: Baptiste TELLIER  
**Version**: 2.0  
**Creation**: September 24, 2025

![GitHub stars](https://img.shields.io/github/stars/PleXi00/autodeploy)
![GitHub forks](https://img.shields.io/github/forks/PleXi00/autodeploy)
![GitHub issues](https://img.shields.io/github/issues/PleXi00/autodeploy)
![GitHub last commit](https://img.shields.io/github/last-commit/PleXi00/autodeploy)

---

_Made with ❤️ for the Veeam community by Baptiste TELLIER and the help of AI_

---

*If this project helps you automate Veeam deployments, please give it a star on GitHub!*
