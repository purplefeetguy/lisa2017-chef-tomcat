<#
.SYNOPSIS
  This is a simple wrapper function to produce the 
  object that will be serialized out to disk as a json parameter file
#>
function New-ParamFileObject( $ParameterObject, $ParameterVersion = '1.0.0.0' )
{
  $ParamFileObject = New-Object PSObject

  Add-Member -InputObject $ParamFileObject -MemberType NoteProperty -Name '$schema' -Value "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
  Add-Member -InputObject $ParamFileObject -MemberType NoteProperty -Name 'contentVersion' -Value $ParameterVersion
  Add-Member -InputObject $ParamFileObject -MemberType NoteProperty -Name 'parameters' -Value $ParameterObject

  #
  # Extra items
  #
  $ep = New-Object PSObject
  $ep | Add-Member -MemberType NoteProperty -Name 'subscriptionName' -Value ''
  $ep | Add-Member -MemberType NoteProperty -Name 'resourceGroupName' -Value ''
  $ep | Add-Member -MemberType NoteProperty -Name 'templateFile' -Value ''

  Add-Member -InputObject $ParamFileObject -MemberType NoteProperty -Name 'deploymentDetails' -Value $ep


  return $ParamFileObject
}


<#
.SYNOPSIS
  Generates a blank parameter object to use for serializing
  the settings of individual system definitions to a parameter file
#>
function New-ParameterObject()
{
  $p = New-Object PSObject 

  # location
  $location = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'location' -Value $location
  # tagAppNameValue
  $tagAppNameValue = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'tagAppNameValue' -Value $tagAppNameValue
  # tagAppEnvValue
  $tagAppEnvValue = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'tagAppEnvValue' -Value $tagAppEnvValue
  # tagSecZoneValue
  $tagSecZoneValue = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'tagSecZoneValue' -Value $tagSecZoneValue
  # vmName
  $vmName = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'vmName' -Value $vmName
  # vmSize
  $vmSize = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'vmSize' -Value $vmSize
  # dataDiskSizeInGB
  $dataDiskSizeInGB = New-PVO -Value 0 -Type 'Integer'
  $p | Add-Member -MemberType NoteProperty -Name 'dataDiskSizeInGB' -Value $dataDiskSizeInGB
  # managedDiskType
  $managedDiskType = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'managedDiskType' -Value $managedDiskType
  # imagePublisher
  $imagePublisher = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'imagePublisher' -Value $imagePublisher
  # imageOffer
  $imageOffer = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'imageOffer' -Value $imageOffer
  # imageVersion
  $imageVersion = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'imageVersion' -Value $imageVersion
  # imageRelease
  $imageRelease = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'imageRelease' -Value $imageRelease
  # adminUserName
  $adminUserName = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'adminUserName' -Value $adminUserName
  # adminPassword
  $adminPassword = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'adminPassword' -Value $adminPassword
  # vnetResGrp
  $vnetResGrp = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'vnetResGrp' -Value $vnetResGrp
  # vnetName
  $vnetName = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'vnetName' -Value $vnetName
  # subnetName
  $subnetName = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'subnetName' -Value $subnetName
  # ipAddress
  $ipAddress = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'ipAddress' -Value $ipAddress
  # diagStorAcctName
  $diagStorAcctName = New-PVO -Value ''
  $p | Add-Member -MemberType NoteProperty -Name 'diagStorAcctName' -Value $diagStorAcctName

  return $p
}


<#
.SYNOPSIS
  This is a another helper since all parameters are actually
  objects with single 'value' properties, to simplify the 
  New-ParameterObject method body
#>
function New-PVO( $Value, $Type = 'String' )
{
  $o = New-Object PSObject 
  $o | Add-Member -MemberType NoteProperty -Name 'value' -TypeName $Type -Value $Value

  return $o
}


<#
.SYNOPSIS
  Save the file to disk
#>
function Save-ParamFile( $ResourceName, $ParamFileObject )
{
  New-Item -ItemType Directory -Path .\created -Force | Out-Null
  try {
    $ParamFileObject | ConvertTo-Json -Depth 10 | Out-File ".\created\$($ResourceName).param.json" -NoClobber
  }
  catch 
  {
    Write-Host 'ERROR: Failed to save parameter file because one already existed.'
    Write-Host "       Saving backup copy as [ .\created\$($ResourceName).param.failed.json ]"
    $ParamFileObject | ConvertTo-Json -Depth 10 | Out-File ".\created\$($ResourceName).param.failed.json"
  }
  
}


<#
.SYNOPSIS
  Generate the console prompts to Select
  a subscription to be used
#>
function Select-SubscriptionName( )
{
  $Subscriptions = Get-AzureRmSubscription

  $SelectedIndex = 0
  for( $i = 0; $i -lt $Subscriptions.Length; $i++ )
  {
    Write-Host "$($i+1)) $($Subscriptions[$i].SubscriptionName)"
  }
  $SelectedIndex = Read-Host "Select a subscription"

  return $Subscriptions[$SelectedIndex-1].SubscriptionName
}


<#
.SYNOPSIS
  Translate a tshirt size string into the related
  Azure VM size value
#>
function Get-MappedTshirtSize( $TshirtSize )
{
  $AzureSize = "Standard_F2S"
  Switch( $TshirtSize.ToLower() )
  {
    "xsmall" { $AzureSize = "Standard_F1S" }
    "small"  { $AzureSize = "Standard_F2S" }
    "medium" { $AzureSize = "Standard_F4S" }
    "large"  { $AzureSize = "Standard_F8S" }
    "xlarge" { $AzureSize = "Standard_F16S" }
  }

  return $AzureSize
}


<#
.SYNOPSIS
  Translate a tshirt size string into the related
  data disk size (in GB)
#>
function Get-MappedDataSize( $TshirtSize )
{
  $DataSize = 64
  Switch( $TshirtSize.ToLower() )
  {
    "xsmall" { $DataSize = 64   }
    "small"  { $DataSize = 128  }
    "medium" { $DataSize = 256  }
    "large"  { $DataSize = 512  }
    "xlarge" { $DataSize = 1024 }
  }

  return $DataSize
}
