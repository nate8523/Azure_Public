# Initialize all uninitialized disks
Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' } | Initialize-Disk -PartitionStyle GPT

# Get all disks without a drive letter that are online
$onlineDisksWithoutDriveLetter = Get-Disk | Where-Object { $_.PartitionStyle -eq 'GPT' -and $_.IsOffline -eq $false -and !$_.DriveLetter }

# Assign drive letters starting from F to online disks without a drive letter and add them as backup repositories
foreach ($disk in $onlineDisksWithoutDriveLetter) {
    $partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
    $partition | Format-Volume -FileSystem ReFS -AllocationUnitSize 64KB -Confirm:$false
}

# Import the Veeam Backup PowerShell module
Import-Module Veeam.Backup.PowerShell

# Connect to Veeam backup server.
$hostname = [Net.Dns]::GetHostName()
$Server = Get-VBRServer -Name $hostname

# Add each initialized disk as a Veeam backup repository
$initializedDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'GPT' -and $_.IsOffline -eq $false }
foreach ($disk in $initializedDisks) {
    $driveLetter = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.DriveLetter } | Select-Object -ExpandProperty DriveLetter
    $folderPath = $driveLetter + ":\"
    Add-VBRBackupRepository -Name "Local Backups $folderpath" -Server $Server -Folder $folderPath -Type WinLocal
}

