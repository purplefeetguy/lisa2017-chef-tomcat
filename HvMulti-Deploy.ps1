<#
.SYNOPSIS
    -= High Volume Multi Deploy =-
    Creates a group of virtual machines in the azure sandbox account
    for using to test functionality that requires large sets of VMs
.DESCRIPTION
    Uses the vm.linux.baseline.multi ARM template to create groups of
    20 VMs concurrently putting the workload on Azure instead of your
    workstation by reducing the number of open sessions needed to create
    large groups of machines

    Groups above 200 will be throttled to not exceed 10 active deployments
    at one time
.PARAMETER ResourceGroupName
    A name for the resource group that will be created to house the newly
    created resource and the prefix used for all components created within it
.PARAMETER MachineCount
    The number of virtual machines to create
#>
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


$StorageTemplateFile = ".\storage.baseline.single.json"
$VmTemplateFile      = ".\vm.linux.baseline.multi.json"

$Credentials      = Get-Credential
$Location         = "West US"
$SubscriptionName = "WAGS Sandbox"


try
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
}
catch
{
    Add-AzureRmAccount -Credential $Credentials | Out-Null
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
}


#
# Set the target resource group 
#   uses the ResourceGroupName value if present
#   uses the smart resource pool if empty
#
if( $ResourceGroupName -ne $null -and $ResourceGroupName -ne "" )
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
    

$VmSetBlock = {
    param($Credentials, $ResourceGroupName, $SetNumber, $VmTemplateFile, $VmParameterObject, $StorTemplateFile, $StorParameterObject)

    Add-AzureRmAccount -Credential $Credentials | Out-Null
    Select-AzureRmSubscription -SubscriptionName $ParameterObject.tagAppEnvValue | Out-Null

    New-AzureRMResourceGroupDeployment `
        -Name "$($ParameterObject.vmNamePrefix)-set$($SetNumber)-deployment" `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $StorTemplateFile `
        -TemplateParameterObject $StorParameterObject `
        -Mode Incremental | Out-Null

    New-AzureRMResourceGroupDeployment `
        -Name "$($ParameterObject.vmNamePrefix)-set$($SetNumber)-deployment" `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $VmTemplateFile `
        -TemplateParameterObject $VmParameterObject `
        -Mode Incremental | Out-Null
    
    $NamePrefix = $ParameterObject.vmNamePrefix
    $Count      = $ParameterObject.vmCount
    $Offset     = $ParameterObject.vmIndexOffset

    $Results = @()
    for( $i = 0; $i -le $Count; $i++ )
    {
        $VmIndex = $i + $Offset
        $NicName = "$NamePrefix$($VmIndex.toString("000"))nic01"
        $Nic = Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName
        $Results += "$NamePrefix$($VmIndex.toString("000")) $($Nic.IpConfigurations[0].PrivateIpAddress)"
    }
    #return New-Object PsObject -Property @{name=$ParameterObject.vmName; ip=$Nic.IpConfigurations[0].PrivateIpAddress}
    return $Results
}

#
# for this i want to break the vms into groups of 20, for each one start a thread
# in there i will create the storage account for that set of VMs
#
$ThreadLimit = 10

$VmGroupJobs = @()
$ActiveCount = 0

$AllResults  = @()

$VmSets = [Math]::Ceiling( $MachineCount / 20 )
for( $i = 1; $i -le $VmSets; $i++ )
{

}

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