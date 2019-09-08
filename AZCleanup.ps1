[CmdletBinding(DefaultParameterSetName="Mode")]
Param(
	[Parameter(
		Mandatory=$false,
		HelpMessage="Select the Mode to Disk, NIC, PIP, ALL"
		)]
	    [ValidateNotNullOrEmpty()]
        [string[]]
    	[Alias('Please provide the Mode')]	
	    $Mode, #Mode
	[Parameter(
		Mandatory=$false
		)]
    	$ProductionRun,
    [Parameter(
		Mandatory=$false
		)]
    	$Login,
    [Parameter(
		Mandatory=$false
		)]
       $Log,
       [Parameter(
		Mandatory=$false
		)]
        [string]$SubscriptionID,
       [Parameter(
        Mandatory=$false
        )]
        $ResourceGroup
)
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
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][string]
        $SubscriptionID,
        [Parameter(Mandatory=$false)][string]
        $ResourceGroup
        
    )
    Process{
        $context=Get-AzContext
        If (!($context -eq $SubscriptionID)) {
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
}

Function GetUnattachedPIPs {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][string]
        $SubscriptionID,
        [Parameter(Mandatory=$false)][string]
        $ResourceGroup
        
    )
    Process{
        $context=Get-AzContext
        If (!($context -eq $SubscriptionID)) {
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
}

Function ResourceLocked {
    Param (
        [parameter(Mandatory)]
        $Resource
    )  
    #Checks if a lock exists on a resource prior to deleting it
    $ResourceType=($Resource.ID -split "/providers" | select -Last 1) -split ("/" + $Resource.Name) | select -first 1 
    $Lock=Get-AzResourceLock -ResourceName $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $ResourceType
    If ($Lock){
        return $lock
    }else{
        return $false
    }   
    
}

Function ApplyResourceLock {
    Param (
        [parameter(Mandatory)]
        $Resource
    )  
    #This Function is used to set a lock on a resource. Validate the lock exist and return the lock name. 
    $Account=(Get-AzContext).Account.id
    $ResourceType=($Resource.ID -split "/providers" | select -Last 1) -split ("/" + $Resource.Name) | select -first 1 
    Set-AzResourceLock -LockLevel CanNotDelete -LockName "NoDelete" -LockNotes ("added by cleanup script: " + $Account) -ResourceName $Resource.Name -ResourceType $ResourceType -ResourceGroupName $Resource.ResourceGroupName  
    $Lock=Get-AzResourceLock -ResourceName $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $ResourceType
}

Function GetUnattachedDisks{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][string]
        $SubscriptionID,
        [Parameter(Mandatory=$false)][string]
        $ResourceGroup
        
    )
    Process{
        $context=Get-AzContext
        If (!($context -eq $SubscriptionID)) {
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
            Write-host $CollectionOfDisks[0]
            return $CollectionOfDisks
        }else{
            write-host ":: Returning 0 disks"
            return $false
        }
    }
}
Function ShowDisks{
    Param (
        [parameter(Mandatory)]
        $selectedSubscriptionID
    )    
    $disks=GetUnattachedDisks $selectedSubscriptionID.ID 
    If (!($disks)){
        Write-host "No disks found"
        return $false
    }else{
        #Write-host "This lists shows all the disks and their number"
        #Write-host "Please type the number of a disk that needs a lock (or removed)"
        #Write-host "or press C to continue with the deletion of all non-locked disks"
        Foreach ($disk in $disks) {
            #Check if there is a lock - and if so, add lock icon to the list of disks
            $locked=ResourceLocked $disk
            $i=0
            Write-host ("[" + $i + "] " + $disk.name + " in resourceGroup " + $disk.ResourceGroupName ) -NoNewline
            If ($locked) {
                Write-host -ForegroundColor Green "  - LOCKED"
            }else{
                Write-host -ForegroundColor Red "  -*-"
            }
            $i++
        }
        return $disks
    }
}
### SCRIPT PART ###
If ($Log){
    $date=(Get-Date).ToString("d-M-y-h.m.s")
    $logname = ("AzureCleanLog-" + $date + ".log")
    New-Item -Path $pwd.path -Value $LogName -ItemType File
    $LogfileActivated=$pwd.path + "\" + $LogName
    ActivateDebug
} #Activating DEBUG MODE


