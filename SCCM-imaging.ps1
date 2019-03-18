
#requires -version 2
<#

.DESCRIPTION
  .SYNOPSIS
  This script is for creating CM-Device objects and adding them to an imaging collection in SCCM

.PARAMETER <Parameter_Name>
    <
.INPUTS
  Inputs for this script are entered by interactive script
.OUTPUTS
  None
.NOTES
  Version:        1.2
  Author:         Ken Ng
  Creation Date:  08/21/18
  Purpose/Change: 	Removed PSdrive sections as unnecessary.
			        Modified SCCM collection query to only show Imaging collections  1/11/19


  Requires SCCM Console installed locally
  
  
  
.EXAMPLE
  
#>


# Powershell SCCM environment 

Import-Module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
$sitecode = "CSI"
Set-Location "$($siteCode):\"

#remove-psdrive -name $sitecode
#$ProviderMachine = "CSIVMCORPSCCM01.redmond.corp.microsoft.com"
#New-PSDrive -name $sitecode -PSProvider CMSite -root $ProviderMachine



#

#Single or Group server imaging selection
function Show-MenuServerCount
   {
        param (
            [string]$Title1 = 'Server imaging'
                )
        cls
        Write-Verbose "==========$Title1==========" -verbose
        Write-Verbose "Press '1' for single server" -Verbose
        Write-Verbose "Press '2' for list of servers" -Verbose
    }

Do
    {
    Show-MenuServerCount
    $input = Read-Host "Please make a selection"
    switch ($input)
    {
            '1'{
                cls
                'You Chose Option 1'
                $Server= Read-Host "Enter the server name"
                $MacAddress = Read-Host 'Enter the Mac Address, XX:XX:XX:XX:XX:XX'
                Write-Verbose "Adding Server information" -Verbose
                Import-CMComputerInformation -ComputerName $Server -MacAddress $MacAddress -verbose
                $servercount = 'single'
            }'2'{
                cls
                'You chose option 2'
                $CSV = Read-Host "Enter the location of the .CSV server list.  Server,Mac Address"
                Import-CMComputerInformation -FileName $CSV -EnableColumnHeading $True -CollectionName 'All Systems' -Verbose
                $Imaging=import-csv $CSV
                $Servers=$imaging.name
                $servercount = 'group'
            }'q'{#End
            Return
        }
    }
    pause
}
until ($input -le '3')   

#OS Type selection

Function Show-ChassisType
       {
        param (
            [string]$Title2 = 'Imaging selection'
                )
        cls
        Write-Verbose "==========$Title2==========" -verbose
        Write-Verbose "Press '1' for CM imaging" -verbose
        Write-Verbose "Press '2' for Server 2012R2" -Verbose
        Write-Verbose "Press '3' for Server 2016" -Verbose
        Write-Verbose "Press '4' for Server 2019" -verbose
    }      
              
Do
    {
    Show-ChassisType
    $input2 = Read-Host "Please make a selection"
    switch ($input2)
    {
            '1'{
                cls
                'You chose CM imaging'
                $Chassistype = 'Installation - CM'                    
            }'2'{
                cls
                'You chose Server 2012'
                $Chassistype = '2012R2 Datacenter'
            }'3'{
                cls
                'You chose Server 2016'
                $Chassistype = "2016 Datacenter"
            }'4'{
                cls
                'You Chose Server 2019'
                $Chassistype = "2019 Datacenter"
            }'q'{#End
            Return
        }
    }
    pause

}
until ($input2 -le '4')   

$CollectionSearch = "*$Chassistype*"
$CollectionGroups = Get-CMDeviceCollection|Where-Object -filterscript {$_.name -like $CollectionSearch}|Select-Object Name,CollectionID|Sort Name
#$CollectionSearch

#SCCM Imaging Collection Groups Selection

$Menu = @{}
for ($i=1;$i -le $CollectionGroups.count; $i++) 
    { Write-Host "$i. $($CollectionGroups[$i-1].CollectionID),$($CollectionGroups[$i-1].Name)" 
    $Menu.Add($i,($CollectionGroups[$i-1].CollectionID))}

[int]$ans = Read-Host 'Enter selection'
$CollectionID = $Menu.Item($ans) ; $CollectionID

Clear-variable CMDevicecheck -ErrorAction SilentlyContinue
Clear-Variable CheckCM -ErrorAction SilentlyContinue
Write-verbose 'Pausing for Device registration' -Verbose
start-sleep 20


If ($Servercount -eq 'single')
    {
        Write-Verbose 'Checking CM Device registration' -verbose
        $CMDeviceCheck = Get-CMDevice -name $Server -verbose
        While ($CMDeviceCheck -eq $null) {
            if ($CheckCM -le '30') {
            $CMDeviceCheck = Get-CMDevice -name $Server
            $CheckCM++
            Start-Sleep -s 5
            }
            }
            Add-CMDeviceCollectionDirectMembershipRule -CollectionId $CollectionID -ResourceId (get-cmdevice -name $server).resourceid -verbose
    }
    Elseif ($servercount -eq 'group')
        {
            $LastServer = $Servers[-1]
            Write-Verbose 'Checking CM Device registration' -verbose
            $CMDeviceCheck = Get-CMDevice -name $LastServer
            While ($CMDeviceCheck -eq $null) {
                if ($CheckCM -le '30') {
                $CMDeviceCheck = Get-CMDevice -name $LastServer
                $CheckCM++
                Start-Sleep -s 5
            }
            }
            ForEach ($server in $servers)
                {
                Add-CMDeviceCollectionDirectMembershipRule -CollectionId $CollectionID -ResourceId (get-cmdevice -name $server).resourceid -verbose
                }
        }
    


<#
RUN to install SSD

foreach ($server in $servers)
    {
    New-CMDeviceVariable -VariableName Imaging_DriveType -VariableValue SSD -DeviceName $server
    }


Run to install to NVME
foreach ($server in $servers)
    {
    New-CMDeviceVariable -VariableName Imaging_DriveType -VariableValue NVME -DeviceName $server
    }

Run to install to HDD
foreach ($server in $servers)
    {
    New-CMDeviceVariable -VariableName Imaging_DriveType -VariableValue HDD -DeviceName $server
    }


#>

