# autodeploy
Automates customization of Veeam Appliance ISO: grub, kickstart, license, node_exporter with error handling, logging, and parameterization

##########################################################

What it does :

Download files (grub.cfg and kickstart.cfg) from iso

edit grub to clean install and run kickstart

edit kickstart file : Answerfile, add Node_Exporter, Add VBR Lic, Run PScmdlet to add syslog server

upload file (grub.cfg and kickstart.cfg) to ISO

##########################################################

What you need before you run this script : 

"license" folder with .lic inside it

to edit tunning : $CustomVBRBlock (All PS command run here)

to deploy node_exporter :

"node_exporter" folder with extracted binary 'NOTICE' 'node_exporter' 'LICENSE'

https://github.com/prometheus/node_exporter/releases

VSA ISO : 

VeeamSoftwareAppliance_13.0.0.4967_20250822.iso

complete parameters
