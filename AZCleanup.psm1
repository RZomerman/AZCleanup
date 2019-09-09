Function AZConnect {
    Add-AzAccount
}

Function ActivateDebug(){
    Add-Content -Path $LogfileActivated -Value "***************************************************************************************************"
    Add-Content -Path $LogfileActivated -Value "Started processing at [$([DateTime]::Now)]."
    Add-Content -Path $LogfileActivated -Value "***************************************************************************************************"
    Add-Content -Path $LogfileActivated -Value ""
    Write-Host "Debug Enabled writing to logfile: " $LogfileActivated
}


Function WriteDebug{
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$true)][string]$LineValue)
    Process{
        Add-Content -Path $LogfileActivated -Value $LineValue
    }
}

Function GetSubscriptions{
    #GETTING A LIST OF SUBSCRIPTIONS
    Write-Host "Getting the subscriptions, please wait..."
    $Subscriptions=Get-AzSubscription
    Foreach ($subscription in $Subscriptions) {
        $title = $subscription.name
        $message = "Do you want this subscription to be added to the selection?"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
            "Adds the subscription to the script."
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
            "Skips the subscription from scanning."
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
        switch ($result){
            0 {
                $selectedSubscriptions.Add($subscription) > $null
                Write-host ($subscription.name + " has been added")
            } 
            1 {Write-host ($subscription.name + " will be skipped")
            }
        }
    }
    return $selectedSubscriptions
}



Function GetUnattachedNICs {
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter()]
        $ResourceGroup
    )   
    $context=Get-AzContext
    If (!($context.Subscription.Id -eq $SubscriptionID)) {
        Write-host "Switching Context"
        Set-AzContext -Subscription $SubscriptionID
    }
    If ($ResourceGroup) {
        $CollectionOfNICs=Get-AzNetworkInterface | where {($_.VirtualMachine -eq $null) -and $_.ResourceGroupName -eq $ResourceGroup } 
    }else{
        #get all unattached disks
        $CollectionOfNICs=Get-AzNetworkInterface | where {$_.VirtualMachine -eq $null }
    }

    #Check if there are any disks in the collection... 
    If (($CollectionOfNICs) -and ($CollectionOfNICs.count -gt 0)) {
        return $CollectionOfNICs
    }else{
        return 0
    }
}


Function ShowNICS{
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter()]
        $ResourceGroup
    )    


    If ($ResourceGroup) {
        $nics=GetUnattachedNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup
    }else{    
        $nics=GetUnattachedNICs $SubscriptionID
    }

    
    If (!($nics)){
        Write-host "No nics found"
        return $false
    }else{
        #Write-host "This lists shows all the nics and their number"
        #Write-host "Please type the number of a NIC that needs a lock (or removed)"
        #Write-host "or press C to continue with the deletion of all non-locked nics"
        $i=0
        Write-Host "[ Locked ]" -ForegroundColor Green
        Write-host "[Unlocked]" -ForegroundColor Red  
        Foreach ($nic in $nics) {
            #Check if the [0] in the array is the subscription if so, skip
            If ($nic.Account) {
                Write-host "CLEANING ARRAY"
                $i=$i+1
                next
            }
            #Check if there is a lock - and if so, add lock icon to the list of disks
            
            $locked=ResourceLocked $nic

            
            If ($locked) {
                Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Green
            }else{
                Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Red
            }
            Write-host ($nic.name + " in resourceGroup " + $nic.ResourceGroupName )
            $i=$i+1
        }
        return $nics
    }
}

