<#
$scriptPath = Split-Path $MyInvocation.MyCommand.Path
& "$scriptPath\Deploy-ARMTemplate.ps1"
#>

Add-AzureRmAccount

# Initialize variables
$SubscriptionName = "WAGS Sandbox"
$Location = "West US"
$Path = "."
$ResourceGroupName = "wba-canary-sbx"
$DeploymentName = "wba-canary-sbx-1"
$TemplateFile = ".\storage.baseline.json"
$TemplateParametersFile = ".\storage.baseline.params.json"

# Test the template
.\Deploy-ARMTemplate.ps1 `
    -SubscriptionName $SubscriptionName `
    -Location $Location `
    -Path $Path `
    -ResourceGroupName $ResourceGroupName `
    -DeploymentName $DeploymentName `
    -TemplateFile $TemplateFile `
    -TemplateParametersFile $TemplateParametersFile `
    -Test

# Deploy the template
.\Deploy-ARMTemplate.ps1 `
    -SubscriptionName $SubscriptionName `
    -Location $Location `
    -Path $Path `
    -ResourceGroupName $ResourceGroupName `
    -DeploymentName $DeploymentName `
    -TemplateFile $TemplateFile `
    -TemplateParametersFile $TemplateParametersFile
