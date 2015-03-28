# Update-DriverInjectionTaskSequence:
# Created 2015-02-19, by J. Greg Mackinnon
# Updated 2015-03-12 - Added ability to update an existing, full OS installation Task Sequence.
#                    - Also removes pre-existing "AutoApplyDrivers" step.  

# Script will update the SCCM Task Sequence named in the mandatory $name parameter. It will add conditional 
# driver package application steps.  One step will be generated for each supported OS/model combination.
# If a driver cannot be found for a "higher level" OS (i.e. Windows 8), the script will attempt to locate
# a "lower level" OS driver package for that model instead (i.e. Windows 7).
# Additionally, supported "peripheral" drivers will be installed for all systems.
# If no matching driver package is detected, an "AutoApplyDrivers" task sequence step will be executed.

# WMI Classes associated with CM Task Sequences (that are relevant to us):
#   SMS_TaskSequencePackage                        <-- The master Task Sequence object
#   SMS_TaskSequence                               <-- Each Task Sequence Package has one of these.
#   SMS_TaskSequence_Group                         <-- Logical groups of actions in the sequence.
#   SMS_TaskSequence_Condition                     <-- A condition that can be attached to an action or group
#      SMS_TaskSequence_WMIConditionExpression        <-- Use "Model" MDT TS Variable instead!
#      SMS_TaskSequence_MakeModelConditionExpression  <-- Does not exist in the GUI! Do not use!
#      SMS_TaskSequence_VariableConditionExpression   <-- Condition based on a TS variable.
#   SMS_TaskSequence_ApplyDriverPackageAction
#   SMS_TaskSequence_AutoApplyAction               <-- Runs an "Auto Apply Drivers" action.

# See them all by running:
#    Get-WmiObject -list -Namespace $namespace | select -property name | ? -Property name -Match "SMS_TaskSequence"

# Helpful resources:
#    The authority... MSDN on programming task sequences (VBScript and C#):
#      https://msdn.microsoft.com/en-us/library/jj217977.aspx
#    Describes how to expand properties from SMS objects with "lazy" properties:
#      http://trevorsullivan.net/2010/09/28/powershell-configmgr-wmi-provider-feat-lazy-properties/
#    Describes using the [wmi] type accelerator to retrieve WMI objects by absolute path:
#      http://windowsitpro.com/scripting/type-accelerators-useful-undocumented-feature-powershell-10
#    Describes the difference between [wmi] and [wmiclass] objects:
#      http://tfl09.blogspot.com/2008/12/powershells-wmiclass-type-accelerator.html
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)][string]$name,
    [Parameter(Position=2)][string]$namespace
)
Set-PSDebug -Strict

#CM Server info:
#[string]$namespace = 'root\sms\site_' + $SiteCode

#Set the WQL-formatted filter which will return a specific WMI object (Task Sequence Package object):
[string]$TSPackageName = $name

#Specify the name of the Driver Injection Group to be added to the Task Sequence:
[string]$TSGroupName = 'UVM Driver Package Injection Group'

#Supported OS Versions:
[string[]]$OSList = @('Win7','Win8','Win10')

Import-Module 'c:\local\scripts\UVM-ConfigurationManager.psm1'

#Set default value for $namespace, if not provided as a parameter:
if ((-not (Test-Path Variable:\namespace)) -or !$namespace) {[string]$namespace = Get-SMSSiteNamespace}

# Get the Name and PackageID for all driver packages currently defined in SCCM, and put them into an array:
[array]$DPackages = @()
$DPackages = Get-WmiObject -Namespace $namespace -Query "Select Name,PackageID from SMS_DriverPackage" | Select-Object -Property Name,PackageID | Sort-Object -Property Name 

