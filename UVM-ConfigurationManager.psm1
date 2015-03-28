# UVM Configuraiton Manager Module
# Functions use "SMS" prefix to avoid collision with Microsoft Configuration Manager cmdlets (which use "CM" prefix).

#History:
#  2015-02-19 - Created, added SMSProviderNamespace and SMSObject, SMSFullObject, and SMSClass cmdlets.
#  2015-03-12 - Added SMSSiteNamespace and Add/Get/Remove/Test SMSTSStep cmdlets.  Bug fixes.
Set-PSDebug -Strict

function Add-SMSTSStep {
    param (
        [Parameter(Mandatory=$true)][System.Management.ManagementBaseObject]$TSStep,
        [Parameter(Mandatory=$true)][System.Management.ManagementBaseObject]$TSObject,
        [int32]$StepIndex = 2147483647
    )
    # Adds the Task Sequence Step (which can be wither an Action or Group) specified in 
    #   $TSNewStep to the Task Sequencw or Task Sequence Group supplied in $TSObject. If 
    #   specified, the step will be added at the index localtion specified in $TSStepIndex.
    #   Otherwise, the step will be appended the end of the sequence or group.

    [System.Management.ManagementBaseObject[]]$newSteps = @()
    #Kludge: The max TS step index could not get this hight without crashing the TS:
    if ($StepIndex -eq 2147483647) { 
        $TSObject.steps += $TSStep
    } else {
        [int32]$i = 0
        foreach ($step in $TSObject.steps) {
            if ($i -eq $StepIndex) {
                $newSteps += $TSStep
            }
            $newSteps += $step
            $i ++
        }
        $TSObject.steps = $newSteps
    }
    return $TSObject
    $TSObject.Dispose()
}

function Get-SMSSiteNamespace {
    #Returns the namespace for the SMS Site on the local server.  
    #  Useful for Get-WMIObject commands.
    $SMSPN = Get-SMSProviderNamespace
    [string]$namespace = $SMSPN.Substring(($SMSPN.IndexOf('\root') + 1))
    return $namespace
}

function Get-SMSProviderNamespace {
    # Returns the SMS_ProviderLocation NamespacePath string on the local server.  
    #   Useful when calling SMS objects by their full path using the [wmi]$smsObjectPath constructor.
    $SMSPL = Get-WmiObject -Query "select * from sms_providerlocation" -Namespace root/sms
    return $SMSPL.NamespacePath
    $SMSPL.Dispose()
}

function Get-SMSSiteCode {
    $SMSPL = Get-WmiObject -Query "select * from sms_providerlocation" -Namespace root/sms
    return $SMSPL.SiteCode
    $SMSPL.Dispose()
}

function Get-SMSFullObject {
    param (
        [string]$namespace = (Get-SMSSiteNamespace),
        [Parameter(Mandatory=$true)][string]$class,
        [Parameter(Mandatory=$true)][string]$filter
    )
    #Do a WMI query to retrieve a specific WMI object.  The "filter" must be constructed to return only one result:
    $looseObject = Get-WmiObject -namespace $namespace -class $class -filter $filter
    #Directly retrieve the object that was queried for above.  The resultanat object will have all properties available.
    return [wmi] $looseObject.__Path
    $looseObject.Dispose()
}

function Get-SMSTSStepIndex {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][System.Management.ManagementBaseObject]$TSObject,
        [Parameter(Mandatory=$true)][string]$TSStepName
    )
    [int]$index = 0
    [bool]$found = $false
    foreach ($step in $TSObject.steps) {
        if (($step.Name -eq $TSStepName) -and (($step.__DYNASTY -eq "SMS_TaskSequence_Step") -or ($step.__DYNASTY -eq "SMS_TaskSequence"))) {
            $found = $true
            break
        }
        $index ++
    }
    if ($found) {
        return $index
    } else {
        throw [string]$("Step with name '$TSStepName' was not found in the specified TaskSequence object '" + $TSObject.name + "'.")
    }
    $TSObject.Dispose()
}

