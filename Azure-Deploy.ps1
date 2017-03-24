<#
.SYNOPSIS
  This will be more of a general deployment engine, i want it to generate
  parameter files for each vm deployed so it can be managed individually
  regardless of how it is generated, each unique machine would be tracked
  and using its unique name could be interacted with.

  all this because i want to spin up three servers....
.PARAMETER Credentials
  A PsCredential object holding your username and password for interacting
  with Azure. If omitted you will be prompted to enter your credentials
.PARAMETER SubscriptionName
  The name of the subscription a set of new servers
  should be deployed into. If omitted you will be prompted to select one
.PARAMETER ResourceGroupName
  Name of the resource group to place the machines in
  (If it does not exist it will be created)
.PARAMETER VmPrefix
  The name to use when creating the group of virtual machines not including
  the index which will be appended to the name dynamically
.PARAMETER VmIndex
  The starting index to use when generating a set of VMs
  Default: 1
.PARAMETER VmSize
  The simple size (TShirt) name used to determine the size to make
  the set of VMs
  Default: small
.PARAMETER VmCount
  The number of VMs to create
  Default: 1

.PARAMETER VmName
  The name of a previously provisioned system to re-run the template
  for.
.PARAMETER Wipe
  Flag to indicate that a previously provisioned system should be destroyed
  and completely re-deployed.
  WARNING: This is a destructive option, the existing instance will be wiped out
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [PsCredential] $Credentials,
    [Parameter(Mandatory=$false)]
    [string] $SubscriptionName,
    [Parameter(Mandatory=$false)]
    [ValidateSet("West US","East US","East US 2","North Central US")]
    [string] $Location = 'West US',
    [Parameter(Mandatory=$false)]
    [string] $SubnetName,
    [Parameter(Mandatory=$false)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$false)]
    [string] $VmPrefix,
    [Parameter(Mandatory=$false)]
    [int] $VmIndex = 1,
    [Parameter(Mandatory=$false)]
    [ValidateSet("xsmall","small","medium","large","xlarge")]
    [string] $VmSize = 'small',
    [Parameter(Mandatory=$false)]
    [int] $VmCount = 1,
    [Parameter(Mandatory=$false)]
    [bool] $Premium = $false
)

Import-Module '.\Functions-AzureGeneral.psm1'
Import-Module '.\Functions-Vnet.psm1'
Import-Module '.\Functions-ResourceGroup.psm1'
Import-Module '.\FUnctions-Storage.psm1'

$StorageTemplateFile  = '.\templates\storage.baseline.single.json'
$VmMultiTemplateFile  = '.\templates\vm.baseline.multi.1.0.json'
$VmSingleTemplateFile = '.\templates\vm.baseline.single.1.0.json'

#
# Validate and use Credential Object
#
if ( $Credentials -eq $null )
{
  $Credentials = Get-Credential
}
Add-AzureRmAccount -Credential $Credentials | Out-Null


#$Location = "West US"
#if( $Location -eq $null )
#{
#  Read-Host "Enter Target Location"
#}

#
# Validate or select target subscription
# and then gather associated information needed
#
if ( $SubscriptionName -eq $null -Or $SubscriptionName -eq '' )
{
  $SubscriptionName = Select-SubscriptionName
}
$Subscription = Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
$VnetInfo     = Get-VnetInfo -SubscriptionName $SubscriptionName -Location $Location
$VnetRgName   = $VnetInfo[0]
$VnetName     = $VnetInfo[1]


#
# Test to ensure that there are no overlaps with existing VM names
# (We are doing this as early as possible to save steps and empty creations)
#
$ExisingVmNames = Get-ExistingVmNames -ResourceGroupName $ResourceGroupName -Location $Location
$ClashingNames  = @()
for( $i = $VmIndex; $i -lt ( $VmIndex + $VmCount ); $i++ )
{
  $TargetVmName = $VmPrefix + $i.ToString().PadLeft( 3, '0' )
  if( $ExisingVmNames -Contains $TargetVmName )
  {
    $ClashingNames += $TargetVmName
  }
}

if( $ClashingNames.Length -gt 0 )
{
  Write-Host 'ERROR: The following existing VMs were found with overlapping names:'
  Write-Host "       $($ClashingNames -Join ', ')"
  Write-Host '       Adjust your range values and try again.'
  exit
}


#
# Validate or select the target subnet name
#
if( $SubnetName -eq $null -Or $SubnetName -eq '' )
{
  $SubnetName = Select-SubnetName -VnetGroup $VnetRgName -VnetName $VnetName
}


#
# Ensure the resource group exists or create it
#
$ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Ignore
if ($ResourceGroup -eq $null)
{
  Write-Host "[$(Get-Date)] Resource group did not exist, creating [ $ResourceGroupName ]"
  New-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
}


