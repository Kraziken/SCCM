<#

.DESCRIPTION
  .SYNOPSIS
  This script is for creating SCCM monthly patching groups and deployments

.PARAMETER <Parameter_Name>
    <
.INPUTS
  
.OUTPUTS
  None
.NOTES
  Version:        1.5
  Author:         Ken Ng
  Creation Date:  11/14/2018
  Update          02/10/2022
  Purpose/Change: Adjustment of patching windows

  Requires SCCM Console installed locally
  
  Notes: Removed unnecessary powershell environment variables for CSI
  Added error checking for Update Folder path and error check for monthly software updates

  modified variables for new SCEM server
  modified SCEM powershell loading parameters
  modified variable for Malicious software tool
  modified values for restart server/workstations to suppress reboots
  modified timing of deployments
.EXAMPLE
  
#>
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

# Creating folder share for package updates
$MonthYear = get-date -Format Y
$Foldername = $MonthYear.Replace(' ','')
$Foldershare = '\\vs-sccm-2016\e$\Updates Content\Updates\WKSMonthly' + $Foldername

$Testpath = "FileSystem::\\vs-sccm-2016\e$\Updates Content\Updates\$Foldername"
$Updatepath = Test-Path $Testpath

If ($Updatepath -eq $False)
    {
    New-Item -ItemType Directory -path $Foldershare
    }

# Powershell CSI SCCM environment 
# Site configuration
$SiteCode = "SITE" # Site code 
$ProviderMachineName = "SCCMSERVER" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams



#Query for monthly Security updates
$Month = get-date -Format MM
$Year = get-date -Format yyyy
$UpdateQuery = '*' + $year + '-' + $month + '*'


#Set timing and dates for install deadlines
$BaseDate = (get-date -day 12).Date
$PatchTuesday = $Basedate.AddDays(2 - [int]$basedate.DayOfWeek)

$FirstAvailabledate = $BaseDate.AddHours(1).AddDays(5 - [int]$BaseDate.DayOfWeek)
$SecondAvailabledate = $PatchTuesday.AddHours(1).AddDays(10)

$ITSGroup1Deadline = $PatchTuesday.AddHours(2).AddDays(10)
$ITSGroup2Deadline = $PatchTuesday.AddHours(20).AddDays(10)

#Sync windows updates
Sync-CMSoftwareUpdate -FullSync $true

#Query Monthly software updates minus ARM64 platform
$SoftwareIDS = (Get-CMSoftwareUpdate -Fast|where {($_.localizeddisplayname -like $UpdateQuery -and $_.localizeddisplayname -notlike "*ARM64*")}).CI_ID



#Check if software IDS are available
If ($SoftwareIDS -eq $null)
    {
    Write-Verbose 'No software updates available, check WSUS sync settings.  Exiting' -Verbose
    Return
    }
    Else
    {
    Get-CMSoftwareUpdate -fast|where {($_.localizeddisplayname -like $UpdateQuery -and $_.localizeddisplayname -notlike "*ARM64*")}|select localizeddisplayname,CI_ID|sort|FT -Wrap
    }


#$SoftwareIDS = (Get-CMSoftwareUpdate -fast|where localizeddisplayname -like $UpdateQuery).CI_ID


#Export Monthly SoftareUpdates to CSV

Get-CMSoftwareUpdate -fast|where {($_.localizeddisplayname -like $UpdateQuery -and $_.localizeddisplayname -notlike "*ARM64*")}|select localizeddisplayname,LocalizedInformativeURL|sort|export-csv C:\Users\adminken\Documents\vuln.csv


#Malicious Software Removal tool update
$MaliciousSoftwareID = (Get-CMSoftwareUpdate -Fast|where {($_.localizeddisplayname -like "*Malicious Software Removal Tool x64*" -and $_.IsSuperseded -eq $false)}).CI_ID



$SoftwareGroupName = $MonthYear + " Patching"

