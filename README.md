## wba-azure-arm-template-base

This repository provides scripts and ARM templates to create VMs in an Azure Subscription.

#### Scripts

    Azure-Deploy.ps1
        Dynamic system provisioning tool that takes menu driven inputs for standardized configurations
        and deploys systems based on it, creating concrete definitions of the systems deployed for later
        re-deployments and reference

    Quick-Deploy.ps1
        Parameter file driven deployment tool that will read information related to the deployment and
        template file from the provided parameter file and perform the necessary actions including
        creation of the resource group, and diagnostic storage account if necessary.

        This relies on additional information being provided in the parameter file, see the script
        documentation for details on the additional information that must be present in the parameter file.
