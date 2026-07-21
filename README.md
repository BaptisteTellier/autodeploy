# Veeam Software Appliance ISO Automation Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](#prerequisites)
[![Veeam](https://img.shields.io/badge/Veeam-v13.1-00B336.svg)](https://www.veeam.com/)

> 🚀 **Enterprise-grade PowerShell automation tool for customizing Veeam Software Appliance ISO files.**

## Overview

This advanced PowerShell script automates the customization of Veeam Software Appliance ISO files, enabling fully automated, unattended appliance deployments with enterprise-grade, reusable configurations. It supports JSON configuration loading, out-of-place ISO modification, advanced logging, and optional IS backup creation. Network, security, and monitoring details can be configured to fit enterprise environments.

- Tested on build 13.0.0.4967_20250822 & 13.0.1.180_20251101 & 13.0.1.2067_20260310 & 13.1.x (VSA)
- For Auto-Deployment PowerShell exemple : [Powershell Folder](https://github.com/BaptisteTellier/autodeploy/tree/main/powershell)
- For Packer remote kickstart exemple : [Packer Folder](https://github.com/BaptisteTellier/autodeploy/tree/main/packer)
- Youtube video - French audi with Eng Sub : [Part 1](https://www.youtube.com/watch?v=Ri877QyX6i8) [Part 2](https://www.youtube.com/watch?v=fIvcHSPhUUM) [Part 3](https://www.youtube.com/watch?v=MwQcrLufKDU) [Part 4](https://www.youtube.com/watch?v=O56TzfvDNT0) [Part 5](https://www.youtube.com/watch?v=-LA9wKzujyA)
---

## What's New (v2.8)
- **Cross-platform (macOS / Linux natif)**: the script now runs natively on macOS and Linux (`xorriso` is called directly); Windows still uses WSL. Thanks @k00laidIT (PR #6).
- **Boot record fix**: ISOs are written with `-boot_image any replay` (instead of `keep`), preserving the isohybrid MBR + boot-info-table so modified ISOs also boot from a `dd`'d USB stick (previously: virtual media only).
- **Support for VSA 13.1**: 4 new JSON keys for the Host Manager init config (VSA workflow only). All default-off so v2.7 JSONs keep working as-is.
  - `ExternalManagersInstallationEnabled` (bool, default `false`) -> rendered as `externalManagersInstallation.enabled=true|false` in `/etc/veeam/vbr_init.cfg`
  - `ExternalManagersInstallationTimeout` (int seconds, default `3600` = 60 min) -> rendered as `externalManagersInstallation.timeout=<sec>`
  - `HighAvailabilityEnabled` (bool, default `false`) -> rendered as `highAvailability.enabled=true|false`
  - `HighAvailabilityTimeout` (int seconds, default `3600` = 60 min) -> rendered as `highAvailability.timeout=<sec>`
- **NodeExporter refactor (BREAKING, VSA 13.1+ required)**: `node_exporter` is now built-in to VSA 13.1 via Veeam Backup & Replication. The script no longer copies an `offline_repo/`, no longer installs the RPM, no longer creates a systemd unit, and no longer opens firewall port 9100. Activation is now a one-liner: `Set-VBRNodeExporterOptions -EnableMetricsSharing` (via the existing `NodeExporter` JSON key, default `false`). Verification endpoint changes from `http://<VSA>:9100/metrics` to `http://<VSA>/metrics` (port 80, or 443 with TLS).
- **New JSON key `NodeExporterTLSEnabled`** (bool, default `false`). When `true`, runs `Set-VBRNodeExporterOptions -EnableMetricsSharing -EnableTLS` so the metrics endpoint switches from HTTP to HTTPS (`https://<VSA>/metrics`). Only effective when `NodeExporter=true`.
- **NodeExporter is now VSA-only (BREAKING)**: `Set-VBRNodeExporterOptions` is a VBR cmdlet that does not exist on VIA/VIAiscsi/VIAHR appliances. Setting `NodeExporter=true` on those workflows now throws early (same pattern as `VCSPConnection`/`LicenseVBRTune`/`RestoreConfig`). VIA appliance node_exporter configuration will be piloted by the VSA in a future release.
- **applianceRole.role auto-injection for VIA appliances**: VSA 13.1 replaces the GRUB-based role selection with a declarative line in `/etc/veeam/vbr_init.cfg`. The script now auto-emits this line based on `ApplianceType`: `VIA` -> `applianceRole.role=vbproxy`, `VIAiscsi` -> `applianceRole.role=vbproxy` + `applianceRole.iSCSI=true`, `VIAHR` -> `applianceRole.role=veeam-lhr`. VSA omits the line (it has a dedicated ISO).
- **`ApplianceType=VIAVMware` renamed to `VIAiscsi`**: the iSCSI / NVMe-TCP proxy workflow is now identified as `VIAiscsi` in JSON. Update your JSON files accordingly. The new `viascsi.json` example file is provided.
- **New JSON key `VIASingleDisk` (VIA-only)**: bool, default `false`. When `true`, the script selects the "Single-Disk Deployment" GRUB menu entry as the boot default instead of the standard "Standard (Multi-Disk) Deployment" label. The Single-Disk entry installs by wiping all devices (kernel passes `inst.vsingledisk`). Applies to `VIA`, `VIAiscsi`, `VIAHR` — throws on `VSA` (which has its own ISO without a Single-Disk entry). The GRUB regex that injects `inst.assumeyes` was broadened so both the Standard and Single-Disk kernel lines get the non-interactive flag.
- **GRUB default labels (VSA 13.1)**: labels updated for the 13.1 release ISOs (no more `[TBD]` placeholders). VSA boots `Veeam Backup & Replication>Install …`; the three VIA workflows boot `Standard (Multi-Disk) Deployment>Install …` (or `Single-Disk Deployment>Install …` when `VIASingleDisk=true`).
- **Publish to main pending VSA 13.1 release**: v2.8 will land on `main` once VSA 13.1 is officially released. Until then, all v2.8 work stays on the `dev` branch.

## What's New (v2.7)
- **JSON-only mode (BREAKING)**: `-ConfigFile` is now the only CLI argument; all other settings MUST come from the JSON file. CLI overrides are no longer supported.
- Built-in defaults are applied first; any key present in the JSON overrides them. Keys absent from the JSON keep their default value.
- Unknown JSON keys are logged as warnings (typo detection).
- `NtpServer` JSON key now accepts an array of servers (e.g. `["ntp1.example.local", "ntp2.example.local"]`) rendered as `ntp.servers=ntp1;ntp2` in the kickstart. Single-string form remains supported (backward-compatible).

## What's New older are moved to archive folder



---

## Features

- Load configuration from JSON for reproducible deployments
- Cross-platform: Windows (WSL), macOS, Linux
- APPLIANCE TYPE SELECTION: Support for VSA, VIA, VIAiscsi, and VIAHR appliances with dedicated deployment workflows
- Modify ISO files (create custom copies or modify in place)
- Automated GRUB and Kickstart configuration injection
- DHCP and static IP support, validated in script
- Regional keyboard & timezone settings
- Secure password and MFA configuration for Veeam accounts
- (optional) node_exporter enablement
- (optional) Service Provider (VCSP) integration for v13.0.1+
- (optional) VBR licensing import and VBR tunning exemple such as Syslog server addition
- (optional) Support for Automatique unattended configuration restore
- (optional) Debug mode (enable root and ssh)
- Enterprise-level logging and error handling

---

## Disclaimer : Before you edit your ISO
Installing additional Linux packages, third-party applications, or changing OS settings (other than those that can be controlled via the Veeam Host Management Console) on the Veeam Appliances is not supported. Veeam Customer Support cannot provide technical support for appliances with unsupported modifications due to their unpredictable impact on the appliance's security, stability, and performance.

https://www.veeam.com/kb4772

---

## Prerequisites

### System Requirements
- **Operating System**: one of
    - Windows 10/11 or Windows Server 2016+, with WSL (Ubuntu/Debian recommended)
    - macOS
    - Linux (Ubuntu/Debian, or RHEL/Rocky/Alma)
- **PowerShell**: Version 7 or higher
- **Memory**: Minimum 4GB RAM (8GB recommended for large ISOs)
- **Storage**: At least 14GB free space for ISO manipulation

### Software Dependencies

`xorriso` is the only external dependency. On Windows it runs inside WSL; on macOS and Linux
the script calls it directly.

| Platform | Install command |
|---|---|
| Windows (in WSL) | `wsl sudo apt-get update && wsl sudo apt-get install -y xorriso` |
| macOS | `brew update && brew install xorriso` |
| Ubuntu/Debian | `sudo apt-get update && sudo apt-get install -y xorriso` |
| RHEL/Rocky/Alma | `sudo dnf install -y xorriso` |

**PowerShell configuration:**
- Run with an appropriate execution policy
- Confirm your setup:
    ```
    # Windows: check WSL is accessible
    wsl --version

    # macOS / Linux: check xorriso is on your PATH
    xorriso -version
    ```

### Optionnal Dependencies
**VBR tunning : License file**
- `license` folder at / of the folder where you run the script
- `xxx.lic` file inside the folder and `xxx.lic` for the `LicenseFile` parameter
- `LicenseVBRTune` set to `$true`

**node_exporter**
- No extra files required -- node_exporter ships with VSA 13.1+ and is enabled via VBR cmdlet.
- VSA-only feature; setting `NodeExporter=true` on VIA/VIAiscsi/VIAHR throws.

**Veeam Service Provider support**
- fill json parameters starting with VCSP

**Configuration Restore**
- download `conf` folder from repo with inside `unattended.xml`, `veeam_addsoconfpw.sh`, and your bco rename to `conftoresto.bco` (hard coded)
- Edit `unattended.xml` with your configuration password at BACKUP_PASSWORD. **It's the password for your configuration you set in VBR console.**
- Set JSON `RestoreConfig` to true and edit with your `ConfigPasswordSo`. **It's the password you set for "configuration backup" as Security Officer.**
- download `offline_repo` folder and place it at / of the folder where you run the script

---

## Quick Start

### Using JSON Configuration (Required)

> Since v2.7, the JSON config file is **mandatory**. `-ConfigFile` is the only CLI argument the script accepts; every other setting MUST be defined in the JSON.

1. Create a JSON configuration file like the example below or download it from the repo :

    ```
    {
    "SourceISO": "VeeamSoftwareAppliance_13.0.1.180_20251101.iso",
    "OutputISO": "",
    "ApplianceType": "VSA",
    "InPlace": false,
    "CreateBackup": true,
    "CleanupCFGFiles": true,
    "CFGOnly": false,
    "GrubTimeout": 0,
    "KeyboardLayout": "fr",
    "Timezone": "Europe/Paris",
    "Hostname": "veeam-backup",
    "UseDHCP": false,
    "StaticIP": "192.168.1.166",
    "Subnet": "255.255.255.0",
    "Gateway": "192.168.1.1",
    "DNSServers": ["192.168.1.64", "8.8.8.4", "8.8.8.8"],
    "VeeamAdminPassword": "123q123Q123!123",
    "VeeamAdminMfaSecretKey": "JBSWY3DPEHPK3PXP",
    "VeeamAdminIsMfaEnabled": "true",
    "VeeamSoPassword": "123w123W123!123",
    "VeeamSoMfaSecretKey": "JBSWY3DPEHPK3PXP",
    "VeeamSoIsMfaEnabled": "true",
    "VeeamSoRecoveryToken": "12345678-90ab-cdef-1234-567890abcdef",
    "VeeamSoIsEnabled": "true",
    "NtpServer": ["time.nist.gov", "0.fr.pool.ntp.org"],
    "NtpRunSync": "true",
    "ExternalManagersInstallationEnabled": false,
    "ExternalManagersInstallationTimeout": 3600,
    "HighAvailabilityEnabled": false,
    "HighAvailabilityTimeout": 3600,
    "NodeExporter": false,
    "NodeExporterTLSEnabled": false,
    "LicenseVBRTune": false,
    "LicenseFile": "Veeam-100instances-entplus-monitoring-nfr.lic",
    "SyslogServer": "",
    "VCSPConnection": false,
    "VCSPUrl": "",
    "VCSPLogin": "",
    "VCSPPassword": "",
    "RestoreConfig": false,
    "ConfigPasswordSo": "",
    "Debug": false
    }
    ```

2. Place the script, ISO, and JSON in the same directory.

3. Run:
    `
    .\autodeploy.ps1 -ConfigFile "production-config.json"
    `
4. See [Powershell Folder](https://github.com/BaptisteTellier/autodeploy/tree/main/powershell) for Auto-Deployment PowerShell Exemple :

- Create-ISO.ps1 - Generates multiple bootable ISO images for Veeam appliances ( VSA + VIA Proxy + VIA Hardened Repository )
- AutoProvisionning.ps1 - Add ISO to VMs, change boot order to DVD-ROM and starts Hyper-V VMs
- Install-VeeamInfra.ps1 - Configures Veeam infrastructure components (VIA Proxy + VIA Hardened Repository)

---

## Configuration Parameters

> All keys below are **JSON config keys** (since v2.7). The only CLI argument is `-ConfigFile <path-to-json>`. Any key omitted from the JSON keeps its built-in default.

### Core Parameters

| Parameter | Type   | Description                      | Default                                   | Required     |
|-----------|--------|----------------------------------|-------------------------------------------|-------------|
| `-ConfigFile` (CLI only) | String | Path to the JSON configuration file (the ONLY CLI argument) | _(none)_ | **Yes** |
| SourceISO     | String | Source ISO filename (required)    | VeeamSoftwareAppliance_13.0.0.4967_20250822.iso | Yes         |
| OutputISO     | String | Customized ISO filename           | auto (adds _customized)                   | No          |
| ApplianceType    | String | VSA, VIA, VIAiscsi, VIAHR | VSA                                       | No          |
| InPlace       | Bool   | Modify original ISO directly      | false                                     | No          |
| CreateBackup  | Bool   | Create backup for InPlace changes | true                                      | No          |
| CleanupCFGFiles| Bool  | Clean temp config files           | true                                      | No          |
| CFGOnly | Bool  | write cfg file and don't touch ISO (for cloudInit/packer)  | false                   | No          |
| GrubTimeout   | Int    | GRUB timeout (seconds)            | 10                                        | No          |
| KeyboardLayout| String | Keyboard code                     | fr                                        | No          |
| Timezone      | String | System timezone                   | Europe/Paris                              | No          |
| Hostname      | String | Hostname for appliance (15char max for Microsoft Domaine)  | veeam-server     | No          |

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
| NtpServer | String OR Array&lt;String&gt; | NTP server(s) for time synchronization (FQDN or IP). Single string for one server, array for multiple — e.g. `["ntp1.example.local","ntp2.example.local"]` | `["time.nist.gov"]` |
| NtpRunSync | String | Enable automatic time synchronization on boot ("true"/"false") - if sync fails customization fails | `"true"` |

### Optional Features

#### All appliances

| Parameter | Type   | Description                                              | Default |
|-----------|--------|----------------------------------------------------------|---------|
| Debug     | Bool   | Enable root SSH access during install. **Do not use in production.** | false |

#### VSA only

| Parameter                           | Type   | Description                                                                                                                                                                                       | Default                                          |
|-------------------------------------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| NodeExporter                        | Bool   | VSA 13.1+. Enables `node_exporter` metrics sharing via `Set-VBRNodeExporterOptions -EnableMetricsSharing`. Endpoint: `http://<VSA>/metrics` (port 80). Throws on VIA/VIAiscsi/VIAHR.            | false                                            |
| NodeExporterTLSEnabled              | Bool   | Enable TLS on the metrics endpoint (`https://<VSA>/metrics`). Only effective when `NodeExporter=true`.                                                                                            | false                                            |
| LicenseVBRTune                      | Bool   | Auto-install Veeam license.                                                                                                                                                                       | false                                            |
| LicenseFile                         | String | License filename (placed in the `license/` folder).                                                                                                                                               | Veeam-100instances-entplus-monitoring-nfr.lic    |
| SyslogServer                        | String | Syslog server IP.                                                                                                                                                                                 | ""                                               |
| VCSPConnection                      | Bool   | Connect to a VCSP and install the Management Agent. Requires `ExternalManagersInstallationEnabled=true` (auto-enforced).                                                                          | false                                            |
| VCSPUrl                             | String | VCSP server address.                                                                                                                                                                              | ""                                               |
| VCSPLogin                           | String | VCSP tenant login.                                                                                                                                                                                | ""                                               |
| VCSPPassword                        | String | VCSP tenant password.                                                                                                                                                                             | ""                                               |
| RestoreConfig                       | Bool   | Enable unattended configuration restore from backup.                                                                                                                                              | false                                            |
| ConfigPasswordSo                    | String | Security Officer password used to decrypt the configuration backup.                                                                                                                               | ""                                               |
| ExternalManagersInstallationEnabled | Bool   | VSA 13.1+. Allow installation of external managers. After the timeout expires, Veeam Host Manager automatically disables the option.                                                              | false                                            |
| ExternalManagersInstallationTimeout | Int    | VSA 13.1+. Timeout (seconds) for the external managers installation window.                                                                                                                       | 3600 (60 min)                                    |
| HighAvailabilityEnabled             | Bool   | VSA 13.1+. Enable HA mode on the appliance. After the timeout expires, Veeam Host Manager automatically disables the option.                                                                      | false                                            |
| HighAvailabilityTimeout             | Int    | VSA 13.1+. Timeout (seconds) for the HA initialization window.                                                                                                                                    | 3600 (60 min)                                    |

#### VIA only (VIA / VIAiscsi / VIAHR)

| Parameter    | Type | Description                                                                                                                                                                  | Default |
|--------------|------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| VIASingleDisk | Bool | Selects the "Single-Disk Deployment" GRUB entry as the boot default (passes `inst.vsingledisk` — wipes all devices). Throws on VSA. | false |

---

### Security Notes

**Password Requirements**
- The passwords for the veeamadmin and veeamso account must meet the following requirements:
- 15 characters minimum
- 1 upper case character
- 1 lower case character
- 1 numeric character
- 1 special character
- No more than 3 characters of the same class in a row. For example, you cannot use more than 3 lowercase or 3 numerical characters in sequence
- The passwords for the veeamadmin and veeamso accounts must be different
**NTP Configuration**
- To avoid timing issues with multifactor authentication, it is recommended to set ntp.runSync=true.
**MFA requirements**
- The multifactor authentication secret key must be specified as a 16 digit, Base32-encoded string.
- The recovery token must be specified using hexadecimal values — 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F. Note that you can generate an appropriate string with the New-Guid cmdlet in Microsoft PowerShell.
**Security Officer Account**
- The SO account provides service-level access separate from the administrative account for improved security separation

### Network Security
- **IP Validation**: Comprehensive IPv4 address format validation using regex patterns
- **DNS Configuration**: Support for multiple DNS servers with individual validation
- **Static Configuration**: Complete network parameter validation for enterprise deployments

### File Security
- **Transcript Logging**: Comprehensive logging with timestamp and severity levels
- **Cleartext secrets in generated `.cfg`**: The generated kickstart (`vbr-ks.cfg` / `proxy-ks.cfg`) necessarily contains all Veeam passwords, MFA secret keys and recovery tokens in cleartext. With `CleanupCFGFiles=true` (default) it is deleted after the ISO is built, but it **persists** when `CFGOnly=true` or `CleanupCFGFiles=false`. Treat these `.cfg` files — and the produced ISO — as secret material and store/shred them accordingly. The `ISO_Customization.log` does **not** record credentials (only ISO/xorriso commands are logged).

---

## How Optional Feature works :

### Node_Exporter (VSA-only, 13.1+)
- VSA 13.1+ has `node_exporter` built-in via Veeam Backup & Replication.
- Enable via JSON: `"NodeExporter": true` (default `false`).
- Optional TLS: `"NodeExporterTLSEnabled": true` switches the metrics endpoint from HTTP to HTTPS.
- Verification after deployment: visit `http://<VSA-IP>/metrics` (or `https://<VSA-IP>/metrics` with TLS).
- Setting `NodeExporter=true` on VIA / VIAiscsi / VIAHR throws early -- these appliances will be piloted by the VSA in a future release.
- No extra files required in the script directory (the previous `offline_repo/` RPM install method is gone).

### VBR Tunning
- **License Installation**: Automated license deployment and activation
- **Run custom script** : Exemple PS script : install lic and add Syslog Server
- If syslog parameters is empty, Add-VBRSyslogServer is not added

Current Exemple in the script is : 
```
$CustomVBRBlock = @(
    "# Custom VBR config",
    "pwsh -Command '",
    "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
    "Install-VBRLicense -Path /etc/veeam/license/$LicenseFile",
    "Add-VBRSyslogServer -ServerHost '$SyslogServer' -Port 514 -Protocol Udp",
    "'"
)
```

### VCSP Connection (RTM_13.0.1.180_20251101 and above)
- **VCSP Connection**: Veeam Service service provider integration with credential management & VSPC management agent flag enable
- (works with optional feature : VBR Tunning to install license)
- check `/var/log/veeam_init.log` for progression
- If you want to remotly enable analytics, for cloud init for exemple, check VCSP folder for bash script


### CFG files Only
- **CFGOnly** : Useful for Packer/CloudInit deployment, you can set parameters to $true thus the script generate only CFG files and do not edit ISO

### Automatique Unattended Restore
- (works with optional feature : VBR Tunning to install license)
- How unattended.xml works : https://helpcenter.veeam.com/docs/vbr/userguide/restore_vbr_linux_edit.html?ver=13
- **Restore process can be very long** : check `/var/log/veeam_init.log` for progression

To speedup the process, you can set `"vbr_control.runStart=false"` in the script ( hardcoded `function Get-VeeamHostConfigBlock`)
- find log - Password SO config: `/var/log/veeam_addsoconfpw.log` & Config restore: `/var/log/veeam_configrestore.log`
- What veeam_addsoconfpw.sh do :
```
Retrieving local IP address
VSA URL: https://192.168.1.169:10443
Generating TOTP code (oathtool)
TOTP code generated
Step 1/4: Authentication (curl)
Authentication successful
Step 2/4: login check
login verified
Step 3/4: Add password
Password added successfully
Step 4/5: Create current configuration password
Current configuration password created successfully
Step 5/5: Final verification
Final verification successful
Process completed successfully
```
- install curl and oathtool from offline repo and then removes oathtool


---

## Known issues
- If you enable NtpRunSync and it fails, customization fails
- If it boots on the init wizard but it's already fully configured and you cannot go through. wait 2-3min. Then check `/var/log/veeam_init.log` (ctrl+alt+F2-F3 etc... to change TTY ) - something went wrong. **Workaround :** Reinstall

## Troubleshooting

### Making ISO

**On Windows (WSL):**
- If you just installed WSL, you need to reboot
- Ensure WSL is installed and available (`wsl --list --verbose`)
- Install `xorriso` in WSL (`sudo apt-get install xorriso`) or update it
- If you just installed WSL, you might have permission issue, reboot Windows

**On macOS / Linux:**
- Ensure `xorriso` is on your PATH (`xorriso -version`). If it is missing, the script prints the
  install command for your platform and exits.

**All platforms:**
- Confirm ISO file is located in the same directory as the script
- Use correct JSON structure with all parameters
- All parameters MUST be defined in the JSON file. Since v2.7 the only CLI argument the script accepts is `-ConfigFile`; any other CLI argument is rejected by PowerShell as unknown.
- If you use optionnal features: check prerequisite and folder structure
- Use `$CFGOnly=true` to verify your kickstart file contain all Configurations Blocks
- Check log file `ISO_Customization.log` for timestamped error messages
- to browse the ISO contents:
    - Windows: `wsl xorriso -indev "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" -ls /`
    - macOS/Linux: `xorriso -indev "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" -ls /`

### Booting ISO
- If your specified answers do not meet these requirements, the configuration process will fail. To troubleshoot errors, you can use the Live OS ISO to view the `/var/log/VeeamBackup/veeam_hostmanager/veeamhostmanager.log` file and the system logs files in the `/var/log/anaconda directory.`
- During installation and after boot, you can try CTRL+ALT+1 to 6 to change TTY, sometimes welcome wizard will dispears and you can check logs
- Post-install log and Veeam init are stored here : `/var/log/appliance-installation-logs/post-install.log` & `/var/log/veeam_init.log`
- If you enable NtpRunSync and it fails, customization fails
- Unattended Configuration Restore logs are stored here : wrong SO Password & TOTP : `/var/log/veeam_addsoconfpw.log` & wrong unattended config password or fail restore : `/var/log/veeam_configrestore.log`

### Troubleshooting parameters

#### Network Configuration Validation
- **IP Format**: Ensure IP addresses match IPv4 format (xxx.xxx.xxx.xxx)
- **Subnet Masks**: Use standard subnet mask formats (255.255.255.0)
- **DNS Arrays**: Provide DNS servers as PowerShell arrays: `@("8.8.8.8", "8.8.4.4")`

#### ISO File Access
- **File Locks**: Ensure ISO files aren't mounted or locked by other applications
- **Permissions**: Verify read/write access to ISO file location
- **Path Format**: don't use paths, put the ISO in the same directory as the script. On Windows
  this avoids WSL path-translation issues; on all platforms it keeps filenames portable.

---

## Work with MFA & Recovery Token

- For MFA creation, you can use this PowerShell :
  
    `
    $MFASecret = -join ((1..16) | ForEach-Object { "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"[(Get-Random -Maximum 32)] })
    `
  
    `
    R2NV4ICF4GM274OU
    `
- For Recovery Token, you can use this PowerShell :
  
    `
    New-Guid
    `
  
    `
    16173f8b-54de-43c7-8364-da36a11ec8ab
    `
  
--

## Contributing

1. Fork this repo and create a pull request to suggest improvements.
2. Use [GitHub Issues](https://github.com/BaptisteTellier/autodeploy/issues) for bugs or feature requests.

## Support

### Documentation Resources
- [Veeam Backup & Replication Documentation](https://helpcenter.veeam.com/docs/vbr/userguide/overview.html?ver=13)
- [Veeam Software Appliance Unattended Documentation](https://helpcenter.veeam.com/docs/vbr/userguide/deployment_linux_silent_deploy_configure.html?ver=13)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Rocky Linux Kickstart Guide](https://docs.rockylinux.org/guides/automation/kickstart/)
- [Node Exporter Releases](https://github.com/prometheus/node_exporter/releases)


## Author & Stats

**Author**: Baptiste TELLIER  
**Version**: 2.8
**Creation**: November 28, 2025

![GitHub stars](https://img.shields.io/github/stars/BaptisteTellier/autodeploy)
![GitHub forks](https://img.shields.io/github/forks/BaptisteTellier/autodeploy)
![GitHub issues](https://img.shields.io/github/issues/BaptisteTellier/autodeploy)
![GitHub last commit](https://img.shields.io/github/last-commit/BaptisteTellier/autodeploy)

---

_Made with ❤️ for the Veeam community by Baptiste TELLIER and the help of AI_

---

*If this project helps you automate Veeam deployments, please give it a star on GitHub!*
