<#

	Auther:		Anis Smajlovic
	Email:		smajlovica@aljazeera.net
	Purpose:	Create VMs in Hyper-V from CSV file (bulk)
	Version:	1.0.0.0
	Date:		23-Jan-2019

#>

# Get VMs from CSV file
$CsvFile = "M:\Scripts\CreateVM\VMs.csv"
$CsvImports = Import-Csv $CsvFile

# Check are there any existing VMs 
$VMs=Get-VM

Foreach ($CsvImport in $CsvImports){
    $VMName = $CsvImport.Name

    Foreach ($VM in $VMs){
        If ($VMName -match $VM.Name){
        
        Write-host -ForegroundColor Red "Found VM With the same name as existing VM: $VMName"
        Exit
        } 
    } 
}

# Creating VMs from CSV file
Foreach ($CsvImport in $CsvImports){
    $VMName = $CsvImport.Name
    $VMMem = $CsvImport.Memory
    $VMSwitch = $CsvImport.Switch
	$VMPath = $CsvImport.Path
	$VMGen = $CsvImport.Generation
    $VMStartMem = $VMMem / 1
        
    New-VM -Name $VMName -MemoryStartupBytes $VMStartMem -SwitchName $VMSwitch -Path $VMPath -Generation $VMGen 
}

# Set Network
Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMVlanId = $CsvImport.NetworkVlan

    Set-VMNetworkAdapterVlan -VMName $VMName -Access -VlanId $VMVlanId 

    #Start and stop VM to get mac address, then arm the new MAC address on the NIC itself
    Start-VM $VMName
    Sleep 5
    Stop-Vm $VMName -Force
    Sleep 5
    $MACAddress=get-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" |select MacAddress -ExpandProperty MacAddress
    $MACAddress=($MACAddress -replace '(..)','$1-').trim('-')
    Get-VMNetworkAdapter -VMName $VMName -Name "Network Adapter"|Set-VMNetworkAdapter -StaticMacAddress $MACAddress
}

# Set CPU and Memory for VMs
Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMCPUCount = $CsvImport.ProcessorCount
    $VMMinMem = $CsvImport.MemoryMinimumBytes / 1
    $VMStartMem = $CsvImport.MemoryStartupBytes / 1
    $VMMaxMem = $CsvImport.MemoryMaximumBytes / 1

    Set-VM -Name $VMName -ProcessorCount $VMCPUCount -DynamicMemory -MemoryMinimumBytes $VMMinMem -MemoryStartupBytes $VMStartMem -MemoryMaximumBytes $VMMaxMem
} 

# Set VHD disk from Golden image
$MasterVHDXPath = "M:\Scripts\CreateVM\GoldImage"

Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
	$VMPath = $CsvImport.Path
    $VMGoldImage = $CsvImport.GoldImage

    Copy-Item "$MasterVHDXPath\$VMGoldImage" "$VMPath\$VMName\$VMName.vhdx"
    Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1 -Path "$VMPath\$VMName\$VMName.vhdx"
    Set-VM -Name $VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticStartDelay 5 

    $MyHD = Get-VMHardDiskDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -BootOrder $MyHD
}

# Configure VM
$IPDomain="10.200.70.99"
$DefaultGW="10.200.70.1"
$DNSServer="10.200.69.51"
$DNSDomain="Staging.Local"
$AdminAccount="Administrator"
$AdminPassword="72Isthe#now"
$StandardTime = "Arab Standard Time"
$Organization="Aljazera Staging System"
$ProductID="C3RCX-M6NRP-6CXC9-TW2F2-4RHYD"
$UnattendLocation="M:\Scripts\CreateVM\unattend.xml"
$TemplateLocation="M:\Scripts\CreateVM\GoldImage\WinServer2016StdGui.vhdx"

Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name
    $VMPath = $CsvImport.Path

    Copy-Item $UnattendLocation $VMPath\$VMName\unattend$VMName.xml
    $DefaultXML = "$VMPath\$VMName\" + "unattend"+"$VMName.xml"
    $NewXML = "$VMPath\$VMName\unattend$VMName.xml"
    $NewDefaultXML = Get-Content $DefaultXML
    $NewDefaultXML  | Foreach-Object {
    $_ -replace '1AdminAccount', $AdminAccount `
    -replace '1Organization', $Organization `
    -replace '1Name', $VMName `
    -replace '1ProductID', $ProductID`
    -replace '1StandardTime', $StandardTime `
    -replace '1MacAddressDomain', $MACAddress `
    -replace '1DefaultGW', $DefaultGW `
    -replace '1DNSServer', $DNSServer `
    -replace '1DNSDomain', $DNSDomain `
    -replace '1AdminPassword', $AdminPassword `
    -replace '1IPDomain', $IPDomain 
    } | Set-Content $NewXML

    Mount-vhd -Path "$VMPath\$VMName\$VMName.vhdx"
    #Find the drive letter of the mounted VHD
    $VolumeDriveLetter=Get-DiskImage "$VMPath\$VMName\$VMName.vhdx" | Get-Disk | Get-Partition |Get-Volume |?{$_.FileSystemLabel -ne "Recovery"}|select DriveLetter -ExpandProperty DriveLetter
    #Construct the drive letter of the mounted VHD Drive
    $DriveLetter="$VolumeDriveLetter"+":"
    #Copy the unattend.xml to the drive
    Copy-Item $NewXML $DriveLetter\unattend.xml
    Dismount-Vhd -Path "$VMPath\$VMName\$VMName.vhdx"
}

# Start VM
Foreach ($CsvImport in $CsvImports){
	$VMName = $CsvImport.Name

Start-VM -Name $VMName
}