Function ShowResourceGroups {
    Param (
        [parameter(Mandatory)]
        $SubscriptionID
    ) 
    $context=Get-AzContext
    If (!($context.Subscription.Id -eq $SubscriptionID)) {
        Write-host "Switching Context"
        Set-AzContext -Subscription $SubscriptionID
    }
        $ResourceGroups=Get-AzResourceGroup
        If (!($ResourceGroups)){
            Write-host "No Resource Groups found"
            return $false
        }else{
            #Write-host "This lists shows all the groups and their number"
            #Write-host "Please type the number of the Resource Groups that needs a lock (or removed)"
            $i=0
            Write-Host "[ Locked ]" -ForegroundColor Green
            Write-host "[Unlocked]" -ForegroundColor Red  
            Foreach ($group in $ResourceGroups) {
                #Check if the [0] in the array is the subscription if so, skip
                If ($group.Account) {
                    Write-host "CLEANING ARRAY"
                    $i=$i+1
                    next
                }
                #Check if there is a lock - and if so, add lock icon to the list of disks
                
                $locked=ResourceLocked $group
    
                
                If ($locked) {
                    Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Green
                }else{
                    Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Red
                }
                Write-host ($group.name)
                $i=$i+1
            }
            return $ResourceGroups
        }
}
Function GetUnattachedPIPs {
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter()]
        $ResourceGroup
    )   
    $context=Get-AzContext
    If (!($context.Subscription.Id -eq $SubscriptionID)) {
        Write-host "Switching Context"
        Set-AzContext -Subscription $SubscriptionID
    }
    If ($ResourceGroup) {
        $CollectionofPIPs=Get-AzPublicIpAddress | where {($_.IPConfiguration -eq $null) -and $_.ResourceGroupName -eq $ResourceGroup } 
    }else{
        #get all unattached disks
        $CollectionofPIPs=Get-AzPublicIpAddress | where {$_.IPConfiguration -eq $null}
    }

    #Check if there are any disks in the collection... 
    If (($CollectionofPIPs) -and ($CollectionofPIPs.count -gt 0)) {
        return $CollectionofPIPs
    }else{
        return 0
    }
}

Function ShowPIPs{
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter()]
        $ResourceGroup
    )    


    If ($ResourceGroup) {
        $pips=GetUnattachedPIPs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup
    }else{    
        $pips=GetUnattachedPIPs $SubscriptionID
    }
    

    
    If (!($pips)){
        Write-host "No Public IP's found"
        return $false
    }else{
        #Write-host "This lists shows all the Public IP's and their number"
        #Write-host "Please type the number of a PIP that needs a lock (or removed)"
        #Write-host "or press C to continue with the deletion of all non-locked PIP's"
        $i=0
        Write-Host "[ Locked ]" -ForegroundColor Green
        Write-host "[Unlocked]" -ForegroundColor Red  
        Foreach ($pip in $pips) {
            #Check if the [0] in the array is the subscription if so, skip
            If ($pip.Account) {
                Write-host "CLEANING ARRAY"
                $i=$i+1
                next
            }
            #Check if there is a lock - and if so, add lock icon to the list of disks
            
            $locked=ResourceLocked $pip

            
            If ($locked) {
                Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Green
            }else{
                Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Red
            }
            Write-host ($pip.name + " in resourceGroup " + $pip.ResourceGroupName )
            $i=$i+1
        }
        return $pips
    }
}

Function ResourceLocked {
    Param (
        [parameter(Mandatory)]
        $Resource,
        [parameter()]
        $ForResourceGroup
    )  
    Write-Verbose ("CHECKING LOCK ON: " + $Resource.Name)
    #Checks if a lock exists on a resource prior to deleting it
    $ResourceType=($Resource.ID -split "/providers" | select -Last 1) -split ("/" + $Resource.Name) | select -first 1 
    If ($ForResourceGroup){
        $Lock=Get-AzResourceLock -ResourceGroupName $Resource.Name  | where {$_.ResourceType -eq 'Microsoft.Authorization/locks'}
    }
    else {
        $Lock=Get-AzResourceLock -ResourceName $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $ResourceType
    }


    If ($Lock.count -gt 1){
        Write-Verbose ("FOUND MULTIPLE LOCKS: ")
        ForEach ($lok in $lock){
            Write-Verbose $lok
        }
        return $lock
    }elseif ($lock){
        Write-Verbose ("FOUND LOCK: " + $lock)
        return $lock
    }else{    
        Write-Verbose "No Lock Found"
        return $false
    }   
}

