[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$false)]
    [string] $MachineName
)

$MyPath = $MyInvocation.MyCommand.Path
$MyDir  = Split-Path $MyPath
Push-Location $MyDir
[Environment]::CurrentDirectory = $MyDir

$Location = "West US"
$SubscriptionName = "WAGS Sandbox"


try
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName
}
catch
{
    Add-AzureRmAccount
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName
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


#
# Get the list of existing server names if the resource group exists so it can stop duplicates
#
$ResourceGroup = Get-AzureRmResourceGroup -Name $TargetResourceGroup -Location $Location -ErrorAction Ignore
if ($ResourceGroup -ne $null)
{
    $ExistingVms = Get-AzureRmVM -ResourceGroupName $TargetResourceGroup
    ForEach( $ExistingVm in $ExistingVms )
    {
        $ExistingVmNames = $ExistingVmNames + $ExistingVm.Name
    }
}


#
# Set the target server name
#   If one was provided as an argument use that
#
$TargetName = ""
if( $MachineName -ne "" )
{
    $TargetName = $MachineName
}
while( $TargetName -eq "" )
{
    $TargetName = Read-Host "Target Server Name (Required)"
    if( $ExistingVmNames -Contains $TargetName )
    {
        Write-Host $TargetName " already exists in the specified resource group, please use a different name"
        $TargetName = ""
    }
}


#
# Set names based on target name value collected
#
$TargetName = $TargetName -Replace '-'
$ComponentPartName = $TargetName #-Replace '-'
$NicName = $ComponentPartName + 'nic01'

$AppName = "Canary"
$DeploymentName = $TargetResourceGroup + "-deployment"
$StorageTemplateFile = ".\storage.baseline.single.json"
$VmTemplateFile = ".\vm.linux.baseline.single.json"

$VmStorageName   = "srposstor0" #this is the starting point name which would be incremented as needed to accomoodate more disks
$DiagStorageName = "srpdiagstor" #this will only be created if it does not exist

$DiagStorageParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    storAcctName=$DiagStorageName;
    storAcctType="Standard_LRS";
}

$VmStorageParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    storAcctName=$VmStorageName;
    storAcctType="Standard_LRS";
}


#
# Create the resource group if it does not exist
# (If the resourse group does not exist there definitely are no storage accounts)
#
$ResourceGroup = Get-AzureRmResourceGroup -Name $TargetResourceGroup -Location $Location -ErrorAction Ignore
if ($ResourceGroup -eq $null)
{
    Write-Output "Creating $TargetResourceGroup in $Location"
    New-AzureRMResourceGroup -Name $TargetResourceGroup -Location $Location

    New-AzureRMResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $TargetResourceGroup `
    -TemplateFile $StorageTemplateFile `
    -TemplateParameterObject $DiagStorageParameters `
    -Mode Incremental `
    -Verbose
    
    $InitialVmStorParameters = $VmStorageParameters.Clone()
    $InitialVmStorParameters.Set_Item("storAcctName", $VmStorageName + "1")

    New-AzureRMResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $TargetResourceGroup `
    -TemplateFile $StorageTemplateFile `
    -TemplateParameterObject $InitialVmStorParameters `
    -Mode Incremental `
    -Verbose
}


#
# Determine if we are going to use an existing storage account or add a new one
#
$StorageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $TargetResourceGroup
$StorageAccountCount = 0 # there is at least one, we just created it if it was empty
ForEach( $StorageAccount in $StorageAccounts )
{
    # we only need to worry about the os disks, not the diag disk
    # we just want to ignore the the diag one
    if( $StorageAccount.StorageAccountName -Match $DiagStorageName )
    {
        continue
    }
    $StorageAccountCount++
    $VhdCount = 0
    $Vhds = $StorageAccount | Get-AzureStorageContainer | Get-AzureStorageBlob
    ForEach( $Vhd in $Vhds )
    {
        if( $Vhd.BlobType -ne "PageBlob" )
        {
            continue
        }
        $VhdCount++
    }
    #Write-Host $StorageAccount.StorageAccountName " has " $VhdCount " vhds in it"
    if( $VhdCount -le 18 )
    {   # this one has room
        $TargetStorageAccount = $StorageAccount.StorageAccountName
        break
    }
}

if( $TargetStorageAccount -eq $null )
{
    #
    # There is not a storage account that can accomodate this VM, need to create one
    #
    $TargetStorageAccount = $VmStorageName + ($StorageAccountCount + 1)

    $NewVmStorParameters = $VmStorageParameters.Clone()
    $NewVmStorParameters.Set_Item("storAcctName", $TargetStorageAccount)

    New-AzureRMResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $TargetResourceGroup `
    -TemplateFile $StorageTemplateFile `
    -TemplateParameterObject $NewVmStorParameters `
    -Mode Incremental `
    -Verbose
}



$VmParameters = @{
    location=$Location;
    tagAppNameValue=$AppName;
    tagAppEnvValue=$SubscriptionName;
    tagSecZoneValue=$SubscriptionName;
    vmName=$TargetName;
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
    storAcctName=$TargetStorageAccount;
    dataDiskSizeInGB=128;
    diagStorAcctName=$DiagStorageName;
}

    
New-AzureRMResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $TargetResourceGroup `
    -TemplateFile $VmTemplateFile `
    -TemplateParameterObject $VmParameters `
    -Mode Incremental `
    -Verbose

$Nic = Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $TargetResourceGroup
echo "Ip Address: " $Nic.IpConfigurations[0].PrivateIpAddress