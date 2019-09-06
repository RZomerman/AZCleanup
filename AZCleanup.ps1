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
            Write-host "RES"
            $CollectionOfDisks=get-azdisk | where {($_.DiskState -eq 'Unattached') -and ($_.ResourceGroupName -eq $ResourceGroup)} 
        }else{
            #get all unattached disks
            Write-host "ALL"
            $CollectionOfDisks=get-azdisk | where {$_.DiskState -eq 'Unattached'}
        }

        #Check if there are any disks in the collection... 
        If (($CollectionOfDisks) -and ($CollectionOfDisks.count -gt 0)) {
            return $CollectionOfDisks
        }else{
            return 0
        }
    }
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
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$true)][string]$Resource)
    #Checks if a lock exists on a resource prior to deleting it
    $ResourceType=($Resource.ID -split "/providers" | select -Last 1) -split ("/" + $Resource.Name) | select -first 1 
        $Lock=Get-AzResourceLock -ResourceName $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $ResourceType
        return $lock
}

Function ApplyResourceLock {
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$true)][string]$Resource)
    #This Function is used to set a lock on a resource. Validate the lock exist and return the lock name. 
    $Account=(Get-AzContext).Account.id
    $ResourceType=($Resource.ID -split "/providers" | select -Last 1) -split ("/" + $Resource.Name) | select -first 1 
    Set-AzResourceLock -LockLevel CanNotDelete -LockName "NoDelete" -LockNotes ("added by cleanup script: " + $Account) -ResourceName $Resource.Name -ResourceType $ResourceType -ResourceGroupName $Resource.ResourceGroupName  
    $Lock=Get-AzResourceLock -ResourceName $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $ResourceType
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
    $CustomSubscription=Get-AzSubscription -SubscriptionId $SubscriptionID
    $selectedSubscriptions.Add($CustomSubscription)
}

#All Subscriptions are now avaiable in my array: $selectedSubscriptions

ForEach ($selectedSubscriptionID in $selectedSubscriptions ) {
    $disks=GetUnattachedDisks $selectedSubscriptionID.ID 
    Foreach ($d in $disks) {
        Write-host $d.name
    }
}