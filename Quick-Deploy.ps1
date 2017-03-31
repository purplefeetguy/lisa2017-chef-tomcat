<#
.SYNOPSIS
This will read a parameter file and take appropriate actions based on the data presented in it
to deploy the system(s) it defines.

Certain information is expected to exist in the parameter file that this script will read directly
to assist in the deployment as an additional top level grouping with the information that would not
normally be present there such as this:

"deploymentDetails" : {
  "subscriptionName": "WAGS Sandbox",
  "resourceGroupName": "your resource group",
  "templateFile" : "path to the template, can be relative"
}

It also expects two standard parameters to be present in the parameter file, though one is optional.
"location" and "diagStorAcctName".

The diagnostic storage account if specified in the parameters will be generated using the
storage.baseline.single.json template that should have been included in the repository
this script is part of. if that is not present it will fail

.PARAMETER ParameterFile
(Required) 
The path a parameter file that contains information about the deployment to be
performed. It must contain the additional information necessary to perform the deployment
automatically as outlined in the synopsis above.

.PARAMETER TemplateFile
(Optional)
The path to the template file for which the parameters apply. If specified this will
take precidence over the template file indicated in the parameter file.
If not specified the value will be pulled from the deploymentDetails.templateFile value
in the parameter file.

.PARAMETER Credentials
(Optional)
A PsCredential object holding the username and password to be used when
connecting to Azure which has the appropriate permissions to perform the actions
necessary to carry out the deployment. If this value is omitted and an authentication
has not already taken place you will be prompted interactively to provide credentials
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ParameterFile,
    [Parameter(Mandatory=$false, Position=1)]
    [string] $TemplateFile,
    [Parameter(Mandatory=$false, Position=2)]
    [PsCredential] $Credentials
)

$Parameters = Get-Content -Raw -Path $ParameterFile | ConvertFrom-Json

#
# Get all of the information that is needed outside of the template
# execution stored in the parameters file (now that we have the parameters file)
#
$SubscriptionName   = $Parameters.deploymentDetails.subscriptionName
$LocationName       = $Parameters.parameters.location.value
$ResourceGroupName  = $Parameters.deploymentDetails.resourceGroupName

#
# If it was not provided and it is not present that is a hard stop
#
if( $TemplateFile -eq '' )
{
  $TemplateFile = $Parameters.deploymentDetails.templateFile
}

#
# Either way we need to be able to locate the file, we can do some quick checking
# using the value as is.
# if it is just a name, that would be the same as looking in the current directory
# which is one of the places we would look. If it is a path it would resolve on its own
# so those are both covered on a single check.
#
# If that fails we can look for it as though it were a name in the templates directory
#
if( Test-Path $TemplateFile )
{
  # this just seems dumb, but i can't think of a better way to write this
  # right now so i guess this will have to do.
  # Note to self: wine doesn't help....
}
elseif ( Test-Path ".\templates\$($TemplateFile)" )
{
  $TemplateFile  = ".\templates\$($TemplateFile)"
}
else
{
  Write-Host "ERROR: The template file specifed [ $($TemplateFile) ] could not be found"
  Write-Host "       as an absolute path, in the current directory, or in the templates"
  Write-Host "       subdirectory. Please correct the template path and try again"
  exit
}


#
# Storage account provisioning will be optional
#
$DiagStorageName   = $null
try{
  $DiagStorageName = $Parameters.parameters.diagStorAcctName.value
} catch { }


#
# It is possible we are already authenticated, if so we can select a
# subscription right away, if that fails we can log in, first.
# if a credential object was not provided to use for that we can
# request it then. (this is probably being WAAAAY too permissive on operational states)
#
try
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
}
catch
{
    if ( $Credentials -eq $null )
    {
      $Credentials = Get-Credential
    }
    Add-AzureRmAccount -Credential $Credentials | Out-Null
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName | Out-Null
}


#
# Ensure the resource group exists or create it
#
$ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $LocationName -ErrorAction Ignore
if ($ResourceGroup -eq $null)
{
  Write-Host "[$(get-date -f "MM/dd/yyyy hh:mm:ss")] Resource group did not exist, creating [ $ResourceGroupName ]"
  New-AzureRMResourceGroup -Name $ResourceGroupName -Location $LocationName | Out-Null
}


#
# Create the diagnostic storage account if it was specified in the parameter 
# file and does not exist already 
#
if( $DiagStorageName -ne $null )
{
  # Make sure the storage baseline template exists
  $StorageTemplateFile = '.\templates\storage.baseline.single.json'
  if( ! (Test-Path $StorageTemplateFile ) )
  {
    Write-Host "ERROR: A diagnostic account [ $($DiagStorageName) ] was specified in the parameter file"
    Write-Host "       but the storage account template file could not be found @ [ $($StorageTemplateFile) ]"
    exit
  }

  $DiagStorage = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $DiagStorageName -ErrorAction Ignore
  if( $DiagStorage -eq $null )
  {
    Write-Host "[$(get-date -f "MM/dd/yyyy hh:mm:ss")] Diagnostic storage account did not exist, creating [ $DiagStorageName ]"

    $DiagStorageParameters = @{
      location=$LocationName;
      storAcctName=$DiagStorageName;
      storAcctType='Standard_LRS';
    }

    New-AzureRMResourceGroupDeployment -Name "$($ResourceGroupName)-diag-$(Get-Date -Format yyyyMMddHHmmss)" `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile $StorageTemplateFile `
                                       -TemplateParameterObject $DiagStorageParameters `
                                       -Mode Incremental | Out-Null
  }
}

Write-Host "[$(get-date -f "MM/dd/yyyy hh:mm:ss")] Performing primary resource deployment(s). please wait..."
New-AzureRMResourceGroupDeployment  -Name "$($ResourceGroupName)-deployment-$(get-date -f yyyyMMddHHmmss)" `
                                    -ResourceGroupName $ResourceGroupName `
                                    -TemplateFile $TemplateFile `
                                    -TemplateParameterFile $ParameterFile `
                                    -Mode Incremental
