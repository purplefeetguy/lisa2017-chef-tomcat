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
.PARAMETER Credentials
    User account details for interacting with Azure
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$false)]
    [int] $MachineCount,
    [Parameter(Mandatory=$false)]
    [PsCredential] $Credentials
)


<#
.SYNOPSIS
    Creates a storage account resource and between 1 and 20 virtual machines in sequence
    using the storage account for their disks

    Returns a list of server names and their corrosponding IP addresses as an array of space delimited strings 
.DESCRIPTION

.PARAMETER ResourceGroupName
.PARAMETER SetNumber
.PARAMETER VmTemplateFile
.PARAMETER VmParameterObject
.PARAMETER StorageTemplateFile
.PARAMETER StorageParameterObject
#>
$VmSetBlock = {
    param($Credentials, $ResourceGroupName, $SetNumber, $VmTemplateFile, $VmParameterObject, $StorageTemplateFile, $StorageParameterObject)

    Add-AzureRmAccount -Credential $Credentials | Out-Null
    Select-AzureRmSubscription -SubscriptionName $VmParameterObject.tagAppEnvValue | Out-Null

    New-AzureRMResourceGroupDeployment `
        -Name "$($VmParameterObject.vmNamePrefix)-set$($SetNumber)-deployment" `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $StorageTemplateFile `
        -TemplateParameterObject $StorageParameterObject `
        -Mode Incremental | Out-Null

    New-AzureRMResourceGroupDeployment `
        -Name "$($VmParameterObject.vmNamePrefix)-set$($SetNumber)-deployment" `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $VmTemplateFile `
        -TemplateParameterObject $VmParameterObject `
        -Mode Incremental | Out-Null
    
    $NamePrefix = $VmParameterObject.vmNamePrefix
    $Count      = $VmParameterObject.vmCount
    $Offset     = $VmParameterObject.vmIndexOffset

    $Results = @()
    for( $i = 0; $i -lt $Count; $i++ )
    {
        $VmIndex  = $i + $Offset
        $NicName  = "$NamePrefix$($VmIndex.toString("000"))nic01"
        $Nic      = Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName
        $Results += "$NamePrefix$($VmIndex.toString("000")) $($Nic.IpConfigurations[0].PrivateIpAddress)"
    }
    #return New-Object PsObject -Property @{name=$ParameterObject.vmName; ip=$Nic.IpConfigurations[0].PrivateIpAddress}
    return $Results
}



$MyPath = $MyInvocation.MyCommand.Path
$MyDir  = Split-Path $MyPath
Push-Location $MyDir
[Environment]::CurrentDirectory = $MyDir


$StorageTemplateFile = ".\storage.baseline.single.json"
$VmTemplateFile      = ".\vm.linux.baseline.multi.json"

if( $Credentials -eq $null )
{
    $Credentials      = Get-Credential
}

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

Write-Host "[$(Get-Date)] Creating resource group $TargetResourceGroup with $MachineCount virtual machines"

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


#
# Storage Account parameter object used when creating accounts to house virtual machine disks
#
$VmStorageParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    storAcctName=$VmStoragePrefix;
    storAcctType="Standard_LRS";
}


#
# Virtual machine template parameters used for creating sets of VMs
#
$VmParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    vmNamePrefix=$VmPrefix;
    vmCount=1;
    vmIndexOffset=1;
    vmSize="Standard_D2";
    imagePublisher="RedHat";
    imageOffer="RHEL";
    osVersion="7.3";
    adminUserName="wagsadmin";
    adminPassword="Welcome123!";
    vnetResGrp="srsgrp-azshr01";
    vnetName="svnetw-azshr01";
    subnetName="APP";
    storAcctName=$VmStoragePrefix;
    dataDiskSizeInGB=512;
    diagStorAcctName=$DiagStorageName;
}


#
# Start the jobs to create the VMs
#
$ThreadLimit = 20
$VmGroupJobs = @()
$ActiveCount = 0
$AllResults  = @()

$VmSetCount = [Math]::Ceiling( $MachineCount / 20 )
for( $Set = 1; $Set -le $VmSetCount; $Set++ )
{
    # i need to get how many vms are being created in this set 
    # and figure out how many have already been set
    $ThisStartingIndex = ($Set * 20) - 20 + 1
    $ThisCount = 20
    if( ($Set * 20) -gt $MachineCount )
    {
        $ThisCount = $MachineCount - (($Set * 20) - 20)
    }

    $ThisVmStorageParameters = $VmStorageParameters.Clone()
    $ThisVmStorageParameters.Set_Item("storAcctName", $VmStoragePrefix + $Set.toString("00") )

    $ThisVmParameters = $VmParameters.Clone()
    $ThisVmParameters.Set_Item("storAcctName", $ThisVmStorageParameters.storAcctName)
    $ThisVmParameters.Set_Item("vmIndexOffset", $ThisStartingIndex)
    $ThisVmParameters.Set_Item("vmCount", $ThisCount)
    
    $VmGroupJobs += Start-Job -ScriptBlock $VmSetBlock -ArgumentList $Credentials, $TargetResourceGroup, $Set, $VmTemplateFile, $ThisVmParameters, $StorageTemplateFile, $ThisVmStorageParameters
    $ActiveCount++

    if( $ActiveCount -ge $ThreadLimit )
    {   # if we have reached the thread limit (roughtly) block until some jobs are done
        # get the results from the done ones, and remove them to allow the loop to continue
        $DoneJobs = Wait-Job -Job $VmGroupJobs -Any
        ForEach( $DoneJob in $DoneJobs )
        {
            $Result = Receive-Job -Job $DoneJobs
            $AllResults += $Result

            #
            # Remove this job off of the overall list so we don't receive it again
            #
            $JobsList = New-Object System.Collections.ArrayList(,$VmGroupJobs)
            $JobsList.Remove( $DoneJob )
            $VmGroupJobs = $JobsList.ToArray()
        }
        
        $ActiveCount = $ActiveCount - $DoneJobs.Length
    }
}


#
# Everything should be done at this point, handle the remaining jobs that are finishing up
#
$DoneJobs = Wait-Job -Job $VmGroupJobs
ForEach( $DoneJob in $DoneJobs )
{
    $Result = Receive-Job -Job $DoneJob
    $AllResults += $Result
}

return $AllResults