function New-SMSClass {
    param (
        [Parameter(Mandatory=$false)][wmi]$smsObject,
        [Parameter(Mandatory=$false)][string]$smsClass
    )
    if ($smsClass) {
        [string] $classPath = (Get-SMSProviderNameSpace) + ':' + $smsClass
    } elseif ($smsObject) {
        [string] $classPath = $smsObject.__NAMESPACE + ':' + $smsObject.__CLASS
    } else {
        Write-Host "Get-SMSClass requires either an SMS Object (-smsObject) or an SMS Class Name (-class) as input"
    }
    if ($classpath) {
        try {
            $outClass = [wmiclass] $classPath
        } catch [System.Management.Automation.RuntimeException] {
            Write-Host "An error occurred."
            Write-Host ""
            Write-Host "Perhaps you did not provide a valid class name? Try running the following command for a full list of valid classes: "
            Write-Host $([string]'Get-WmiObject -list -Namespace $namespace | select -property name | Sort-Object -Property name | ? -Property name -match ' + "'" + 'SMS_|BDD_' + "'")
        }
        return $outClass
        $outClass.Dispose()
    }
}

function New-SMSObject {
    param (
        [string]$namespace = (Get-SMSProviderNamespace),
        [Parameter(Mandatory=$true)][string]$class
    )
    [string] $wmiPath = $namespace + ':' + $class
    $wmiClass = [wmiclass] $wmiPath
    return $wmiClass.CreateInstance()
}

function Remove-SMSTSStep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][System.Management.ManagementBaseObject]$TSObject,
        [Parameter(Mandatory=$true)][string]$TSStepName
    )
    # Removes the first instance of a Task Sequence Step with the .name attribute matchine the import param $TSStepName.
    #   Intent was to return a new object with the step removed, but the script modifies the input object as-is owing to some incomprehensible 
    #   linkage between the function object $TSObject and the supplied input object.  Seems like a scope violation, but I guess that's just WMI.
    # Requires:
    #   $TSObject - An ManagementBaseObject that must be of the SMS_TaskSequence or SMS_TaskSequence_Group class.  Must contain a "steps" property.
    #   $TSStepName - Must be the full name of the TSStep or TSGroup to be removed from the TSSteps object.
    # Returns:
    #   A new TSObject with the first instance of the specified step removed.
    [bool]$found = $false
    foreach ($step in $TSObject.steps) {
        if (($step.Name -eq $TSStepName) -and (($step.__DYNASTY -eq "SMS_TaskSequence_Step") -or ($step.__DYNASTY -eq "SMS_TaskSequence"))) {
            $killStep = $step
            $found = $true
            break
        }
    }
    if ($found) {
        #-- This will not work because the Array is of fixed length.  The remove method is present but does not actually work:
        #$groupSteps.Remove($killStep)
        #-- This does work, but I can't really see why.  It is nice compact code, but I cannot bring myself to trust it: 
        #$newSteps = $postInstTSGroup.steps -ne $killStep

        #-- The following works... note that we have to cast $newSteps as an array of managementBaseObjects, otherwise we
        #   will get casting error that 'PSObject' cannot be cast to type 'ManagementBaseObject'.  
        [System.Management.ManagementBaseObject[]]$newSteps = $TSObject.steps | ? {$_.Name -ne $killStep.Name}
        #Use local scope in case there is a global $newSteps.  PowerShell should prefer local, but I like to play it safe.
        $TSObject.steps = $local:newSteps
        return $TSObject
        $killStep.Dispose()
    } else {
        throw "Specified step was not found within the task sequence object."
    }
    $TSObject.Dispose()
}

function Test-SMSTSStep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][System.Management.ManagementBaseObject]$TSObject,
        [Parameter(Mandatory=$true)][string]$TSStepName
    )
    # Tests the input $TSObject (which needs to be of Class SMS_TaskSequence or SMS_TaskSequenceGroup) for a 
    #    step with a .name attribute matching the string parameter $TSStepName.
    # Returns: A Boolean $true or $false.
    [bool] $found = $false
    foreach ($step in $TSObject.steps) {
        if (($step.Name -eq $TSStepName) -and (($step.__DYNASTY -eq "SMS_TaskSequence_Step") -or ($step.__DYNASTY -eq "SMS_TaskSequence"))) {
            $found = $true
            break
        }
    }
    return $found
}

Export-ModuleMember -Function Add-SMSTSStep, Get-SMSProviderNameSpace, Get-SMSSiteNamespace, Get-SMSSiteCode, Get-SMSFullObject, Get-SMSTSStepIndex, New-SMSClass, New-SMSObject, Remove-SMSTSStep, Test-SMSTSStep