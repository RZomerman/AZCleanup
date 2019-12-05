# AZCleanup

Import the module (import-module AzClean.psm1) and the following commands will be available: 

SelectOperationsTarget -SubscriptionID 24890e90-123455-123457789-12438764370

(-Confirmed $true) to actually delete (else -WhatIF)
(-Verbose also available)

The Menu will guide you to select objects: (NIC's, DISKs, PublicIP's). 

You can set a lock to each resource to avoid it from being deleted (follow menu). You can also select R (ResourceGroup) and apply
a lock on a complete resource group to prevent deletion of any object in the resource group. 

Then, select Delete, and it will delete the objects that do not have a lock on them. 

You can also run the fuctions separately: 
- Get-UnattachedNICs 
- Get-UnattachedPIPs 
- Get-UnattachedDisks

(-ResourceGroup 'ResgroupName') optional to further specify the scope

DeleteObject (deletes unused objects that are unlocked)
- DeleteObject -SubscriptionID 24890e90-123455-123457789-12438764370 -ObjectType <see below>
(-Confirmed $true) to actually delete (else -WhatIF)
(-ResourceGroup 'ResgroupName') optional to further specify the scope

ObjectTypes supported: "Disks", "NICs", "PIPs"

If you have a resource as an object in a variable, you can also play with the locks: 

Check if resource is locked:
ResourceLocked -Resource $Resource
(-ForResourceGroup) if $Resource is a ResourceGroup
(for example: 
   $Resource=Get-AzNetworkInterface -Name "MyNic" -ResourceGroupName "MyRG"
   ResourceLocked -Resource $Resource
)

Apply a no-delete lock:
ApplyResourceLock -Resource $Resource
(-ForResourceGroup) if $Resource is a ResourceGroup

Remove a lock (only possible if a single lock on the resource exists and the lock scope is the resource) 
RemoveResourceLock -Resource $Resource
(-ForResourceGroup) if $Resource is a ResourceGroup


Quick Fix Example:
   If you want to delete all unused disks (in a resource group or subscription), you can pipe the output to a remove command
   
   Get-UnattachedDisks -ResourceGroup MyRG | Remove-AzDisk

This will run a delete command against every disk.. appending -Force will remove the verification for every deletion

If you have a lot of disks, and you are sure on the disks to be deleted run it as a job for speeding up the deletion:

   Get-UnattachedDisks -ResourceGroup MyRG | Remove-AzDisk -Force -AsJob
   
You can retrieve the job status through: 
   
   Get-Job
