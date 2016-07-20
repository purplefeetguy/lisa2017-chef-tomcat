$MyPath = $MyInvocation.MyCommand.Path
$MyDir  = Split-Path $MyPath
Push-Location $MyDir
[Environment]::CurrentDirectory = $MyDir

Add-AzureRmAccount

$TargetName = Read-Host "Target Server Name"



$ComponentPartName  = $TargetName -Replace '-'
$StorageAccountName = $ComponentPartName + 'stor0'
$NicName            = $ComponentPartName + 'nic01'
$ResourceGroupname  = $ComponentPartName + 'grp'

$AppName = "Canary"
$SubscriptionName = "WAGS Sandbox"
$Location = "West US"
$Path = "."
$DeploymentName = $ResourceGroupname
$StorageTemplateFile = ".\storage.baseline.json"
$VmTemplateFile = ".\vm.linux.baseline.single.json"


$StorageParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    storAcctPrefix=$StorageAccountName;
    storAcctType="Standard_LRS";
    storAcctCount=2;
}

$ValidationKey = [IO.File]::ReadAllText(".\walgreenco-validator.pem")

$VmParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    vmName=$ComponentPartName;
    vmSize="Standard_D2";
    imagePublisher="RedHat";
    imageOffer="RHEL";
    osVersion="7.2";
    adminUserName="wbaadmin";
    adminPassword="Welcome123!";
    vnetResGrp="srsgrp-azshr01";
    vnetName="svnetw-azshr01";
    subnetName="APP";
    nicName=$NicName;
    storAcctName=$StorageAccountName + "1";
    dataDiskSizeInGB=128;
    diagStorAcctName=$StorageAccountName + "2";
    chefServerUrl="https://172.31.207.210/organizations/walgreenco";
    chefRunList="recipe[chef-client]";
    chefValidationClientName="walgreenco-validator";
    chefValidationKeyFormat="plaintext";
    chefValidationKey=$ValidationKey;
}


Select-AzureRmSubscription -SubscriptionName $SubscriptionName

# Create the resource group if it doesn't already exist
$ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Ignore
if ($ResourceGroup -eq $null)
{
    Write-Output "Creating $ResourceGroupName in $Location"
    New-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location
}

Test-AzureRmResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $StorageTemplateFile  `
    -TemplateParameterObject $StorageParameters `
    -Mode Incremental `
    -Verbose
    
Test-AzureRmResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $VmTemplateFile  `
    -TemplateParameterObject $VmParameters `
    -Mode Incremental `
    -Verbose

New-AzureRMResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $StorageTemplateFile `
    -TemplateParameterObject $StorageParameters `
    -Mode Incremental `
    -Verbose
    
New-AzureRMResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $VmTemplateFile `
    -TemplateParameterObject $VmParameters `
    -Mode Incremental `
    -Verbose

$Nic = Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName
echo "Ip Address: " $Nic.IpConfigurations[0].PrivateIpAddress