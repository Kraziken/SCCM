$CMSearch='Installation - CM*'
$BladeSearch='*blades*'
$CMGroup=Get-CMDeviceCollection|Where-Object -filterscript {$_.name -like $CMSearch}|Select-Object Name,CollectionID
$BladeGroup=Get-CMDeviceCollection|Where-Object -filterscript {$_.name -like $BladeSearch}|Select-Object Name,CollectionID
$CMGroup
$Bladegroup
$Collections=($CMGroup + $BladeGroup).collectionid

foreach ($Collection in $Collections)
    {
    get-cmdevice -CollectionID $Collection|Where-Object clientactivestatus -eq 1
    
    }



<#
foreach ($Collection in $Collections)
    {
    $servers=get-cmdevice -CollectionID $Collection|Where-Object clientactivestatus -eq 1|%{$_.name}
    Remove-CMDeviceCollectionDirectMembershipRule -ResourceId (get-cmdevice -name $server).resourceid -collectionid $Collection
    }


#>

