# Update-OSApplyTaskSequence:
# Created 2015-03-09, by J. Greg Mackinnon
# Updated 2015-03-12 - Added ability to update an existing, full OS installation Task Sequence.
#                    - Also removes pre-existing "Apply Apply Operating System Image " step.  

# Script will update the SCCM Task Sequence named in the $TSPackageName variable with a conditional 
# "Apply OS Image" step for each OS currently defined in SCCM.  

# Why?  Because unless all of your OS images are contained within a single WIM file, the SCCM deployment
# sequence will ignore any OS Image selection that you make in UDI.  Instead, we will have to rely on 
# UDI to set the "OSDImageName", and we will apply OS images based on that information.  
# NOTE: We are ASSUMING one image per WIM file, so the image index value will always be set to "1".

#WMI Classes associated with CM Task Sequences (that are relevant to us):
#   SMS_TaskSequencePackage                <-- The master Task Sequence object
#   SMS_TaskSequence                       <-- Each Task Sequence Package has one of these.
#   SMS_TaskSequence_Group                 <-- Logical groups of actions in the sequence.
#   SMS_TaskSequence_Condition             <-- A condition that can be attached to an action or group
#      SMS_TaskSequence_WMIConditionExpression        <-- Use "Model" MDT TS Variable instead!
#      SMS_TaskSequence_MakeModelConditionExpression  <-- Does not exist in the GUI! Do not use!
#      SMS_TaskSequence_VariableConditionExpression   <-- Condition based on a TS variable.
#      SMS_TaskSequence_ApplyOperatingSystemAction    <-- Apply an Operating System Image

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

######## Begin Site-Specific Settings: ########
#Name of the TaskSequence to configure (must already exist):
[string]$TSPackageName = $name

#Name of the MDT Settings Package that contains the unattend.xml file to be used during deployment:
[string] $MDTSettingsName = 'MDT 2013 Settings'

#Name of the new Apply OS Images Group to be applied to the Task Sequence:
[string]$TSGroupName = 'UVM Apply Operating System Image Group'
######### End Site-Specific Settings: #########

Import-Module 'c:\local\scripts\UVM-ConfigurationManager.psm1'

#Set default value for $namespace, if not provided as a parameter:
if ((-not (Test-Path Variable:\namespace)) -or !$namespace) {[string]$namespace = Get-SMSSiteNamespace}

########################################################
########## Begin Create New OS Apply TS Group ##########
# Get the Name and PackageID for all OS image packages currently defined in SCCM, and put them into an array:
[array]$OSPackages = @()
$OSPackages = Get-WmiObject -Namespace $namespace -Query "Select Name,PackageID from SMS_ImagePackage" | Select-Object -Property Name,PackageID | Sort-Object -Property Name 
#Instantiate a new, empty TS Group:
$newTSGroup = New-SMSObject -class SMS_TaskSequence_Group
#Configure the group:
$newTSGroup.Name = $TSGroupName
$newTSGroup.Description = "Copy this group into a task sequence to replace all pre-existing 'Apply Operating System Image' actions."
#Get the PackageID for our MDT Settings Package.  We will need this later when defining the "Apply Operating System Image" TS Step:
[string] $MDTSettingsID = $(Get-WmiObject  -namespace $namespace -query "Select PackageID from SMS_Package where NAME = '$MDTSettingsName'").PackageID
foreach ($package in $OSPackages) {
    #Add an action to run each Apply Operating System Image Action:
    $ApplyOSTSAction = New-SMSObject -class SMS_TaskSequence_ApplyOperatingSystemAction
    $ApplyOSTSAction.Name = ("Apply OS Package: " + $package.name)
    $ApplyOSTSAction.ConfigFileName = "unattend.xml"
    $ApplyOSTSAction.ConfigFilePackage = $MDTSettingsID
    $ApplyOSTSAction.Description = "Conditionally applies this OS Image Package to the local drive."
    $ApplyOSTSAction.DestinationVariable = "OSDisk"
    $ApplyOSTSAction.ImagePackageID = $package.PackageID
    $ApplyOSTSAction.ImageIndex = "1"
    #Create a Task Sequence Condition object:
    $TSCondition = New-SMSObject -namespace $namespace -class SMS_TaskSequence_Condition
    #Create a Task Sequence Condition Expression object:
    $TSConditionExp = New-SMSObject -namespace $namespace -class SMS_TaskSequence_VariableConditionExpression
    $TSConditionExp.Operator = "equals"
    $TSConditionExp.Value = $package.name
    $TSConditionExp.Variable = "OSDImageName"
    #Add the condition expression to the "operands" attribute of the condition object:
    $TSCondition.Operands = @($TSConditionExp) #  Multiple conditions are possible, use an array.
    #Add the Condition object to the condition attribute of the Group object:
    $ApplyOSTSAction.Condition = $TSCondition #  Only one condition, not an array.
    $TSConditionExp.Dispose()
    $TSCondition.Dispose()
    $newTSGroup.Steps += @($ApplyOSTSAction)
}
########### End Create New OS Apply TS Group ###########
########################################################

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
[int32]$instIndex = Get-SMSTSStepIndex -TSObject $ExeTSGroup -TSStepName 'Install'
$instTSGroup = $ExeTSGroup.steps[$instIndex]

#Remove the existing "Apply OS Image" step, if it exists:
[string]$osApplyStepName = 'Apply Operating System Image'
if (Test-SMSTSStep -TSObject $instTSGroup -TSStepName $osApplyStepName) {
    Remove-SMSTSStep -TSObject $instTSGroup -TSStepName $osApplyStepName
}

#Remove the existing UVM Driver Group (if it exists):
if (Test-SMSTSStep -TSObject $instTSGroup -TSStepName $TSGroupName) {
    Remove-SMSTSStep -TSObject $instTSGroup -TSStepName $TSGroupName
}

#Identify the position within the task sequence group where we will add our new UVM OS Apply Group:
[int]$i = [int]$(Get-SMSTSStepIndex -TSObject $instTSGroup -TSStepName 'Set Variable for Drive Letter') + 1

#Add the new OS Apply Group to the Install Group after the position discovered in the previous step:
Add-SMSTSStep -TSObject $instTSGroup -TSStep $NewTSGroup -StepIndex $i
$newTSGroup.Dispose()

#Walk back up the task sequence tree, updating each parent group with the revised child groups:
Remove-SMSTSStep -TSObject $ExeTSGroup -TSStepName $instTSGroup.Name
Add-SMSTSStep -TSObject $ExeTSGroup -TSStep $instTSGroup -StepIndex $instIndex
$instTSGroup.Dispose()
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