Try {
	Import-Module Az.Compute
	}
	catch {
	Write-Host 'Modules NOT LOADED - EXITING'
	Exit
}

If (-not ($Login)) {AZConnect}
$selectedSubscriptions = New-Object System.Collections.ArrayList

#First lets run through the subscriptions
If (!($SubscriptionID)){
    $AvailableSubscription=GetSubscriptions
    Foreach ($subscription in $AvailableSubscription) {
        #ask if it should be included
        $title = $subscription.subscriptionname
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
                Write-host ($subscription.subscriptionname + " has been added")
            } 
            1 {Write-host ($subscription.subscriptionname + " will be skipped")
            }
        }
    }
    Write-Host ""
    Write-Host "------------------------------------------------------"
    Write-Host "Subscriptions selected:" -ForegroundColor Yellow
}else{
    Write-host "Getting subscription"
    $CustomSubscription=Get-AzSubscription -SubscriptionId $SubscriptionID
    $selectedSubscriptionID=$CustomSubscription
    $selectedSubscriptions.Add($CustomSubscription)
}

#All Subscriptions are now avaiable in my array: $selectedSubscriptions
#Need to create a list of disks to be able to apply locks

#Select disks, NICs or IP's
write-host ("using subscription:" + $selectedSubscriptionID.ID)
write-host "Which resource type should be targgetted"
$SelectedObjectType = Read-Host -Prompt 'D[DISK], N[NICs], I[Public IP]'
Switch ($SelectedObjectType.ToUpper()) {
    "D" {$Resource=ShowDisks $selectedSubscriptionID}
    "N" {$Resource=ShowNICs $selectedSubscriptionID}
    "I" {$Resource=ShowNICs $selectedSubscriptionID }
}
    DO {
        $SelectedObject = Read-Host -Prompt 'Type the number to be selected, R [Refresh] or Q [QUIT]'
        Write-host $SelectedObject.ToLower()
        ($SelectedObject -is [int] )
        Write-host $SelectedObject.GetType()
        If (($SelectedObject.ToLower() -ne "q" -or $SelectedObject.ToLower() -eq 'r') -and $SelectedObject -match '\d' ) {
            #Disk selected is #SelectedObject
            $ObjectAction = Read-Host -Prompt 'type L (LOCK), U (UNLOCK), R[REFRESH], or C (CONTINUE)'
            Switch ($ObjectAction.ToUpper()){
                "L" {
                    Write-host ("Applying lock to:" + $Resource[$SelectedObject].Name + " in resource group: " + $Resource[$SelectedObject].ResourceGroupName)
                    #$Lock=ApplyResourceLock $Resource[$SelectedObject]
                }
                "U"{
                    Write-host ("Trying to remove lock from: " + $Resource[$SelectedObject].Name + " in resource group: " + $Resource[$SelectedObject].ResourceGroupName)
                    #$Lock=RemoveResourceLock $Resource[$SelectedObject]
                }
                "R"{
                    Switch ($SelectedObjectType.ToUpper()) {
                        "D" {$Resource=ShowDisks $selectedSubscriptionID}
                        "N" {$Resource=ShowNICs $selectedSubscriptionID}
                        "I" {$Resource=ShowNICs $selectedSubscriptionID}
                    }
                }
                "C"{
                    Write-host "continue"
                    break
                }
            }

        }elseif ($SelectedObject.ToLower() -eq "q") {
            #QUIT
            Exit-PSHostProcess
        }elseif ($SelectedObject.ToLower() -eq "r"){
            #need to refresh
            Switch ($SelectedObjectType.ToUpper()) {
                "D" {$Resource=ShowDisks $selectedSubscriptionID}
                "N" {$Resource=ShowNICs $selectedSubscriptionID}
                "I" {$Resource=ShowNICs $selectedSubscriptionID}
            }
        }

    }while ($break -ne $true)