Function ApplyResourceLock {
    Param (
        [parameter(Mandatory)]
        $Resource,
        [parameter()]
        $ForResourceGroup
    )  
    Write-Verbose ("inbound object to lock: " + $Resource.Name)
    #This Function is used to set a lock on a resource. Validate the lock exist and return the lock name. 
    $Account=(Get-AzContext).Account.id
    $ResourceType=($Resource.ID -split "/providers" | select -Last 1) -split ("/" + $Resource.Name) | select -first 1 
    If ($ForResourceGroup) {
        Set-AzResourceLock -LockLevel CanNotDelete -LockName "NoDelete" -LockNotes ("added by cleanup script: " + $Account) -ResourceGroupName $Resource.ResourceGroupName -Force
        $Lock=Get-AzResourceLock -ResourceGroupName $Resource.Name  | where {$_.ResourceType -eq 'Microsoft.Authorization/locks'}
    }else {
        Set-AzResourceLock -LockLevel CanNotDelete -LockName "NoDelete" -LockNotes ("added by cleanup script: " + $Account) -ResourceName $Resource.Name -ResourceType $ResourceType -ResourceGroupName $Resource.ResourceGroupName -Force
        $Lock=Get-AzResourceLock -ResourceName $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $ResourceType       
    }
}


Function RemoveResourceLock {
    Param (
        [parameter(Mandatory)]
        $Resource,
        [parameter()]
        $ForResourceGroup
    )  
    Write-Verbose ("inbound object to unlock: " + $Resource.Name)
    #This Function is used to remove lock from a resource. Validate the lock exist and return the lock name. 
    #first we need to check if there is a lock, secondly if that lock is on the object or higher level
    $ResourceType=($Resource.ID -split "/providers" | select -Last 1) -split ("/" + $Resource.Name) | select -first 1 
    $Lock=Get-AzResourceLock -ResourceName $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $ResourceType
    #Write-Verbose $Lock
    If ($Lock.count -gt 1) {
        write-host "parent lock or multiple locks found, cannot remove single lock" -ForegroundColor Red
        Foreach ($loc in $lock) {
            write-host $lock.ResourceType
        }     
    }elseif($Lock){
        #VALIDATE IF THE LOCK IS REMOVABLE - ON THE OBJECT ITSELF
        Write-verbose " in deletion block"
        If (("/" + $Lock.ResourceType) -eq $ResourceType ) {
            #WE CAN REMOVE IT
            Write-Verbose ("Removing lock:" + $Lock.LockID)
            Remove-AzResourceLock -LockId $Lock.LockId -Force
        }Else{
            Write-Host "Parent lock detected, cannot remove" -ForegroundColor Red
            Write-Verbose ("Lock found: " + $Lock.ResourceType)
            Write-Verbose ("Resource  : " + $ResourceType)
        }
    }else{
        Write-host "No lock found"
    }   
}
Function GetUnattachedDisks{
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter()]
        $ResourceGroup
    )   
    $context=Get-AzContext
    If (!($context.Subscription.Id -eq $SubscriptionID)) {
        Write-host "Switching Context"
        Set-AzContext -Subscription $SubscriptionID
    }
    If ($ResourceGroup) {
        Write-host "Retrieving all disks in Resource Group: $ResourceGroup"
        $CollectionOfDisks=get-azdisk | where {($_.DiskState -eq 'Unattached') -and ($_.ResourceGroupName -eq $ResourceGroup)} 
    }else{
        #get all unattached disks
        Write-host "Retrieving all disks"
        $CollectionOfDisks=get-azdisk | where {$_.DiskState -eq 'Unattached'}
    }

    #Check if there are any disks in the collection... 
    If (($CollectionOfDisks) -and ($CollectionOfDisks.count -gt 0)) {
        return $CollectionOfDisks
    }else{
        write-host ":: Returning 0 disks"
        return $false
    }

}
Function ShowDisks{
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter()]
        $ResourceGroup
    )    
    
    
    If ($ResourceGroup) {
        $disks=GetUnattachedDisks -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup
    }else{    
        $disks=GetUnattachedDisks $SubscriptionID
    }

    If (!($disks)){
        Write-host "No disks found"
        return $false
    }else{
        #Write-host "This lists shows all the disks and their number"
        #Write-host "Please type the number of a disk that needs a lock (or removed)"
        #Write-host "or press C to continue with the deletion of all non-locked disks"
        $i=0
        Write-Host "[ Locked ]" -ForegroundColor Green
        Write-host "[Unlocked]" -ForegroundColor Red  
        Foreach ($disk in $disks) {
            #Check if the [0] in the array is the subscription if so, skip
            If ($disk.Account) {
                Write-host "CLEANING ARRAY"
                $i=$i+1
                next
            }
            #Check if there is a lock - and if so, add lock icon to the list of disks
            
            $locked=ResourceLocked $disk

            
            If ($locked) {
                Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Green
            }else{
                Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Red
            }
            Write-host ($disk.name + " in resourceGroup " + $disk.ResourceGroupName )
            $i=$i+1
        }
        return $disks
    }
}

