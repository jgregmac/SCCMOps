# Build-UDIInfoFiles.ps1
# J. Greg Mackinnon, 2015-01-03
# Builds two files to be used by the zUVMDetectDriverPackage.wsf script that runs in WinPE during ZTI/UDI client installations.
#   YOU MUST ALSO RUN "build-UDIImageList.ps1" to ensure that the images in the UDI Wizard are identical to the images used by the zUVMSetDriverCategories script.
#   YOU MUST run this script after each run of the ImportDrivers.ps1 script.
# These are CSV files contain the following information gathered from Configuration Manager:
#   - a list of all current OS Images and a matching text string to indicate the major OS version.
#   - a list Driver Categories names, with matching Driver Category IDs.
# Requires: Configuration Manager administration tools (including CM PowerShell), and access to the SCCM server using WMI.
# Update $outFile to change the output file names ($outFile is defined twice in the script, rather unprofessionally, really).
# Update $CMSiteCode, $CMBinPath to run in a different server environment.

set-psdebug -strict

###############################################################################
######################### Start Build Driver Info File ########################
    #Build a CSV consisting of each SCCM Driver Category Name, and its corresponding UniqueID 
    [string] $computer = $env:COMPUTERNAME 
    [string] $CMSiteCode = 'UVM'

    [string] $CMBinPath = 'F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\'
    [string] $CMModName = 'ConfigurationManager.psd1'
    [string] $CMModPath = Join-Path -Path $CMBinPath -ChildPath $CMModName

    [string] $CMDrive = $CMSiteCode + ':\'

    # First output file - Driver Categories:
    [string] $outFile = 'O:\sources\os\mdt\files\Scripts\zUVM-DriverCategories.csv'

    #Cleanup existing file:
    if (Test-Path $outFile) {Remove-Item $outFile -Force -Confirm:$false}
    [string] $namespace = "root\SMS\site_" + $CMSiteCode
    
    #Note: Since we don't actually use the Category UniqueID anymore, a safer approach would be to import a list of SMS_DriverPackage objects instead:
    # Get-WmiObject -Namespace $namespace -Class SMS_DriverPackage -Property name | Select-Object -Property name | Sort-Object -Property name

    [string] $query = "select LocalizedCategoryInstanceName,CategoryInstance_UniqueID from sms_categoryinstance WHERE CategoryTypeName ='DriverCategories'"
    $wmiDriverCats = Get-WmiObject -ComputerName $computer -namespace $namespace -query $query | Sort-Object -Property LocalizedCategoryInstanceName

    #Generate CSV file with CategoryName,UniqueID:
    $driverCats = $wmiDriverCats | Select-Object -Property LocalizedCategoryInstanceName,CategoryInstance_UniqueID
    foreach ($cat in $driverCats) {
        $outStr = $cat.LocalizedCategoryInstanceName + ',' + $cat.CategoryInstance_UniqueID
        $outStr | Out-File -FilePath $outFile -Append -Encoding ascii
    }
########################## End Build Driver Info File #########################
###############################################################################


###############################################################################
########################### Start Build OS Info File ##########################
    #Second output file - OSImage information:
    [string] $outFile = 'O:\sources\os\mdt\files\Scripts\zUVM-OSImages.csv'
    if (Test-Path $outFile) {Remove-Item $outFile -Force -Confirm:$false}

    #We /could/ (and probably should) use WMI here to query root/sms/site_[siteCode]/ImagePackage 
    # (and corresponding ImagePackageInfo), but I am being lazy and will stick with the xml parsing code I already wrote:

    #Load the Configuration Manager PS module, needed for the CM cmdlet:
    Import-Module -Name $CMModPath

    Push-Location
    Set-Location $CMDrive
    $OSImages = Get-CMOperatingSystemImage
    Pop-Location

    foreach ($image in $OSImages) {
        [xml]$imageXml = $image.ImageProperty
        $OSVer = ($imageXml.WIM.IMAGE.Property | ? -Property name -eq 'OS version').'#text'
        if ($OSVer -match '^6\.2|^6\.3') {
            [string] $winVer = 'Win8'
        } elseif ($OSVer -match '^6\.1') {
            [string] $winVer = 'Win7'
        } else {
            [string] $winVer = 'unknown'
        }
        $outStr = $image.Name + ',' + $winVer
        $OutStr | Out-File $outFile -Append -Encoding ascii
    }
############################ End Build OS Info File ###########################
###############################################################################
