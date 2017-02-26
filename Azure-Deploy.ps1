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
    [string] $SubnetName,
    [Parameter(Mandatory=$false)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$false)]
    [string] $VmPrefix,
    [Parameter(Mandatory=$false)]
    [int] $VmIndex = 1,
    [Parameter(Mandatory=$false)]
    [ValidateSet("xsmall","small","medium","large","xlarge")]
    [string] $VmSize = "small",
    [Parameter(Mandatory=$false)]
    [int] $VmCount = 1,

    # alternately i could move this to a different script
    # to keep the logic simple
    [Parameter(Mandatory=$false)]
    [string] $VmName,
    [Parameter(Mandatory=$false)]
    [bool] $Wipe
)

Import-Module '.\Functions-AzureGeneral.psm1'
Import-Module '.\Functions-Vnet.psm1'
Import-Module '.\Functions-ResourceGroup.psm1'
Import-Module '.\FUnctions-Storage.psm1'

$StorageTemplateFile  = '.\storage.baseline.single.json'
$VmMultiTemplateFile  = '.\vm.baseline.multi.json'
$VmSingleTemplateFile = '.\vm.baseline.single.json'

#
# Validate and use Credential Object
#
if ( $Credentials -eq $null )
{
  $Credentials = Get-Credential
}
Add-AzureRmAccount -Credential $Credentials | Out-Null


#
# Validate or select target subscription
# and then gather associated information needed
#
if ( $SubscriptionName -eq $null )
{
  $SubscriptionName = Select-SubscriptionName
}
$Subscription = Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
$VnetRgName   = Get-VnetResourceGroupName -SubscriptionName $SubscriptionName
$VnetName     = Get-VnetName -SubscriptionName $SubscriptionName


#
# Validate or select the target subnet name
#
if( $SubnetName -eq $null )
{
  $SubnetName = Select-SubnetName -SubscriptionName $SubscriptionName
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
$DiagStorageName = ($ResourceGroupName -Replace '-') + "diagstore01"
$DiagStorage     = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $DiagStorageName -ErrorAction Ignore
if( $DiagStorage -eq $null )
{
  Write-Host "[$(Get-Date)] Diagnostic storage account did not exist, creating [ $DiagStorageName ]"

  $DiagStorageParameters = @{
    location=$Location;
    storAcctName=$DiagStorageName;
    storAcctType="Standard_LRS";
  }

  New-AzureRMResourceGroupDeployment -Name $DeploymentName `
                                     -ResourceGroupName $ResourceGroupName `
                                     -TemplateFile $StorageTemplateFile `
                                     -TemplateParameterObject $DiagStorageParameters `
                                     -Mode Incremental | Out-Null
}


# Now we need to make sure that none of the vms to be created already exist since that would
# be a problem

$AzureSize = Get-MappedTshirtSize( $VmSize )

# there will be two modes of operation
# Dynamic provisioning of new systems, this will take parameters to deploy 1 or more systems
# each one being deployed should be saved for future reference as a parameter file
# (thanks to managed disks i no longer need to have threading)
#
# Existing instance redeploy. this will take a name and read the parameter file
# to interact with an existing system. (rerun the template, or destroy and then rerun the template)
#
# It should take a credential object in either case, prompting if not supplied
# It can take a subscription object for multi (or prompt for it if null)
# - maybe i can detect the vnet resource group and vnet name automatically

# it needs to take an existing instance name, this would be for an existing
# machine and would likely be re-running the template, might need an additional
# flag that would distroy and re-deploy it using the same parameters.

# i won't be able to directly leverage the parameters files if i am deploying in
# a set since i can deploy it faster going with a template that can do 
# grouped deployments, but i want to interact with them individually 

# that means i need to have templates that are compatible between the .multi and .single forms

# i'll need to make sure to clean up the storage for the system when i am redeploying
# of course i could potentially have a persistent storage drive i use on the VM so it
# only redeploys the OS level

# there would need to be a differenctiation between the market deploy and the custom image
# not because the template is overly different but there is a lot of extra steps in deploying
# the vm that uses the image.