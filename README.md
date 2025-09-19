# Autodeploy

Automates customization of the Veeam Appliance ISO: GRUB, Kickstart, license, Node Exporter—includes error handling, logging, and full parameterization.

---

## Features

- Downloads `grub.cfg` and `kickstart.cfg` from the ISO
- Edits GRUB to enable clean install (erase all) and kickstart execution
- Modifies Kickstart to:
  - Provide installation answers
  - Add Node Exporter
  - Add Veeam Backup & Replication (VBR) license
  - Run PowerShell cmdlets to add a syslog server
- Uploads the modified files back into the ISO

---

## Prerequisites

Before running the script, you need:

1. **WSL & xorriso installed**
   - Make sure [WSL](https://learn.microsoft.com/en-us/windows/wsl/) is running on your computer
   - Install `xorriso` in your WSL environment

2. **License file** (if `$LicenseVBRTune = true`)
   - Place your `.lic` file inside a `license` directory
   - Customize PowerShell commands in the `$CustomVBRBlock` variable

3. **Node Exporter** (if `$NodeExporter = true`)
   - Place the extracted Node Exporter binary files (`node_exporter`, `LICENSE`, `NOTICE`) in a `node_exporter` directory  
   - [Download Node Exporter here](https://github.com/prometheus/node_exporter/releases)

4. **Veeam Software Appliance ISO**
   - Example: `VeeamSoftwareAppliance_13.0.0.4967_20250822.iso`

5. **Configured parameters**
   - Set all required variables in the script’s parameters section before running

---

## Usage

1. Clone or download this repository
2. Prepare all files and prerequisites as described above
3. Edit the script parameters to match your environment and requirements
4. Run the script in the same folder where the ISO is located

---

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.
