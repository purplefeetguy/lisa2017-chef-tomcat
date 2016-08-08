## wba-azure-arm-template-base

This repository provides scripts and ARM templates to create VMs in an Azure Subscription.

#### Scripts

    Deploy-All.ps1
        This deploys one VM and bootstraps it

    Multi-Deploy.ps1
        This prompts to deploy a VM in a ResourceGroup. It requires the script Multi-Bootstrap which takes the output of VMs and IP addresses

    HvMulti-Deploy.ps1
        This script supports faster high volume VM creation by creating the underlying resource groups with storage accounts in parallel.
    
