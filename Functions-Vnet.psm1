<#
.SYNOPSIS
  Returns the name of the VNet Resource Group, and VNet
  based on the subscription name and location
  
  Currently this is a hard-coded, hopefully to change to dynamic lookup
#>
function Get-VnetInfo( $SubscriptionName, $Location )
{
  $VnetGroup = $null
  $VnetName  = $null

  switch( $SubscriptionName )
  {
    
    'INFRASTRUCTURE'
    {
      switch( $Location )
      {
        'West US' { $VnetGroup = 'InfrastructureVNetRG'; $VnetName = 'InfrastructureVNet' }
      }
    }
    'Sensitive Dev-Test 3'      { $VnetGroup = $null }
    'WAGS Sandbox'
    {
      switch( $Location )
      {
        'West US' { $VnetGroup = 'srsgrp-azshr01'; $VnetName  = 'svnetw-azshr01' }
      }
    }
    'Sensitive Dev-Test 2'      { $VnetGroup = $null }
    'WBA - (NSEN)'              { $VnetGroup = $null }
    'Store Technology Frontier' { $VnetGroup = $null }
    'WBA-DTN'                   
    {
      switch( $Location )
      {
        'West US' { $VnetGroup = 'wbadtn-network'; $VnetName = 'WBA-DTN' }
      }
    }
    'Sensitive Prod'            
    {
      switch( $Location )
      {
        'West US' { $VnetGroup = 'prsgrp-azshr01'; $VnetName = 'pvnetw-azshr01' }
        'East US 2' { $VnetGroup = 'prsgrp-azshr51'; $VnetName = 'pvnetw-azshr51' }
      }
      $VnetGroup = $null
    }
    'WBA-SEN'                   { $VnetGroup = $null }
    'Sensitive Dev-Test 1'      { $VnetGroup = $null }
    'Non-Sensitive Dev-Test'
    { 
      switch( $Location )
      {
        'West US'   { $VnetGroup = 'drsgrp-azshr01'; $VnetName = '' }
        'East US 2' { $VnetGroup = 'drsgrp-azshr51'; $VnetName = 'dvnetw-azshr51' }
      }
    }
    'HCC-DTN'                   { $VnetGroup = $null }
  }

  if( $VnetGroup -eq $null )
  {
    throw 'This subscription does not have a known vnet linked in this location'
  }
  return @($VnetGroup, $VnetName)
}


<#
.SYNOPSIS
  Prompts for a subnet selection using the subscription name
  to look up the list of available subnets and returns the
  selected name
#>
function Select-SubnetName( $VnetGroup, $VnetName )
{
  $Vnet     = Get-AzureRmVirtualNetwork -ResourceGroupName $VnetGroup -Name $VnetName
  $Subnets  = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $Vnet

  $SelectedIndex = 0
  for( $i = 0; $i -lt $Subnets.Length; $i++ )
  {
    Write-Host "$($i+1)) $($Subnets[$i].Name)"
  }
  $SelectedIndex = Read-Host 'Select a subnet'

  return $Subnets[$SelectedIndex-1].Name
}