New-CMSoftwareUpdateGroup -Name $SoftwareGroupName -Description "Monthly Patching Group"

#Query for Automatic Deployment Rule Monthly Server
$ServerMonthlyQuery = 'Server Monthly ' + $year + '-' + $Month + '*'

#Add Software updates to Software update Group
ForEach ($SoftwareID in $SoftwareIDS)
    {
    Add-CMSoftwareUpdateToGroup -SoftwareUpdateGroupName $SoftwareGroupName -SoftwareUpdateID $SoftwareID
    }

#Add Malicious software tool update
Add-CMSoftwareUpdateToGroup -SoftwareUpdateGroupName $SoftwareGroupName -SoftwareUpdateId $MaliciousSoftwareID

#Set CM software update Deployment Package
New-CMSoftwareUpdateDeploymentPackage -Name $SoftwareGroupName -Path $Foldershare -Description 'Monthly hotfixes'


Save-CMSoftwareUpdate -SoftwareUpdateGroupName $SoftwareGroupName -DeploymentPackageName $SoftwareGroupName

#CM Collection groups for deployment
#$CollectionWorkstations = (Get-CMCollection|where name -like "*Workstations with Clients*").collectionID
$CollectionServerFirstGroup = (Get-CMCollection -name "*1st Maintenance*").collectionID
$CollectionServerSecondGroup = (Get-CMCollection -name "*2nd Maintenance*").collectionid
$CollectionITSGroup1 = (get-cmcollection -Name "*ITS First Maintenance*").collectionid
$CollectionITSGroup2 = (get-cmcollection -Name "*ITS Second Maintenance*").collectionid

#Create Software Deployment
#New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SoftwareGroupName -DeploymentName "$MonthYear Workstation Group" -Description 'Workstations with clients' -AvailableDateTime (get-date) -DeadlineDateTime $SecondPatchGroup -CollectionId $CollectionWorkstations -AllowRestart $false -DownloadFromMicrosoftUpdate $true -RequirePostRebootFullScan $true -SoftwareInstallation $true -RestartWorkstation $False
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SoftwareGroupName -DeploymentName "$MonthYear Server First Maintenance Group - UAT/DEV" -Description 'Servers First group -reboot' -AvailableDateTime $FirstAvailabledate -DeadlineDateTime $FirstAvailabledate -CollectionId $CollectionServerFirstGroup -AllowRestart $true -DownloadFromMicrosoftUpdate $true -RequirePostRebootFullScan $true -SoftwareInstallation $true
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SoftwareGroupName -DeploymentName "$MonthYear Server Second Maintenance Group - Production" -Description 'Production Servers deployment -noreboot' -AvailableDateTime $SecondAvailabledate -DeadlineDateTime $SecondAvailabledate -CollectionID $CollectionServerSecondGroup -AllowRestart $False -DownloadFromMicrosoftUpdate $true -RequirePostRebootFullScan $true -SoftwareInstallation $true -RestartWorkstation $True -RestartServer $True 


New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SoftwareGroupName -DeploymentName "$MonthYear ITS Server Patch group 1" -Description 'ITS Server collection 1 -auto reboot' -AvailableDateTime $SecondAvailabledate -DeadlineDateTime $ITSGroup1Deadline -CollectionId $CollectionITSGroup1 -AllowRestart $true -DownloadFromMicrosoftUpdate $true -RequirePostRebootFullScan $true -SoftwareInstallation $true
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $SoftwareGroupName -DeploymentName "$MonthYear ITS Server Patch group 2" -Description 'ITS Server collection 2 -auto reboot' -AvailableDateTime $SecondAvailabledate -DeadlineDateTime $ITSGroup2Deadline -CollectionId $CollectionITSGroup2 -AllowRestart $true -DownloadFromMicrosoftUpdate $true -RequirePostRebootFullScan $true -SoftwareInstallation $true
