<#
.SYNOPSIS
    Returns a list of existing VM names for the provided resourse group
    (Returns an empty list if there are none or the group does not exist)
.DESCRIPTION

.PARAMETER ResourceGroupName

.PARAMETER Location
#>
function Get-ExistingVmNames( [string]$ResourceGroupName, [string]$Location )
{
    $ExistingVmNames = @()
    $ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Ignore
    if ($ResourceGroup -ne $null)
    {
        $ExistingVms = Get-AzureRmVM -ResourceGroupName $TargetResourceGroup
        ForEach( $ExistingVm in $ExistingVms )
        {
            $ExistingVmNames = $ExistingVmNames + $ExistingVm.Name
        }
    }

    return $ExistingVmNames
}



<#
.SYNOPSIS
    Checks to see if the provided vm name already exists in the provided resource group at the provided location
.DESCRIPTION

.PARAMETER VmName

.PARAMETER ResourceGroupName

.PARAMETER Location

#>
function VmExists( [string]$VmName, [string]$ResourceGroupName, $Location )
{
    $Exists = $false
    $ExistingVmNames = Get-ExistingVmNames $ResourceGroupName $Location
    if( $ExistingVmNames -Contains $VmName )
    {
        $Exists = $true
    }

    return $Exists
}