######################################################
########## Begin Create New Driver TS Group ##########
#Create a new Task Sequence Group:
$NewTSGroup = New-SMSObject -class SMS_TaskSequence_Group
$NewTSGroup.Name = $TSGroupName
$NewTSGroup.Description = "Copy this group into a task sequence to replace all pre-existing driver actions."
#Add an action to run the Package Detection script:
$PkgDetectTSAction = New-SMSObject -class SMS_TaskSequence_RunCommandLineAction
$PkgDetectTSAction.Name = "Run the Driver Package Detection Script"
$PkgDetectTSAction.Description = "Run a script to determine which (if any) driver package to apply to the operating " `
    + "system.  This script will set the 'UVMDriverPackageDetected' and 'UVMDriverPackage' variables."
$PkgDetectTSAction.CommandLine = 'cscript.exe %DeployRoot%\Scripts\ZUVMDetectDriverPackage.wsf'
#Create the "Apply Packages" Group":
$ApplyPkgsTSGroup = New-SMSObject -class SMS_TaskSequence_Group
$ApplyPkgsTSGroup.Name = "Apply Driver Packages Group"
$ApplyPkgsTSGroup.Description = "Apply the detected package group and other mandatory groups, if a package was detected."
$TSCondition = New-SMSObject -namespace $namespace -class SMS_TaskSequence_Condition
#Create a Task Sequence Condition Expression object:
$TSConditionExp = New-SMSObject -namespace $namespace -class SMS_TaskSequence_VariableConditionExpression
$TSConditionExp.Operator = "equals"
$TSConditionExp.Value = "YES"
$TSConditionExp.Variable = "UVMDriverPackageDetected"
#Add the condition expression to the "operands" attribute of the condition object:
$TSCondition.Operands = @($TSConditionExp) #  Multiple conditions are possile, use an array.
#Add the Condition object to the condition attribute of the Group object:
$ApplyPkgsTSGroup.Condition = $TSCondition #  Only one condition, not an array.
$TSConditionExp.Dispose()
$TSCondition.Dispose()
foreach ($package in $DPackages) {
    if ($package.name -notmatch '^Other|^WinPE') { # Exclude Other and WinPE packages... these are for "AutoApply" logic only.
        #Create a new Task Sequence Action object:
        $TSAction = New-SMSObject -namespace $namespace -class SMS_TaskSequence_ApplyDriverPackageAction
        #Set the required properties
        $TSAction.name = 'Apply the ' + $package.Name + ' Driver Packge'
        $TSAction.Description = "Conditionally install this driver package, if it matches the UVMDriverPackage TS Environment Variable."
        $TSAction.DriverPackageID = $package.PackageID
        $TSAction.UnsignedDriver = $true

        if ($package.name -notmatch '^Peripherals'){ # Exclude conditional logic for peripherals, because we want all systems to get these. 
            #Create a Task Sequence Condition object:
            $TSCondition = New-SMSObject -namespace $namespace -class SMS_TaskSequence_Condition
            #Create a Task Sequence Condition Expression object:
            $TSConditionExp = New-SMSObject -namespace $namespace -class SMS_TaskSequence_VariableConditionExpression
            $TSConditionExp.Operator = "equals"
            $TSConditionExp.Value = $package.Name
            $TSConditionExp.Variable = "UVMDriverPackage"
            #Add the condition expression to the "operands" attribute of the condition object:
            $TSCondition.Operands = @($TSConditionExp) #  Multiple conditions are possible, use an array.
            #Add the Condition object to the condition attribute of the Action object:
            $TSAction.Condition = $TSCondition #  Only one condition, not an array.
            $TSConditionExp.Dispose()
            $TSCondition.Dispose()
        }
        #Add the TS Action to the parent TS Group:
        $ApplyPkgsTSGroup.Steps += @($TSAction)
        $TSAction.Dispose()
    }
}
#Create the "Auto Apply Drivers" Step":
$AutoApplyTSAction = New-SMSObject -class SMS_TaskSequence_AutoApplyAction
$AutoApplyTSAction.Name = "Auto Apply Drivers Action"
$AutoApplyTSAction.Description = "Automatically apply all matching drivers, ONLY IF a matching driver package was not detected."
$AutoApplyTSAction.UnsignedDriver = $true
$TSCondition = New-SMSObject -namespace $namespace -class SMS_TaskSequence_Condition
#Create a Task Sequence Condition Expression object:
$TSConditionExp = New-SMSObject -namespace $namespace -class SMS_TaskSequence_VariableConditionExpression
$TSConditionExp.Operator = "equals"
$TSConditionExp.Value = "NO"
$TSConditionExp.Variable = "UVMDriverPackageDetected"
#Add the condition expression to the "operands" attribute of the condition object:
$TSCondition.Operands = @($TSConditionExp) #  Multiple conditions are possible, use an array.
#Add the Condition object to the condition attribute of the Group object:
$AutoApplyTSAction.Condition = $TSCondition # Only one condition, not an array.
$TSConditionExp.Dispose()
$TSCondition.Dispose()
#Put the Apply Packages Group into the Root Group:
$NewTSGroup.Steps = @($PkgDetectTSAction,$ApplyPkgsTSGroup,$AutoApplyTSAction)
$PkgDetectTSAction.Dispose()
$ApplyPkgsTSGroup.Dispose()
$AutoApplyTSAction.Dispose()
########### End Create New Driver TS Group ###########
######################################################


######################################################
############# Begin Retrieve Existing TS #############
#Run the WQL queries required to get the fully-populated Task Sequence Package object (no loosely bound parameters)
[string]$filter = "name = '" + $TSPackageName + "'"
$TSP = Get-SMSFullObject -namespace $namespace -class SMS_TaskSequencePackage -filter $filter
#Get a class object for the object retrieved above.  This will allow access to static properties and methods not available in individual WMI objects.
$TSPClass = New-SMSClass -smsObject $TSP 
#For Task Sequence Packages, the GetSequence method allows us to get the sequence associated with a package.
#(Under CM 2012, each Package has one (and only one) Task Sequence)
#  Q: Why do this? The WMI object retrieved above already has a property "sequence", which contains all groups/steps in XML format.  Why can't we use that?
#  A: Because this is XML data that will be challenging to manipulate!  CM has separate classes for more controlled TS step manipulation.
#Note1: Interestingly, the retrieved object as a property "TaskSequence", which is the actual Task Sequence.  WHY!?!?!
#Note2: We also could use "New-SMSObject" to create an entirely new Task Sequence.
$TS = $TSPClass.GetSequence($TSP).TaskSequence
############## End Retrieve Existing TS ##############
######################################################

#Locate the Task Sequence items that need to be modified:
[int32]$exeIndex = Get-SMSTSStepIndex -TSObject $TS -TSStepName 'Execute Task Sequence'
$ExeTSGroup = $TS.steps[$exeIndex]
[int32]$postIndex = Get-SMSTSStepIndex -TSObject $ExeTSGroup -TSStepName 'PostInstall'
$postInstTSGroup = $ExeTSGroup.steps[$postIndex]

#Remove the existing "Auto Apply Drivers" step, if it exists:
[string]$autoApplyStepName = 'Auto Apply Drivers'
if (Test-SMSTSStep -TSObject $postInstTSGroup -TSStepName $autoApplyStepName) {
    Remove-SMSTSStep -TSObject $postInstTSGroup -TSStepName $autoApplyStepName
}   

#Remove the existing UVM Driver Group (if it exists):
if (Test-SMSTSStep -TSObject $postInstTSGroup -TSStepName $TSGroupName) {
    Remove-SMSTSStep -TSObject $postInstTSGroup -TSStepName $TSGroupName
}

#Identify the position within the task sequence group where we will add our new UVM Driver Group:
[int]$i = [int]$(Get-SMSTSStepIndex -TSObject $postInstTSGroup -TSStepName 'Configure') + 1

#Add the new TS Driver Group to the PostInstall Group after the position discovered in the previous step:
Add-SMSTSStep -TSObject $postInstTSGroup -TSStep $NewTSGroup -StepIndex $i
$NewTSGroup.Dispose()

#Walk back up the task sequence tree, updating each parent group with the revised child groups:
Remove-SMSTSStep -TSObject $ExeTSGroup -TSStepName $postInstTSGroup.Name
Add-SMSTSStep -TSObject $ExeTSGroup -TSStep $postInstTSGroup -StepIndex $postIndex
$postInstTSGroup.Dispose()
Remove-SMSTSStep -TSObject $TS -TSStepName $ExeTSGroup.Name 
Add-SMSTSStep -TSObject $TS -TSStep $ExeTSGroup -StepIndex $exeIndex
$ExeTSGroup.Dispose()

#The moment of truth...
#Use the Task Sequence Package class "SetSequence" method to add our new or updated sequence to the task sequence package object:
try {
    $TSPClass.SetSequence($TSP,$TS)
} catch  [System.Management.Automation.MethodInvocationException] {
    [string] $out = "Could not commit the Task Sequence to the Task Sequence Package. "
    $out += "Perhaps this Package is open for editing elsewhere? "
    $out += "Check the Management Point SMSProv.log for details. "
    Write-Error $out
}

#At this point, our Task Sequence has been updated, and the new steps will be available to clients!

# Dispose of all remaining objects: (Do we really need to do this?)
$TS.Dispose()
$TSP.Dispose()
$TSPClass.Dispose()
