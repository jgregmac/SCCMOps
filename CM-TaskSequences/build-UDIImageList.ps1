# build-UDIImageList.ps1
# J. Greg Mackinnon
# Created: 2015-01-26
# Updated: 2015-03-17 - Added host output to indicate task progress.
# Populates the UDI Configuration Wizard XML file with all Operating System images gathered from
# Configuration Manager.  
# Requires: a local installation of the Configuration Manager administration tools.
#   Modify $udiXmlIn, $udiXmlOut, $CMSiteCode, and $CMBinPath to match your environment.

[string] $udiXmlIn = 'O:\sources\os\mdt\files\Scripts\UDIWizard_Config.xml'
[string] $udiXmlOut = 'O:\sources\os\mdt\files\Scripts\UDIWizard_Config.xml'


[string] $CMSiteCode = 'UVM'

[string] $CMBinPath = 'F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\'
[string] $CMModName = 'ConfigurationManager.psd1'
[string] $CMModPath = Join-Path -Path $CMBinPath -ChildPath $CMModName

[string] $CMDrive = $CMSiteCode + ':\'

Import-Module -Name $CMModPath | Out-Null

Push-Location $CMDrive

write-host "Gathering OS Images from SCCM..." -ForegroundColor Yellow
$osImages = Get-CMOperatingSystemImage | select -Property Name,ImageProperty

write-host "Loading the current UDI Wizard configuration file..." -ForegroundColor Yellow
[xml]$udiXml = Get-Content $udiXmlIn
$dataElement = ($udixml.wizard.pages.page | ? -Property Name -eq 'VolumePage').data
# XPath variation, not working for some reason:
#$imgSel = $udiXml.SelectNodes("wizard/pages/page[@Name=""VolumePage""]")

#Clear the existing Nodes:
$dataElement.RemoveAll()
#Add the name/Imageselection attribute back in to the element:
$dataElement.SetAttribute('Name','ImageSelection')

write-host
foreach ($image in $osImages) {
    #Create a new DataItem element for each OS Image:
    $dataItemElement = $udiXml.CreateElement('DataItem')
    $dataElement.AppendChild($dataItemElement) | out-null

    # Read information from the existing image:
    [xml]$imageXml = $image.ImageProperty
    [string]$ImageName = $image.Name
    [string]$Index = $imageXml.WIM.IMAGE.Index
    [string]$archNumber = ($imageXml.WIM.IMAGE.Property | ? -Property Name -eq 'Architecture').'#text'
    if ($archNumber -eq '9') {
        [string]$Architecture = 'amd64'
    } elseif ($archNumber -eq '0') {
        [string]$Architecture = 'x86'
    } else {
        [string]$Architecture = ''
    }
    #The UDI DisplayName value does not need to be tied to a property in SCCM, 
    # but we will use the matching Display Name in the SCCM GUI, which is mapped out below:
    [string]$DisplayName = $imageXml.WIM.IMAGE.name
    
    write-host "Adding image named: $DisplayName" -ForegroundColor Yellow

    #Add collected image info to a new array
    [array[]]$setters = @(
        @('DisplayName', $DisplayName),
        @('Index', $Index),
        @('Architecture', $Architecture),
        @('ImageName', $ImageName)
    )

    #Now feed data from the info array as "setter" elements under the "DataItem" element:
    foreach ($setter in $setters) {
        write-host "    Adding element: '"$setter[0]"' with property '"$setter[1]"'" -ForegroundColor cyan
        $setterElement = $udiXml.CreateElement('Setter')
        $setterElement.SetAttribute('Property',$setter[0])
        $setterElement.InnerText = $setter[1]
        $dataItemElement.AppendChild($setterElement) | out-null
    }
}

$udiXml.Save($udiXmlOut)

Pop-Location


