<#
.SYNOPSIS
  This will be more of a general deployment engine, i want it to generate
  parameter files for each vm deployed so it can be managed individually
  regardless of how it is generated, each unique machine would be tracked
  and using its unique name could be interacted with.

  all this because i want to spin up three servers....
#>
[CmdletBinding()]
param(
    
)

# it needs to take an existing instance name, this would be for an existing
# machine and would likely be re-running the template, might need an additional
# flag that would distroy and re-deploy it using the same parameters.

# i won't be able to directly leverage the parameters files if i am deploying in
# a set since i can deploy it faster going with a template that can do 
# grouped deployments, but i want to interact with them individually 

# that means i need to have templates that are compatible between the .multi and .single forms

# i'll need to make sure to clean up the storage for the system when i am redeploying
# of course i could potentially have a persistent storage drive i use on the VM so it
# only redeploys the OS level

# there would need to be a differenctiation between the market deploy and the custom image
# not because the template is overly different but there is a lot of extra steps in deploying
# the vm that uses the image.