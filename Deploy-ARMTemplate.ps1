<#
.SYNOPSIS
	This script deploys an ARM template.
	
.DESCRIPTION
	This script deploys an ARM template.
	
.NOTES
	Author: Ed Mondek
	Date: 07/15/2016

.CHANGELOG
    1.0  07/15/2016  Ed Mondek  Initial commit
#>

# Sign in to your Azure account
<#
Add-AzureRmAccount
#>

# Initialize variables
$subscriptionName = "WAGS Sandbox"
$location = "West US"
$path = "."

# Set the current subscription
Select-AzureRmSubscription -SubscriptionName $subscriptionName

# Create the resource group if it doesn't already exist
$rgName = "wba-canary-group-sbx"
$rg = Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Ignore
if ($rg -eq $null)
{
    Write-Output "Creating $rgName in $location"
    New-AzureRMResourceGroup -Name $rgName -Location $location
}

# Deploy the ARM template
$deployName = "wba-canary-group-sbx"
$templateFile = "$path\storage.baseline.json"
$templateParamFile = "$path\storage.baseline.params.json"
Test-AzureRmResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $templateFile  -TemplateParameterFile $templateParamFile -Mode Incremental
New-AzureRMResourceGroupDeployment -Name $deployName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterFile $templateParamFile -Mode Incremental

$deployName = "WBA Canary Group Sandbox"
$templateFile = "$path\vm.linux.single.json"
$templateParamFile = "$path\vm.linux.single.chef.params.json"
Test-AzureRmResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $templateFile  -TemplateParameterFile $templateParamFile -Mode Incremental
New-AzureRMResourceGroupDeployment -Name $deployName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterFile $templateParamFile -Mode Incremental

<#
Remove-AzureRmResourceGroup -Name $rgName
#>
