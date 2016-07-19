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
	1.1  07/18/2016  Ed Mondek  Added parameters section
#>

# Parameters section
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true, Position=1)]
	[string] $SubscriptionName,

	[Parameter(Mandatory=$true, Position=2)]
	[string] $Location,

	[Parameter(Mandatory=$true, Position=3)]
	[string] $Path,

	[Parameter(Mandatory=$true, Position=4)]
	[string] $ResourceGroupName,

	[Parameter(Mandatory=$true, Position=5)]
	[string] $DeploymentName,

	[Parameter(Mandatory=$true, Position=6)]
	[string] $TemplateFile,

	[Parameter(Mandatory=$true, Position=7)]
	[string] $TemplateParametersFile,

	[Parameter(Mandatory=$false, Position=8)]
	[switch] $Test
)

# Set the current subscription
Select-AzureRmSubscription -SubscriptionName $SubscriptionName

# Create the resource group if it doesn't already exist
$rg = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Ignore
if ($rg -eq $null)
{
    Write-Output "Creating $ResourceGroupName in $Location"
    New-AzureRMResourceGroup -Name $ResourceGroupName -Location $Location
}

# Deploy the ARM templates
if ($Test) {
	Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile  -TemplateParameterFile $TemplateParametersFile -Mode Incremental -Verbose
} else {
	New-AzureRMResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParametersFile -Mode Incremental -Verbose
}

<#
Remove-AzureRmResourceGroup -Name $ResourceGroupName
#>
