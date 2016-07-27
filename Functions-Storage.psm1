<#
.SYNOPSIS
    Searches the resource group for storage accounts that have room to house
    the disk images for a new VM
.DESCRIPTION

.PARAMETER ResourceGroupName

.PARAMETER DiagStorageName
    The name of the storage account used for diagnostics data in the specified
    resource group.
    If provided the storage account identified as matching this name will not be
    used as a potential target
#>
function Get-TargetStorageAccountName( [string]$ResourceGroupName, [string]$DiagStorageName )
{
    $TargetStorageAccount = $null

    $StorageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName
    ForEach( $StorageAccount in $StorageAccounts )
    {   # if a diagnostics storage accout name is given, do not consider it for selection
        if( $DiagStorageName -ne $null -And $StorageAccount.StorageAccountName -Match $DiagStorageName )
        {
            continue
        }
        $VhdCount = Get-VhdCount( $StorageAccount )
        if( $VhdCount -lt 20 )
        {   # this one has room
            $TargetStorageAccount = $StorageAccount.StorageAccountName
            break
        }
    }

    return $TargetStorageAccount
}



<#
.SYNOPSIS
    Counts the number of storage accounts that are associated with the provided resource group
    excluding the diagnostics storage account if its name is provided
.DESCRIPTION

.PARAMETER ResourceGroupName

.PARAMETER $DiagStorageName
#>
function Get-StorageAccountCount( [string]$ResourceGroupName, [string]$DiagStorageName )
{
    $StorageAccountCount = 0

    $StorageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName
    ForEach( $StorageAccount in $StorageAccounts )
    {   # If a diagnostics account name is given, do not count it
        if( $DiagStorageName -ne $null -And $StorageAccount.StorageAccountName -Match $DiagStorageName )
        {
            continue
        }
        $StorageAccountCount++
    }

    return $StorageAccountCount
}



<#
.SYNOPSIS
    Counts the number of VHD files currently stored in the specified storage account
.DESCRIPTION

.PARAMETER StorageAccount
    A storage account object retrieved from a call to Get-AzureRmStorageAccount
#>
function Get-VhdCount( $StorageAccount )
{
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
    return $VhdCount
}