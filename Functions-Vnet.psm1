<#
.SYNOPSIS
  Returns the name of the VNet Resource Group
  based on the subscription name
  
  Currently this is a hard-coded, hopefully to change to dynamic lookup
#>
function Get-VnetResourceGroupName( $SubscriptionName, $Location )
{
  $VnetGroup = $null

  switch( $SubscriptionName )
  {
    
    'INFRASTRUCTURE'            { $VnetGroup = 'InfrastructureVNetRG' }
    'Sensitive Dev-Test 3'      { $VnetGroup = $null }
    'WAGS Sandbox'              { $VnetGroup = 'srsgrp-azshr01' }
    'Sensitive Dev-Test 2'      { $VnetGroup = $null }
    'WBA - (NSEN)'              { $VnetGroup = $null }
    'Store Technology Frontier' { $VnetGroup = $null }
    'WBA-DTN'                   { $VnetGroup = $null }
    'Sensitive Prod'            { $VnetGroup = $null }
    'WBA-SEN'                   { $VnetGroup = $null }
    'Sensitive Dev-Test 1'      { $VnetGroup = $null }
    #'Non-Sensitive Dev-Test'    { $VnetGroup = 'drsgrp-azshr01' }
    'Non-Sensitive Dev-Test'    { $VnetGroup = 'drsgrp-azshr51' }
    'HCC-DTN'                   { $VnetGroup = $null }
  }

  if( $VnetGroup -eq $null )
  {
    throw 'VNet resource group not known for the provided subscription name'
  }

  return $VnetGroup
}


<#
.SYNOPSIS
  Returns the name of the VNet based on the subscription name
  
  Currently this is a hard-coded, hopefully to change to dynamic lookup
#>
function Get-VnetName( $SubscriptionName )
{
  $VnetName = $null

  switch( $SubscriptionName )
  {
    'INFRASTRUCTURE'            { $VnetName = 'InfrastructureVNet' }
    'Sensitive Dev-Test 3'      { $VnetName = $null }
    'WAGS Sandbox'              { $VnetName = 'svnetw-azshr01' }
    'Sensitive Dev-Test 2'      { $VnetName = $null }
    'WBA - (NSEN)'              { $VnetName = $null }
    'Store Technology Frontier' { $VnetName = $null }
    'WBA-DTN'                   { $VnetName = $null }
    'Sensitive Prod'            { $VnetName = $null }
    'WBA-SEN'                   { $VnetName = $null }
    'Sensitive Dev-Test 1'      { $VnetName = $null }
    'Non-Sensitive Dev-Test'    { $VnetName = 'dvnetw-azshr51' }
    'HCC-DTN'                   { $VnetName = $null }
  }

  if( $VnetName -eq $null )
  {
    throw 'VNet name not known for the provided subscription name'
  }

  return $VnetName
}


<#
.SYNOPSIS
  Prompts for a subnet selection using the subscription name
  to look up the list of available subnets and returns the
  selected name
#>
function Select-SubnetName( $SubscriptionName )
{
  $VnetRG   = Get-VnetResourceGroupName( $SubscriptionName )
  $VnetName = Get-VnetName( $SubscriptionName )

  $Vnet     = Get-AzureRmVirtualNetwork -ResourceGroupName $VnetRG -Name $VnetName
  $Subnets  = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $Vnet

  $SelectedIndex = 0
  for( $i = 0; $i -lt $Subnets.Length; $i++ )
  {
    Write-Host "$($i+1)) $($Subnets[$i].Name)"
  }
  $SelectedIndex = Read-Host 'Select a subnet'

  return $Subnets[$SelectedIndex-1].Name
}
