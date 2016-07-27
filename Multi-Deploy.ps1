[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$false)]
    [int] $MachineCount
)


$MyPath = $MyInvocation.MyCommand.Path
$MyDir  = Split-Path $MyPath
Push-Location $MyDir
[Environment]::CurrentDirectory = $MyDir

#Import-Module ".\Functions-ResourceGroup.psm1"
#Import-Module ".\Functions-Storage.psm1"

$StorageTemplateFile = ".\storage.baseline.single.json"
$VmTemplateFile      = ".\vm.linux.baseline.single.json"

$Credentials      = Get-Credential
$Location         = "West US"
$SubscriptionName = "WAGS Sandbox"


try
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
}
catch
{
    #$Credentials = Get-Credential
    Add-AzureRmAccount -Credential $Credentials | Out-Null
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
}


#
# Set the target resource group 
#   uses the ResourceGroupName value if present
#   uses the smart resource pool if empty
#
if( $ResourceGroupName -ne "" )
{
    $TargetResourceGroup = $ResourceGroupName
}
else
{
    $TargetResourceGroup = Read-Host "Target Resource Group [Enter for default]"
    if( $TargetResourceGroup -eq "" )
    {
        $TargetResourceGroup = "SmartResourcePool"
    }
}

if( $MachineCount -eq 0 )
{
    $MachineCount = Read-Host "Virtual Machine Count"
}

Write-Host "Creating resource group $TargetResourceGroup with $MachineCount virtual machines"

#
# Make sure the resource group does not exist before we go any further
#
$ResourceGroup = Get-AzureRmResourceGroup -Name $TargetResourceGroup -Location $Location -ErrorAction Ignore
if ($ResourceGroup -ne $null)
{   #stop, this doesn't want to mess with an existing resource group
    Write-Host "target resource group already exists"
    exit
}



#
# Set names based on target name value collected
#
$VmPrefix        = $TargetResourceGroup -Replace '-'
$DiagStorageName = $VmPrefix + "diagstor01"
$VmStoragePrefix = $VmPrefix + "osstor"
$VmNicSuffix     = "nic01"
$DeploymentName  = $TargetResourceGroup + "-deployment"
$AppName         = "Bootstrap Testing"



#
# Make the Resource Group
#
New-AzureRMResourceGroup -Name $TargetResourceGroup -Location $Location | Out-Null



#
# Make the diagnostics data storage account
#
$DiagStorageParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    storAcctName=$DiagStorageName;
    storAcctType="Standard_LRS";
}

New-AzureRMResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $TargetResourceGroup -TemplateFile $StorageTemplateFile -TemplateParameterObject $DiagStorageParameters -Mode Incremental | Out-Null
    


#
# Make the correct number of storage accounts for the number of VMs being created (1 for every 20 VMs)
#
$VmStorageParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    storAcctName=$VmStoragePrefix;
    storAcctType="Standard_LRS";
}

$NeededStorageAccounts = [Math]::Ceiling( $MachineCount / 20 )
for ($i = 1; $i -le $NeededStorageAccounts; $i++) 
{
    $ThisVmStorParameters = $VmStorageParameters.Clone()
    $ThisVmStorParameters.Set_Item("storAcctName", $VmStoragePrefix + $i.toString("00") )

    New-AzureRMResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $TargetResourceGroup -TemplateFile $StorageTemplateFile -TemplateParameterObject $ThisVmStorParameters -Mode Incremental | Out-Null
}


$VmParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    vmName=$VmPrefix;
    vmSize="Standard_D2";
    imagePublisher="RedHat";
    imageOffer="RHEL";
    osVersion="7.2";
    adminUserName="wbaadmin";
    adminPassword="Welcome123!";
    vnetResGrp="srsgrp-azshr01";
    vnetName="svnetw-azshr01";
    subnetName="APP";
    nicName=$VmNicSuffix;
    storAcctName=$VmStoragePrefix;
    dataDiskSizeInGB=128;
    diagStorAcctName=$DiagStorageName;
}



$Block = 
{
    param( $Credentials, $ResourceGroupName, $TemplateFile, $ParameterObject )

    Add-AzureRmAccount -Credential $Credentials | Out-Null
    Select-AzureRmSubscription -SubscriptionName $ParameterObject.tagAppEnvValue | Out-Null
    New-AzureRMResourceGroupDeployment `
        -Name "$($ParameterObject.vmName)-deployment" `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterObject $ParameterObject `
        -Mode Incremental | Out-Null

    $Nic = Get-AzureRmNetworkInterface -Name $ParameterObject.nicName -ResourceGroupName $ResourceGroupName
    #return New-Object PsObject -Property @{name=$ParameterObject.vmName; ip=$Nic.IpConfigurations[0].PrivateIpAddress}
    return "$($ParameterObject.vmName) $($Nic.IpConfigurations[0].PrivateIpAddress)"
}



#
# Start the jobs to create the VMs
#
$VmCreationJobs = @()
for ($i = 1; $i -le $MachineCount; $i++) 
{
    $ThisVmParameters = $VmParameters.Clone()
    $ThisVmParameters.Set_Item("vmName", $VmPrefix + $i.toString("00" ))
    $ThisVmParameters.Set_Item("nicName", $ThisVmParameters.vmName + $VmNicSuffix)
    $ThisVmParameters.Set_Item("storAcctName", $VmStoragePrefix + ([Math]::Ceiling($i / 20)).toString("00"))
    
    $VmCreationJobs += Start-Job -ScriptBlock $Block -ArgumentList $Credentials, $TargetResourceGroup, $VmTemplateFile, $ThisVmParameters
}

Wait-Job -Job $VmCreationJobs | Out-Null
$ReturnedInformation = Receive-Job -Job $VmCreationJobs
return $ReturnedInformation