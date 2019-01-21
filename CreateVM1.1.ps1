<#-----------------------------------------------

	Auther:		Anis Smajlovic
	Email:		smajlovica@aljazeera.net
	Purpose:	Create VMs in Hyper-V from CSV file (bulk)
	Version:	1.1.0.0
	Date:		23-Jan-2019

-----------------------------------------------#>

<#-----------------------------------------------

    // Get list of VMs from VMs.csv file

-----------------------------------------------#>
$CsvFile = "X:\Scripts\CreateVM\VMs.csv"
$CsvImports = Import-Csv $CsvFile

Write-host -ForegroundColor Green "[Phase 1.0] - Get VMs list from file: $CsvFile"
Sleep 1
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Check are there any existing VMs 

-----------------------------------------------#>
$VMs=Get-VM
Write-host -ForegroundColor Green "[Phase 1.1] - Check are there any existing VMs from file: $CsvFile"
Foreach ($CsvImport in $CsvImports){
    $VMName = $CsvImport.Name

    Foreach ($VM in $VMs){
        If ($VMName -match $VM.Name){

        Write-host -ForegroundColor Yellow "[Phase 1.1.1] - Found VM name with existing VM name: $VMName"
        Exit
        } 
    } 
}
Sleep 1

<#-----------------------------------------------

    // Creating VMs from CSV file

-----------------------------------------------#>
Write-host -ForegroundColor Green "[Phase 1.2] - Creating VMs from file: $CsvFile"
Foreach ($CsvImport in $CsvImports){
    $VMName = $CsvImport.Name
    $VMMem = $CsvImport.Memory
    $VMSwitch = $CsvImport.Switch
	$VMPath = $CsvImport.Path
	$VMGen = $CsvImport.Generation
    $VMStartMem = $VMMem / 1
    
    New-VM -Name $VMName -MemoryStartupBytes $VMStartMem -SwitchName $VMSwitch -Path $VMPath -Generation $VMGen
    Write-host -ForegroundColor Green "[Phase 1.2.1] - VM created: $VMName" 
}
Sleep 1
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Set VLAN id and get MAC address for 
    // unattended installation

-----------------------------------------------#>
Write-host -ForegroundColor Green "[Phase 1.3] - Configure network"
Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMVlanId = $CsvImport.NetworkVlan

    #Assign VLAN id
    Set-VMNetworkAdapterVlan -VMName $VMName -Access -VlanId $VMVlanId
    Write-host -ForegroundColor Green "[Phase 1.3.1] - Network configured for VM: $VMName , with VLAN id: $VMVlanId"  

    #Start and stop VM to get mac address, then arm the new MAC address on the NIC itself
    Start-VM $VMName
    Sleep 5
    Stop-Vm $VMName -Force
    Sleep 5
    $MACAddress=get-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" |select MacAddress -ExpandProperty MacAddress
    $MACAddress=($MACAddress -replace '(..)','$1-').trim('-')
    Get-VMNetworkAdapter -VMName $VMName -Name "Network Adapter"|Set-VMNetworkAdapter -StaticMacAddress $MACAddress
    Write-host -ForegroundColor Green "[Phase 1.3.2] - Get MAC address for: $VMName" 
}
Sleep 1
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Configure vCPU and RAM 

-----------------------------------------------#>
Write-host -ForegroundColor Green "[Phase 1.4] - Configure vCPU and RAM"
Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMCPUCount = $CsvImport.ProcessorCount
    $VMMinMem = $CsvImport.MemoryMinimumBytes / 1
    $VMStartMem = $CsvImport.MemoryStartupBytes / 1
    $VMMaxMem = $CsvImport.MemoryMaximumBytes / 1

    Set-VM -Name $VMName -ProcessorCount $VMCPUCount -DynamicMemory -MemoryMinimumBytes $VMMinMem -MemoryStartupBytes $VMStartMem -MemoryMaximumBytes $VMMaxMem
    Write-host -ForegroundColor Green "[Phase 1.4.1] - Configured for: $VMName"
    Write-host -ForegroundColor Green "[Phase 1.4.1] ------------------------------------"
    Write-host -ForegroundColor Green "[Phase 1.4.1.1] - vCPUr:          $VMCPUCount"
    Write-host -ForegroundColor Green "[Phase 1.4.1.2] - MinMem:        "$CsvImport.MemoryMinimumBytes
    Write-host -ForegroundColor Green "[Phase 1.4.1.3] - StartMem:      "$CsvImport.MemoryStartupBytes
    Write-host -ForegroundColor Green "[Phase 1.4.1.4] - MaxMem:        "$CsvImport.MemoryMaximumBytes
} 
Sleep 1
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Copy Golden image 

-----------------------------------------------#>
$MasterVHDXPath = "X:\Scripts\CreateVM\GoldImage"

Write-host -ForegroundColor Green "[Phase 2.0] - Copy Golden image"
Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
	$VMPath = $CsvImport.Path
    $VMGoldImage = $CsvImport.GoldImage

    Copy-Item "$MasterVHDXPath\$VMGoldImage" "$VMPath\$VMName\$VMName.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1 -Path "$VMPath\$VMName\$VMName.vhdx"
    Set-VM -Name $VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticStartDelay 5 

    $MyHD = Get-VMHardDiskDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -BootOrder $MyHD
    Write-host -ForegroundColor Green "[Phase 2.1] - Golden image ($VMGoldImage) copied for: $VMName"
}
Sleep 1
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Configure "unattend.xml" file 

