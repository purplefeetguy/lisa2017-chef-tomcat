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

  2 nodes - 8TB on edge (as 4 disks)
  3 nodes - 2TB on master (as 2 disk)
  5 nodes - 20TB on data (as 10 disks)
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
    [int] $MasterCount = 3,
    [Parameter(Mandatory=$false)]
    [int] $EdgeCount = 2,
    [Parameter(Mandatory=$false)]
    [int] $DataCount = 5,
    [Parameter(Mandatory=$false)]
    [string] $OverrideSize = $null,
    [Parameter(Mandatory=$false)]
    [ValidateSet("sandbox","development","test","production")]
    [string] $Environment = "production"
)

Import-Module '.\Functions-AzureGeneral.psm1'
Import-Module '.\Functions-Vnet.psm1'
Import-Module '.\Functions-ResourceGroup.psm1'
Import-Module '.\FUnctions-Storage.psm1'

$StorageTemplateFile  = '.\templates\storage.baseline.single.json'
$VmStaticTemplateFile = '.\templates\vm.baseline.single.1.3.json'
$VmDynamicTemplateFile = '.\templates\vm.baseline.single.dynamic.1.3.json'

# This will be needed to get some of the information about the system
# that was built to be passed to the bootstrapper. There will be an expectation
# of certain information existing in here, specificaly the username and password
# in the variables section
$TemplateObject = Get-Content -Raw -Path $VmDynamicTemplateFile | ConvertFrom-Json

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
# TODO: this should probably scan the created set too, since we need to protect
# against creations from other resource groups that would conflict with names in DNS
#
$ExisingVmNames = Get-ExistingVmNames -ResourceGroupName $ResourceGroupName -Location $Location
$ClashingNames  = @()
for( $i = $VmIndex; $i -lt ( $VmIndex + $VmCount ); $i++ )
{
  $TargetVmName = $VmPrefix + $i.ToString().PadLeft( 2, '0' )
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


$AzureSize = Get-MappedTshirtSize -TshirtSize 'hdp'
#$DataSize  = Get-MappedDataSize -TshirtSize $VmSize

$DiskType  = 'Standard_LRS'
if( $Premium )
{
  $DiskType = 'Premium_LRS'
}


Write-Host "[$(Get-Date)] Creating [ $($MasterCount + $EdgeCount + $DataCount) ] virtual machine(s)..."
$Results = @()
$ResultObjects = @()

$RunningIndex = $VmIndex

#
# Create the group of virtual machines
#
ForEach( $HdpType in ('Master', 'Edge', 'Data') )
{
  $Count = 0
  $DataSize = 0

  $DiskCount  = 0
  $Disk01Size = 0
  $Disk02Size = 0
  $Disk03Size = 0
  $Disk04Size = 0
  $Disk05Size = 0
  $Disk06Size = 0
  $Disk07Size = 0
  $Disk08Size = 0
  $Disk09Size = 0
  $Disk10Size = 0

  $ChefEnvironment = $Environment
  $HdpVerTag = "Hortonworks26"
  $ChefTagsGeneric = "Azure,$($Location.Replace(' ','-')),EIS,EISLinux,Infrastructure,HadoopDb,$($HdpVerTag)"
  $ChefSetTag = "Set-$($VmPrefix)"
  $ChefTags = ''

  $ChefRunList = 'recipe[wag_registration],recipe[profile_wag_infrastructure_baseline],recipe[profile_wag_hdp_infra]'
  # i think it may make sense to create profiles for the sub-components

  # It doesn't quite follow our naming standards, but for now i want to be able to differenciate
  switch($HdpType)
  {
     'Master' {
       #$TypePrefix = 'm'
       $Count = $MasterCount 
       $DataSize = 2048
       $DiskCount = 2
       $Disk01Size = $DataSize
       $Disk02Size = $DataSize

       $ChefTags = "$($ChefSetTag),$($ChefTagsGeneric),HdpMaster"
      }
     'Edge' {
       #$TypePrefix = 'e'
       $Count = $EdgeCount
       $DataSize = 2048
       $DiskCount = 4
       $Disk01Size = $DataSize
       $Disk02Size = $DataSize
       $Disk03Size = $DataSize
       $Disk04Size = $DataSize

       $ChefTags = "$($ChefSetTag),$($ChefTagsGeneric),HdpEdge"
      }
     'Data' {
       #$TypePrefix = 'd'
       $Count = $DataCount 
       $DataSize = 2048
       $DiskCount = 5
       $Disk01Size = $DataSize
       $Disk02Size = $DataSize
       $Disk03Size = $DataSize
       $Disk04Size = $DataSize
       $Disk05Size = $DataSize
       #$Disk06Size = $DataSize
       #$Disk07Size = $DataSize
       #$Disk08Size = $DataSize
       #$Disk09Size = $DataSize
       #$Disk10Size = $DataSize

       $ChefTags = "$($ChefSetTag),$($ChefTagsGeneric),HdpData"
      }
  }

  for( $i = 1; $i -le $Count; $i++ )
  {
    $VmParameters = @{
      location=$Location;

      # These need to be adjusted or removed
      AppNameTag='Hadoop';
      AppEnvTag=$Environment;
      SecZoneTag='Unknown';
      vmName="$($VmPrefix)$($RunningIndex.ToString().PadLeft(2, '0'))"
      #vmName="$($VmPrefix)$($TypePrefix)$($i.ToString().PadLeft( 2, '0' ))"
      vmSize=$AzureSize;
      osDiskSize=128;

      # the zero disks will be ignored
      diskCount=$DiskCount;
      disk01Size=$Disk01Size;
      disk02Size=$Disk02Size;
      disk03Size=$Disk03Size;
      disk04Size=$Disk04Size;
      disk05Size=$Disk05Size;
      disk06Size=$Disk06Size;
      disk07Size=$Disk07Size;
      disk08Size=$Disk08Size;
      disk09Size=$Disk09Size;
      disk10Size=$Disk10Size;

      # This will need to be specified
      managedDiskType=$DiskType;

      vnetResGrp=$VnetRgName;
      vnetName=$VnetName;
      subnetName=$SubnetName;
      diagStorAcctName=$DiagStorageName;
    }

    Write-Host "[$(Get-Date)] Creating machine [ $($VmParameters.vmName) ]..."
    # might need to change this
    New-AzureRMResourceGroupDeployment -Name "$($VmPrefix)-vm-$(Get-Date -Format yyyyMMddHHmmss)" `
                                      -ResourceGroupName $ResourceGroupName `
                                      -TemplateFile $VmDynamicTemplateFile `
                                      -TemplateParameterObject $VmParameters `
                                      -Mode Incremental | Out-Null


    #
    # Alter the network interface to be static so it is not lost on deallocation
    # and get the IP address it was assigned for reporting and use
    #
    $ThisVm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VmParameters.vmName
    $Nic = Get-AzureRmResource -ResourceId $ThisVm.NetworkProfile.NetworkInterfaces[0].Id | Get-AzureRmNetworkInterface
    $Nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
    Set-AzureRmNetworkInterface -NetworkInterface $Nic | Out-Null

    # Set the information that the current version of multideploy takes and is also nice to read
    $Results   += "$($VmParameters.vmName) $($Nic.IpConfigurations[0].PrivateIpAddress)"
    # Set the detailed information about the entity that can be used for individual
    # system bootstrap operations
    $ResultObjects += @{
      nodeIp=$Nic.IpConfigurations[0].PrivateIpAddress;
      nodeName=$VmParameters.vmName
      username=$TemplateObject.variables.adminUsername;
      password=$TemplateObject.variables.adminPassword;
      environment=$ChefEnvironment;
      tags=$ChefTags;
      runList=$ChefRunList
    }

    #
    # Now to create the parameter file with all of the details about this system
    #
    $ThisVmParam = New-ParameterObject -Version 2
    $ThisVmParam.location.value           = $VmParameters.location
    $ThisVmParam.AppNameTag.value         = $VmParameters.AppNameTag
    $ThisVmParam.AppEnvTag.value          = $VmParameters.AppEnvTag
    $ThisVmParam.SecZoneTag.value         = $VmParameters.SecZoneTag
    $ThisVmParam.vmName.value             = $VmParameters.vmName
    $ThisVmParam.vmSize.value             = $VmParameters.vmSize
    $ThisVmParam.osDiskSize.value         = $VmParameters.osDiskSize
    $ThisVmParam.diskCount.value          = $VmParameters.diskCount
    $ThisVmParam.disk01Size.value         = $VmParameters.disk01Size
    $ThisVmParam.disk02Size.value         = $VmParameters.disk02Size
    $ThisVmParam.disk03Size.value         = $VmParameters.disk03Size
    $ThisVmParam.disk04Size.value         = $VmParameters.disk04Size
    $ThisVmParam.disk05Size.value         = $VmParameters.disk05Size
    $ThisVmParam.disk06Size.value         = $VmParameters.disk06Size
    $ThisVmParam.disk07Size.value         = $VmParameters.disk07Size
    $ThisVmParam.disk08Size.value         = $VmParameters.disk08Size
    $ThisVmParam.disk09Size.value         = $VmParameters.disk09Size
    $ThisVmParam.disk10Size.value         = $VmParameters.disk10Size
    $ThisVmParam.managedDiskType.value    = $VmParameters.managedDiskType
    $ThisVmParam.vnetResGrp.value         = $VmParameters.vnetResGrp
    $ThisVmParam.vnetName.value           = $VmParameters.vnetName
    $ThisVmParam.subnetName.value         = $VmParameters.subnetName
    $ThisVmParam.ipAddress.value          = $Nic.IpConfigurations[0].PrivateIpAddress
    $ThisVmParam.diagStorAcctName.value   = $VmParameters.diagStorAcctName

    $ThisVmParamFile = New-ParamFileObject -ParameterObject $ThisVmParam
    $ThisVmParamFile.deploymentDetails.subscriptionName   = $SubscriptionName
    $ThisVmParamFile.deploymentDetails.resourceGroupName  = $ResourceGroupName
    $ThisVmParamFile.deploymentDetails.templateFile       = $VmStaticTemplateFile

    $ThisVmParamFile.deploymentDetails.chefEnvironment  = $ChefEnvironment
    $ThisVmParamFile.deploymentDetails.chefTags         = $ChefTags
    $ThisVmParamFile.deploymentDetails.chefRunList      = $ChefRunList

    Save-ParamFile -ResourceName $VmParameters.vmName -ParamFileObject $ThisVmParamFile

    $RunningIndex++
  }
}

return $ResultObjects
