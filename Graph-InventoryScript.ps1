#$everything=Search-AzGraph -Query "where type != ''"

$everything=$(Search-AzGraph -Query "where type != ''" -First 5000)
while ($($everything.Count) % 5000 -eq 0) { 
$everything=$everything + $(Search-AzureRmGraph -Query "where type != ''" -Skip $($everything.Count))
}

$VMs=$everything | Where {$_.type -contains 'Microsoft.Compute/virtualMachines'} 
$NICs=$everything | Where {$_.type -contains 'microsoft.network/networkinterfaces'} 
$pubIPs = $everything | Where {$_.type -contains 'microsoft.network/publicipaddresses'}
$NSGs= $everything | Where {$_.type -contains 'microsoft.network/networksecuritygroups'}
$VMSizes = @()
$locations=$VMs | Select location -Unique
foreach ($location in $($locations.location)){
$sizes=get-azurermvmsize -location $location | Select @{Name="Location";Expression={$location}},Name,NumberOfCores,MemoryInMB,MaxDataDiskCount,OSDiskSizeInMB,ResourceDiskSizeInMB
$VMSizes+=$sizes
}


$output=$VMs `
| select *,@{N='vmSize';E={$_.properties.hardwareProfile.vmSize}} `
| select *,@{N='CurrentSku';E={$s=$_.VMSize;$l=$_.location;$VMSizes | where {$_.Location -eq $l -and $_.Name -eq $s}}} `
| select *,@{N='NumberOfCores';E={$_.CurrentSku.NumberOfCores}} `
| select *,@{N='MemoryInMB';E={$_.CurrentSku.MemoryInMB}} `
| select *,@{N='MaxDataDiskCount';E={$_.CurrentSku.MaxDataDiskCount}} `
| select *,@{N='ResourceDiskSizeInMB';E={$_.CurrentSku.ResourceDiskSizeInMB}} `
| select *,@{N='NICInfo';E={$NICId=$_.id;$NICs | Where {$_.properties.virtualMachine.id  -eq $NICId }}} `
| select *,@{N='NicName';E={(($_.NICInfo).Name)}} `
| select *,@{N='NSGID';E={(($_.NICInfo).properties).networkSecurityGroup.id}} `
| select *,@{N='NSGInfo';E={$NSGID=$_.NSGID;($NSGs | Where {$_.Id -eq $NSGID}).Properties}} `
| select *,@{N='securityRules';E={(($_.NSGInfo).securityRules).Name}} `
| select *,@{N='PrivIP';E={(((($_.NICInfo).Properties).ipConfigurations[0]).properties).privateIPAddress}} `
| select *,@{N='PubIPID';E={(((($_.NICInfo).Properties).ipConfigurations[0]).properties).publicIPAddress.id }} `
| select *,@{N='PubIPInfo';E={$PUBIPID=$_.PubIPID;($pubIPs | Where {$_.Id -eq $PUBIPID}).Properties}} `
| select *,@{N='publicIPAllocationMethod';E={(($_.PubIPInfo)).publicIPAllocationMethod}} `
| select *,@{N='publicIPAddress';E={(($_.PubIPInfo).ipAddress)}}