-----------------------------------------------#>
Write-host -ForegroundColor Green "[Phase 3.0] - Prepare unattend.xml file"

# Configure VM variables
$DefaultGW = "10.200.70.1"
$DNSServer = "10.200.69.51"
$DNSServer2 = "10.200.69.52"
$DNSDomain = "Staging.Local"
$AddDnsDomain = "Staging.Local"
$LocalAdminAccount = "Administrator"
$LocalAdminPassword = "password123"
$DomainAdminAccount = "Administrator"
$DomainAdminPassword = "password123"
$StandardTime = "Arab Standard Time"
$Organization = "Aljazera Staging System"
$ProductID = "C3RCX-M6NRP-6CXC9-TW2F2-4RHYD"

Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMPath = $CsvImport.Path
    $IPAddress = $CsvImport.IPAddress
    $UnattendLocation = $CsvImport.UnattendLocation

    Copy-Item $UnattendLocation $VMPath\$VMName\unattend$VMName.xml
    $DefaultXML = "$VMPath\$VMName\" + "unattend"+"$VMName.xml"
    $NewXML = "$VMPath\$VMName\unattend$VMName.xml"
    $NewDefaultXML = Get-Content $DefaultXML
    $NewDefaultXML  | Foreach-Object {
    $_ -replace '1AdminAccount', $LocalAdminAccount `
    -replace '1AdminPassword', $LocalAdminPassword `
    -replace '1Organization', $Organization `
    -replace '1Name', $VMName `
    -replace '1ProductID', $ProductID`
    -replace '1StandardTime', $StandardTime `
    -replace '1MacAddressDomain', $MACAddress `
    -replace '1DefaultGW', $DefaultGW `
    -replace '1DNSServer', $DNSServer `
    -replace '2DNSServer', $DNSServer2 `
    -replace '1DNSDomain', $DNSDomain `
    -replace '1AddDnsDomain', $AddDnsDomain `
    -replace '1DomainAdminAccount', $DomainAdminAccount `
    -replace '1DomainAdminPassword', $DomainAdminPassword `
    -replace '1IPDomain', $IPAddress
    } | Set-Content $NewXML
    Write-host -ForegroundColor Green "[Phase 3.1] - Unattend file Parsed for: $VMName"

    Mount-vhd -Path "$VMPath\$VMName\$VMName.vhdx"
    # Find the drive letter of the mounted VHD
    $VolumeDriveLetter=Get-DiskImage "$VMPath\$VMName\$VMName.vhdx" | Get-Disk | Get-Partition |Get-Volume |?{$_.FileSystemLabel -ne "Recovery"}|select DriveLetter -ExpandProperty DriveLetter
    # Construct the drive letter of the mounted VHD Drive
    $DriveLetter="$VolumeDriveLetter"+":"
    # Copy the unattend.xml to the drive
    Copy-Item $NewXML $DriveLetter\unattend.xml
    Dismount-Vhd -Path "$VMPath\$VMName\$VMName.vhdx"
    Write-host -ForegroundColor Green "[Phase 3.2] - Unattend file Copied for: $VMName"
}
Sleep 1
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Start VMs for Provisioning and Delete Unattend file

-----------------------------------------------#>
Write-host -ForegroundColor Green "[Phase 4.0] - Start VMs for Provisioning"

Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMPath = $CsvImport.Path

    Start-VM -Name $VMName
    Write-host -ForegroundColor Green "[Phase 4.1] - Provisioning started for VM: $VMName"
    Sleep 120
    Stop-VM -Name $VMName -Force
    Write-host -ForegroundColor Green "[Phase 4.2] - Stop VM: $VMName"

    Mount-vhd -Path "$VMPath\$VMName\$VMName.vhdx"
    # Find the drive letter of the mounted VHD
    $VolumeDriveLetter=Get-DiskImage "$VMPath\$VMName\$VMName.vhdx" | Get-Disk | Get-Partition |Get-Volume |?{$_.FileSystemLabel -ne "Recovery"}|select DriveLetter -ExpandProperty DriveLetter
    # Construct the drive letter of the mounted VHD Drive
    $DriveLetter="$VolumeDriveLetter"+":"
    # Delete the unattend.xml to the drive
    Remove-Item $DriveLetter\unattend.xml
    Dismount-Vhd -Path "$VMPath\$VMName\$VMName.vhdx"
}
Sleep 1
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Delete Unattend file

-----------------------------------------------#>
Write-host -ForegroundColor Green "[Phase 5.0] - Delete Unattend files"

Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMPath = $CsvImport.Path
    
    Remove-Item $VMPath\$VMName\unattend$VMName.xml
    Write-host -ForegroundColor Green "[Phase 5.1] - Deleted Unattend file for VM: $VMName, from VM path: $VMPath\$VMName\unattend$VMName.xml"
    Write-host -ForegroundColor Green "[Phase 5.2] - Deleted Unattend file for Guest OS: $VMName, from Guest OS path: C:unattend.xml"
}
Sleep 1
Write-host -ForegroundColor Green "..."
Write-host -ForegroundColor Green "[Phase 6.0] - Finished!"
Write-host -ForegroundColor Green "..."

<#-----------------------------------------------

    // Start VMs

-----------------------------------------------#>
Write-host -ForegroundColor Green "[Phase 7.0] - Start VMs from file: $CsvFile"

Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name

    Start-VM -Name $VMName
    Write-host -ForegroundColor Green "[Phase 7.1] - VM started: $VMName"

}
Sleep 1
Write-host -ForegroundColor Green "..."