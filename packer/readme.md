find in this folder an exemple of multi vm deployment.

Improved boot command can be find here : https://github.com/BaptisteTellier/autodeploy/issues/1#issue-3705664221
```
"boot_commad" : [
    "<wait10>",
    "c",
    "<wait2>",
    "linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=[ votre config ] inst.assumeyes quiet<enter>",
    "<wait2>",
    "initrdefi /images/pxeboot/initrd.img<enter>",
    "<wait2>",
    "boot<enter>"
]
```
