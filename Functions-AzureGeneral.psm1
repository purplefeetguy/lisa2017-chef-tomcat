<#
.SYNOPSIS
  This is a simple wrapper function to produce the 
  object that will be serialized out to disk as a json parameter file
#>
function New-ParamFileObject( $ParameterObject )
{
  $Version = '1.0.0.0'
  # this should be overridable if needed

  $ParamFileObject = New-Object PSObject 
  Add-Member -InputObject $ParamFileObject -MemberType NoteProperty -Name '$schema' -Value "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
  Add-Member -InputObject $ParamFileObject -MemberType NoteProperty -Name 'contentVersion' -Value $Version
  Add-Member -InputObject $ParamFileObject -MemberType NoteProperty -Name 'parameters' -Value $ParameterObject

  return $ParamFileObject
}

function New-ParameterObject()
{
  # i will need to ensure that the parameter specifications are consistent
  # so that it can be relied on to have specific properties
  # this can populate default values

  # after i get these all defined i can move around the ones that
  # cannot have a defaulted value

  # i need a method to identify the resource group and name of each
  # subscriptions real vnet so it can be 
  # it might be easier to look at if i seperate the values and
  # object building

  $p = New-Object PSObject 

  $location = New-PVO 'West-US'
  $p | Add-Member -MemberType NoteProperty -Name 'location' -Value $location

  $vmName = New-PVO 'Invalid'
  $p | Add-Member -MemberType NoteProperty -Name 'vmName' -Value $vmName

  $vmSize = New-PVO 'Standard_D1'
  $p | Add-Member -MemberType NoteProperty -Name 'vmSize' -Value $vmSize

  $adminUserName = New-PVO 'wbaadmin'
  $p | Add-Member -MemberType NoteProperty -Name 'adminUserName' -Value $adminUserName

  $adminPassword = New-PVO 'Welcome1234!'
  $p | Add-Member -MemberType NoteProperty -Name 'adminPassword' -Value $adminPassword

  $vnetResGrp = New-PVO 'Invalid'
  $p | Add-Member -MemberType NoteProperty -Name 'vnetResGrp' -Value $vnetResGrp

  $vnetName = New-PVO 'Invalid'
  $p | Add-Member -MemberType NoteProperty -Name 'vnetName' -Value $vnetName

  $subnetName = New-PVO 'Invalid' # should i have a default for this?
  $p | Add-Member -MemberType NoteProperty -Name 'subnetName' -Value $subnetName

  $nicName = New-PVO 'Invalid'
  $p | Add-Member -MemberType NoteProperty -Name 'nicName' -Value $nicName

  # i would want to ensure the same IP gets reused once it is assigned
  # until it is released. so even when it is dynamic, it is static
  # when it comes time to plastisize the parameter file for it.
  $ipAddress = 'Dynamic' # this would be different properties
  $p | Add-Member -MemberType NoteProperty -Name 'ipAddress' -Value $ipAddress

}


<#
.SYNOPSIS
  This is a another helper since all parameters are actually
  objects with single 'value' properties, to simplify the 
  New-ParameterObject method body
#>
function New-PVO( $Value )
{
  $o = New-Object PSObject 
  $o | Add-Member -MemberType NoteProperty -Name 'value' -Value $Value

  return $o
}


function Save-ParamFile( $ParamFileObject )
{
  #this will save the file as....
  # for this to work i need to force that vm names are unique, NOW!, this should
  # not be a problem since we want this to be true anyway

}


function Select-SubscriptionName( )
{
  $Subscriptions = Get-AzureSubscription

  $SelectedIndex = 0
  for( $i = 0; $i -lt $Subscriptions.Length; $i++ )
  {
    Write-Host "$($i+1)) $($Subscriptions[$i].SubscriptionName)"
  }
  $SelectedIndex = Read-Host "Select a subscription"

  return $Subscriptions[$SelectedIndex-1].SubscriptionName
}


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