Function DeleteObject{
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter(Mandatory)]
        $ObjectType,
        [parameter()]
        $ResourceGroup,
        [parameter()]
        $Confirmed
    )

    If (!($ResourceGroup)){
        Write-Verbose ("No Resource group specified" )
        Switch ($ObjectType) {
            "Disks" {[array]$objects=GetUnattachedDisks $SubscriptionID}
            "NICs" {[array]$objects=GetUnattachedNICs $SubscriptionID}
            "PIPs" {[array]$objects=GetUnattachedNICs $SubscriptionID}
        }
    }else{
        Write-Verbose ("Resource group limitation: " + $ResourceGroup )
            Switch ($ObjectType) {
                "Disks" {[array]$objects=GetUnattachedDisks -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                "NICs" {[array]$objects=GetUnattachedNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                "PIPs" {[array]$objects=GetUnattachedNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
            }
        
    }

    If ($objects){
        Foreach ($object in $objects) {
            #Check if the [0] in the array is the subscription if so, skip
            If ($object.Account) {
                Write-host "CLEANING ARRAY"
                $i=$i+1
                next
            }
            #Check if there is a lock - and if so, add lock icon to the list of disks
            
            $locked=ResourceLocked $object            
            If ($locked) {
                Write-verbose ($object.name + " locked")
            }else{
                Write-Verbose ("deleting: " + $object.name)
                If ($Confirmed) {
                    Write-host ("Deleting " + $Object.Name + " in Resource Group: " + $object.ResourceGroupName)
                    Switch ($ObjectType){
                        "Disks" {get-azdisk -ResourceGroupName $object.ResourceGroupName -DiskName $object.Name | Remove-AzDisk -Force}
                        "NICs" {Get-AzNetworkInterface -ResourceID $object.id | Remove-AzNetworkInterface -Force}
                        "PIPs" {Get-AzPublicIpAddress -ResourceGroupName $object.ResourceGroupName -Name $object.Name | Remove-AzPublicIpAddress -Force}
                    }
                     
                }else{
                    Switch ($ObjectType){
                        "Disks" {get-azdisk -ResourceGroupName $object.ResourceGroupName -DiskName $object.Name | Remove-AzDisk -WhatIf}
                        "NICs" {Get-AzNetworkInterface -ResourceID $object.id | Remove-AzNetworkInterface -WhatIf}
                        "PIPs" {Get-AzPublicIpAddress -ResourceGroupName $object.ResourceGroupName -Name $object.Name | Remove-AzPublicIpAddress -WhatIf}
                    }
                }
            }
        }
    }
}
Function SelectScope{
    Param (
        [parameter(Mandatory)]
        $SubscriptionID
    )   

    $ResourceGroups=Get-AzResourceGroup
    If ($ResourceGroups) {
        $i=0
        Foreach ($ResourceGroup in $ResourceGroups) {
            #Check if the [0] in the array is the subscription if so, skip
            If ($ResourceGroup.Account) {
                $i=$i+1
                next
            }

            Write-host ("[" + $i + "] ")   -NoNewline -ForegroundColor Green
            Write-host $ResourceGroup.ResourceGroupName 
            $i=$i+1
        }
        $SelectedObject = Read-Host -Prompt 'Type the number to set the scope to that resource group'
        If ( $SelectedObject -match '\d' ) {
            $RS=$ResourceGroups[$SelectedObject]
            Write-Host ("Selected ResourceGroup: " + $ResourceGroups[$SelectedObject].ResourceGroupName)
            return $RS.ResourceGroupName
        }else{
            Write-host "not a number - NO RESOURCE GROUP SELECTED"
            return $false
        }
            #number selected is #SelectedObject
    }else{
        Write-host "no resource groups found"
        return $false
    }
}
Function SelectOperationsTarget{
    Param (
        [parameter(Mandatory)]
        $SubscriptionID,
        [parameter()]
        $Confirmed,
        [parameter()]
        $ResourceGroup
    )   

    #SET Confirmed to false if not specified.. will not delete by default
    If (!($Confirmed)) {$Confirmed = $false}
    #Select disks, NICs or IP's
    Do {
        write-host ("using subscription: " + $SubscriptionID)
        write-host "Which resource type should be targgetted"
        $SelectedObjectType = Read-Host -Prompt 'D[DISK], N[NICs], P[Public IP], R[Resource Groups], S[SCOPE], Q[QUIT]'
        Switch ($SelectedObjectType.ToUpper()) {
            "D" {$Resource=ShowDisks $SubscriptionID}
            "N" {$Resource=ShowNICs $SubscriptionID}
            "P" {$Resource=ShowPIPs $SubscriptionID}
            "R" {$ResourceGroup=ShowResourceGroups $SubscriptionID}
            "S" {
                $ResourceGroup=SelectScope -SubscriptionID $SubscriptionID
                $SelectedObjectType = Read-Host -Prompt 'D[DISK], N[NICs], P[Public IP], R[Resource Groups], Q[QUIT]'
                Switch ($SelectedObjectType.ToUpper()) {
                    "D" {$Resource=ShowDisks -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                    "N" {$Resource=ShowNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                    "P" {$Resource=ShowPIPs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                    "R" {$Resource=ShowResourceGroups -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                }
            }
            "Q" {break}
        }
        $break=$false
        DO {
            $SelectedObject = Read-Host -Prompt 'Type the number to be selected, R [Refresh], D [DELETE], S [SELECT], or Q [QUIT]'
            If (($SelectedObject.ToLower() -ne "q" -or $SelectedObject.ToLower() -eq 'r' -or $SelectedObject.ToLower() -eq 'd') -and $SelectedObject -match '\d' ) {
                #number selected is #SelectedObject
                $ObjectAction = Read-Host -Prompt 'type L (LOCK), U (UNLOCK), R [REFRESH], or C [CONTINUE}'
                Switch ($ObjectAction.ToUpper()){
                    "L" {
                        Write-host ("Applying lock to:" + $Resource[$SelectedObject].Name + " in resource group: " + $Resource[$SelectedObject].ResourceGroupName)
                        Write-Verbose ("Running operation on: " + $Resource[$SelectedObject])
                        $Lock=ApplyResourceLock ($Resource[$SelectedObject])
                        
                        If (!($ResourceGroup)){
                            Switch ($SelectedObjectType.ToUpper()) {
                                "D" {$Resource=ShowDisks $SubscriptionID}
                                "N" {$Resource=ShowNICs $SubscriptionID}
                                "I" {$Resource=ShowPIPs $SubscriptionID}
                                "R" {$Resource=ShowResourceGroups $SubscriptionID}
                            }
                        }else{

                                Switch ($SelectedObjectType.ToUpper()) {
                                    "D" {$Resource=ShowDisks -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "N" {$Resource=ShowNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "I" {$Resource=ShowPIPs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "R" {$Resource=ShowResourceGroups $SubscriptionID}
                                }
                            
                        }
                    }
                    "U"{
                        Write-host ("Trying to remove lock from: " + $Resource[$SelectedObject].Name + " in resource group: " + $Resource[$SelectedObject].ResourceGroupName)
                        Write-Verbose ("Running operation on: " + $Resource[$SelectedObject])
                        $Lock=RemoveResourceLock ($Resource[$SelectedObject])
                        If (!($ResourceGroup)){
                            Switch ($SelectedObjectType.ToUpper()) {
                                "D" {$Resource=ShowDisks $SubscriptionID}
                                "N" {$Resource=ShowNICs $SubscriptionID}
                                "I" {$Resource=ShowPIPs $SubscriptionID}
                                "R" {$Resource=ShowResourceGroups $SubscriptionID}
                            }
                        }else{

                                Switch ($SelectedObjectType.ToUpper()) {
                                    "D" {$Resource=ShowDisks -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "N" {$Resource=ShowNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "I" {$Resource=ShowPIPs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "R" {$Resource=ShowResourceGroups $SubscriptionID}
                                }
                            
                        }
                    }
                    "R"{
                        If (!($ResourceGroup)){
                            Switch ($SelectedObjectType.ToUpper()) {
                                "D" {$Resource=ShowDisks $SubscriptionID}
                                "N" {$Resource=ShowNICs $SubscriptionID}
                                "I" {$Resource=ShowPIPs $SubscriptionID}
                                "R" {$Resource=ShowResourceGroups $SubscriptionID}
                            }
                        }else{

                                Switch ($SelectedObjectType.ToUpper()) {
                                    "D" {$Resource=ShowDisks -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "N" {$Resource=ShowNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "I" {$Resource=ShowPIPs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                                    "R" {$Resource=ShowResourceGroups $SubscriptionID}
                                }
                            
                        }
                    }
                    "C"{
                        Write-host "continue"
                        break
                    }
                }

            }elseif ($SelectedObject.ToLower() -eq "s") {
                #QUIT
                break
            }elseif ($SelectedObject.ToLower() -eq "r"){
                #need to refresh
                If (!($ResourceGroup)){
                    Switch ($SelectedObjectType.ToUpper()) {
                        "D" {$Resource=ShowDisks $SubscriptionID}
                        "N" {$Resource=ShowNICs $SubscriptionID}
                        "I" {$Resource=ShowPIPs $SubscriptionID}
                        "R" {$Resource=ShowResourceGroups $SubscriptionID}
                    }
                }else{

                        Switch ($SelectedObjectType.ToUpper()) {
                            "D" {$Resource=ShowDisks -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                            "N" {$Resource=ShowNICs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                            "I" {$Resource=ShowPIPs -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup}
                            "R" {$Resource=ShowResourceGroups $SubscriptionID}
                        }
                    
                }
            }elseif ($SelectedObject.ToLower() -eq "d") {
                Write-host "RUN DELETE SEQUENCE"
                #RUN DELETE SEQUENCE
                Switch ($SelectedObjectType.ToUpper()) {
                    "D" {$Resource=DeleteObject -SubscriptionID $SubscriptionID -ObjectType "Disks" -Confirmed $Confirmed}
                    "N" {$Resource=DeleteObject -SubscriptionID $SubscriptionID -ObjectType "NICs" -Confirmed $Confirmed}
                    "I" {$Resource=DeleteObject -SubscriptionID $SubscriptionID -ObjectType "PIPs" -Confirmed $Confirmed}
                }
            }elseif ($SelectedObject.ToLower() -eq "q") {
                $break=$true
            }

        }while ($break -ne $true)

    }while ($mainloop -ne $true)
}
