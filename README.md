# Create VM

Automate virtual machines provisioning.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for production and testing purposes.

### Prerequisites

The Set-ExecutionPolicy cmdlet enables you to determine which Windows PowerShell scripts will be allowed to run on your computer.

Windows PowerShell has four different execution policies:

Restricted - No scripts can be run. Windows PowerShell can be used only in interactive mode.
AllSigned - Only scripts signed by a trusted publisher can be run.
RemoteSigned - Downloaded scripts must be signed by a trusted publisher before they can be run.
Unrestricted - No restrictions; all scripts can be run.

```powershell
Set-Executionpolicy Unrestricted
```

### Installing

A step by step series of examples that tell you how to get running.

- Clone Github repository,
- Populate VMs.csv with virtual machines,
- Install Windows Server 2016 Standard in Hyper-V,
- Sysprep Windows Server 2016 Standard installation,
- Copy image.vhdx file to proper location (location in script),
- Start CreateVM.ps1

## License

This project is licensed under the Apache License - see the [LICENSE.md](LICENSE.md) file for details