#
# Working on the assumption that a storage account will exist within
# the resource group that is named after the resource group with diagstore on the end
# (with dashes removed since storage accounts cant have those)
#
$DiagStorageName = ($ResourceGroupName -Replace '-')
if( $DiagStorageName.Length -gt 18 )
{
  $DiagStorageName = $DiagStorageName.Substring( 0, 18 )
}
$DiagStorageName = $DiagStorageName + 'diag01'
$DiagStorage     = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $DiagStorageName -ErrorAction Ignore
if( $DiagStorage -eq $null )
{
  Write-Host "[$(Get-Date)] Diagnostic storage account did not exist, creating [ $DiagStorageName ]"

  $DiagStorageParameters = @{
    location=$Location;
    storAcctName=$DiagStorageName;
    storAcctType='Standard_LRS';
  }

  New-AzureRMResourceGroupDeployment -Name "$($ResourceGroupName)-diag-$(Get-Date -Format yyyyMMddHHmmss)" `
                                     -ResourceGroupName $ResourceGroupName `
                                     -TemplateFile $StorageTemplateFile `
                                     -TemplateParameterObject $DiagStorageParameters `
                                     -Mode Incremental | Out-Null
}


$AzureSize = Get-MappedTshirtSize -TshirtSize $VmSize
$DataSize  = Get-MappedDataSize -TshirtSize $VmSize

$DiskType  = 'Standard_LRS'
if( $Premium )
{
  $DiskType = 'Premium_LRS'
}


#
# Create the group of virtual machines
#
$VmParameters = @{
  location=$Location;

  # These need to be adjusted or removed
  tagAppNameValue='DynamicDeployment';
  tagAppEnvValue='DynamicDeployment';
  tagSecZoneValue='DynamicDeployment';

  vmNamePrefix=$VmPrefix;
  vmIndexOffset=$VmIndex;
  vmCount=$VmCount;
  vmSize=$AzureSize;
  dataDiskSizeInGB=$DataSize;

  # This will need to be specified
  managedDiskType=$DiskType;

  # This should be able to be specified as well
  # maybe as part of a standard selection where you say linux or windows
  imagePublisher='RedHat';
  imageOffer='RHEL';
  imageVersion='7.3';
  imageRelease='latest'; # @TODO: how do i find out which one was used for storage?

  adminUserName='wagsadmin';
  adminPassword='Welcome123!';
  vnetResGrp=$VnetRgName;
  vnetName=$VnetName;
  subnetName=$SubnetName;
  diagStorAcctName=$DiagStorageName;
}

Write-Host "[$(Get-Date)] Creating [ $($VmCount) ] virtual machine(s)..."
New-AzureRMResourceGroupDeployment -Name "$($VmPrefix)-vm-$(Get-Date -Format yyyyMMddHHmmss)" `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $VmMultiTemplateFile `
                                   -TemplateParameterObject $VmParameters `
                                   -Mode Incremental | Out-Null

#
# Afterwards we need to collect the information about each of them
# so that we can create the parameter files
# and also to return the appropriate list for bootstrapping
#
$Results = @()
for( $i = $VmParameters.vmIndexOffset; $i -lt ( $VmParameters.vmIndexOffset + $VmParameters.vmCount ); $i++ )
{
  $ThisVmName = "$($VmParameters.vmNamePrefix)$($i.ToString().PadLeft( 3, '0' ))"
  $NicName    = "$($ThisVmName)nic01"
  $Nic        = Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName
  $Results   += "$($ThisVmName) $($Nic.IpConfigurations[0].PrivateIpAddress)"

  #
  # Now to create the parameter file with all of the details about this system
  #
  $ThisVmParam                          = New-ParameterObject
  $ThisVmParam.location.value           = $VmParameters.location
  $ThisVmParam.tagAppNameValue.value    = $VmParameters.tagAppNameValue
  $ThisVmParam.tagAppEnvValue.value     = $VmParameters.tagAppEnvValue
  $ThisVmParam.tagSecZoneValue.value    = $VmParameters.tagSecZoneValue
  $ThisVmParam.vmName.value             = $ThisVmName
  $ThisVmParam.vmSize.value             = $VmParameters.vmSize
  $ThisVmParam.dataDiskSizeInGB.value   = $VmParameters.dataDiskSizeInGB
  $ThisVmParam.managedDiskType.value    = $VmParameters.managedDiskType
  $ThisVmParam.imagePublisher.value     = $VmParameters.imagePublisher
  $ThisVmParam.imageOffer.value         = $VmParameters.imageOffer
  $ThisVmParam.imageVersion.value       = $VmParameters.imageVersion
  $ThisVmParam.imageRelease.value       = $VmParameters.imageRelease # Need to find a way to convert the 'latest' value into which one it was
  $ThisVmParam.adminUserName.value      = $VmParameters.adminUserName
  $ThisVmParam.adminPassword.value      = $VmParameters.adminPassword
  $ThisVmParam.vnetResGrp.value         = $VmParameters.vnetResGrp
  $ThisVmParam.vnetName.value           = $VmParameters.vnetName
  $ThisVmParam.subnetName.value         = $VmParameters.subnetName
  $ThisVmParam.ipAddress.value          = $Nic.IpConfigurations[0].PrivateIpAddress
  $ThisVmParam.diagStorAcctName.value   = $VmParameters.diagStorAcctName

  $ThisVmParamFile = New-ParamFileObject -ParameterObject $ThisVmParam
  $ThisVmParamFile.deploymentDetails.subscriptionName   = $SubscriptionName
  $ThisVmParamFile.deploymentDetails.resourceGroupName  = $ResourceGroupName
  $ThisVmParamFile.deploymentDetails.templateFile       = $VmSingleTemplateFile
  Save-ParamFile -ResourceName $ThisVmName -ParamFileObject $ThisVmParamFile
}

return $Results
