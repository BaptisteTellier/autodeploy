## What's New (v2.7)
- **JSON-only mode (BREAKING)**: `-ConfigFile` is now the only CLI argument; all other settings MUST come from the JSON file. CLI overrides are no longer supported.
- Built-in defaults are applied first; any key present in the JSON overrides them. Keys absent from the JSON keep their default value.
- Unknown JSON keys are logged as warnings (typo detection).
- `NtpServer` JSON key now accepts an array of servers (e.g. `["ntp1.example.local", "ntp2.example.local"]`) rendered as `ntp.servers=ntp1;ntp2` in the kickstart. Single-string form remains supported (backward-compatible).

## What's New (v2.6)
- Now requires PowerShell 7+ 
- Add Service Provider doesn't require any external tool anymore
- Node_Exporter install use offline_repo
- debug works for all VIA
- 2.6.1 : fixed issue - hardened repo not pairing automatically after deployment 
- 2.6.2 : fixed issue - official updater repo re-enablement after being disabled by offline repo (node exporter & restore conf)

## What's New (v2.5)

- Now works with RTM_13.0.1.180_20251101
- Confirmed with RTM : Add service provider works with SO (no logic added w/o SO yet)
- Enhanced logics with retry & Restart TTY end of script for reliability

## What's New (v2.4)

- Optionnal feature : Debug ! (enable root and ssh)
- Automatique unattended configuration restore now works offline

## What's New (v2.3)

- Optionnal feature : Automatique unattended configuration restore !
- Improved log inside VSA

## What's New (v2.2)

- Now support Veeam Infrastructure Appliance (JeOS) - Proxy / VMware Proxy / Hardened Repository

## What's New (v2.1)

- Fix network configuration not applied correctly
- CFGOnly parameter to create cfg file without iso creation or modification - useful for Packer or Cloud init
- NodeExporterDNF parameter to install Node Exporter with DNF (require online)

## What's New (v2.0)

- JSON configuration support for all parameters
- Out-of-place ISO customization by default
- Optional backup creation for in-place editing
- Improved script logging and in VSA logging
