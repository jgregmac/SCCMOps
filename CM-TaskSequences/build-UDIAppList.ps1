# build-UDIImageList.ps1
# J. Greg Mackinnon
# Created: 2015-01-26
# Updated: 2015-03-17 - Added host output to indicate task progress.  Removed block comments for blogging clarity.
# Populates the UDI Configuration Wizard XML APP file with all categorized applications gathered 
# from Configuration Manager.  
# Requires: a local installation of the Configuration Manager administration tools.
#   Modify $outPath, $CMSiteCode, and $CMBinPath to match your environment.
Set-PSDebug -Strict

[string] $outPath = 'O:\sources\os\mdt\files\Scripts\UDIWizard_Config.xml.app'

[string] $CMSiteCode = 'UVM'
[string] $CMBinPath = 'F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\'
[string] $CMModName = 'ConfigurationManager.psd1'
[string] $CMModPath = Join-Path -Path $CMBinPath -ChildPath $CMModName

[string] $CMDrive = $CMSiteCode + ':\'

Import-Module -Name $CMModPath | out-null
Push-Location $CMDrive

#Gather current "Administrative Categories" used to classify Applications, capture to an Array of strings:
write-host "Gathering Application Categories..."
[String[]] $CMAppGroups = Get-CMCategory -CategoryType AppCategories | % {$_.LocalizedCategoryInstanceName}

[int] $appCount = 1

# Output XML requires: 
    # DisplayName (map to LocalizedDisplayName)
    # Name, 
    # Guid (with ScopeID, ApplicationGUID... maps to "ModelName" CMApplication Property), 
    # description (optional? map to LocalizedDescription), 
    # type (deployment type?), 
    # ProductID (which can be found in the sdmpackagexml.deploymenttypes[#].installer.productcode)
# All separated into "ApplicationGroup" stanzas, with name= attributes, I think we can map this to "LocalizedCategoryInstanceNames"


#$xmlDoc = New-Object System.Xml.XmlDocument # Note this is the same as the [xml] type accelerator
$utf8 = New-Object System.Text.UTF8Encoding
# Create The Document Writer:
$XmlWriter = New-Object System.XMl.XmlTextWriter($outPath,$utf8)
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "5"
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement("Applications")
$xmlWriter.WriteAttributeString('RootDisplayName','Applications')

write-host "Gathering CM Applications..."
$CMApps = Get-CMApplication | Select-Object -Property LocalizedDisplayName,LocalizedDescription,ModelName,LocalizedCategoryInstanceNames,IsLatest,IsExpired,IsSuperseded,SDMPackageXML | ? {$_.IsLatest -and ($_.IsExpired -eq $false) -and ($_.IsSuperseded -eq $false)}

write-host
foreach ($group in $CMAppGroups) {
    $xmlWriter.WriteStartElement('ApplicationGroup')
    $xmlWriter.WriteAttributeString('Name',$group)
    write-host "Processing group: $group" -ForegroundColor yellow
    
    foreach ($app in $CMApps) {
        if ($app.LocalizedCategoryInstanceNames.contains($group)) {
            write-host "    Adding application " $app.LocalizedDisplayName -ForegroundColor cyan
            $xmlWriter.WriteStartElement('Application')
            $xmlWriter.WriteAttributeString('DisplayName',$app.LocalizedDisplayName)
            $xmlWriter.WriteAttributeString('State','enabled')
            $xmlWriter.WriteAttributeString('Id',[string]$appCount)
            $xmlWriter.WriteAttributeString('Name',$app.LocalizedDisplayName)
            $xmlWriter.WriteAttributeString('Guid',$app.ModelName)

            $appXml = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::Deserialize($app.SDMPackageXML,$true)

                $xmlWriter.WriteStartElement('Setter')
                $xmlWriter.WriteAttributeString('Property','description')
                $xmlWriter.WriteEndElement()

                $xmlWriter.WriteStartElement('Dependencies')
                $xmlWriter.WriteEndElement()

                $xmlWriter.WriteStartElement('Filters')
                $xmlWriter.WriteEndElement()

                $xmlWriter.WriteStartElement('ApplicationMappings')
                
                    $xmlWriter.WriteStartElement('Match')           
                    $xmlWriter.WriteAttributeString('Type','WMI')
                    $xmlWriter.WriteAttributeString('OperatorCondition','OR')
                    $xmlWriter.WriteAttributeString('DisplayName',$app.LocalizedDisplayName)
                        $xmlWriter.WriteStartElement('Setter')
                        $xmlWriter.WriteAttributeString('Property','Name')
                            $xmlWriter.WriteString($app.LocalizedDisplayName)
                        $xmlWriter.WriteEndElement() # <-- End Setter
                    $xmlWriter.WriteEndElement() # <-- End Match
                    foreach ($type in $appXml.DeploymentTypes) {
                        $xmlWriter.WriteStartElement('Match')
                        $xmlWriter.WriteAttributeString('Type','MSI')
                        $xmlWriter.WriteAttributeString('OperatorCondition','OR')
                        $xmlWriter.WriteAttributeString('DisplayName',$app.LocalizedDisplayName)
                            $xmlWriter.WriteStartElement('Setter')
                            $xmlWriter.WriteAttributeString('Property','ProductId')
                                if ($type.Installer.Technology -match 'MSI') {
                                    $xmlWriter.WriteString($type.Installer.ProductCode)
                                } else {
                                    $xmlWriter.WriteString(' ')
                                }
                            $xmlWriter.WriteEndElement() # <-- End Setter
                        $xmlWriter.WriteEndElement() # <-- End Match
                    }
                $xmlWriter.writeEndElement() # <-- End ApplicationMappings

            $xmlWriter.WriteEndElement() # <-- End Application
            $appCount++ # Increment the appCount by one for use in the "ID" Application element property.
        }
    }
    $XmlWriter.WriteEndElement() # <-- End ApplicationGroup
}

$xmlWriter.WriteEndElement() # <-- End Application
$xmlWriter.WriteEndDocument() # <-- End XML Document
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close()

Pop-Location
