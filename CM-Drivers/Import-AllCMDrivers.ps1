# Script to add all drivers in an import source into SCCM.
# This script does not work.  Please do not use it in production.
# Why? Becuase of numerous bugs in the unbelievably crappy SCCM PowerShell cmdlets.  It's hopeless.

param ([bool]$reImport = $false)
Set-PSDebug -Strict

#CM Server info:
[string]$CMSiteCode = 'UVM'
[string]$MPServer = 'confman3.campus.ad.uvm.edu'

#Directory containing ConfigManager management dll files:
[string] $CMBinPath = 'F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\'

#Directory containing drivers to import:
[string] $driverUncPath = '\\confman3\sources\drivers\import'

# Define Supported Model Output File:
[string] $modelOutFile = 'c:\local\temp\SupportedModels.txt'

function cleanDriverDir {
    param ([string]$dir)
	# Clean up "cruft" files that lead to duplicate drivers in the share:
	Write-Host "Cleaning extraneous files from $dir" -ForegroundColor Cyan
	$delItems = gci -recurse -Include version.txt,release.dat,cachescrubbed.txt,btpmwin.inf $dir
	Write-Host "Found " $delItems.count " files to delete..." -ForegroundColor Yellow
	if ($delItems.count -ne 0) {
		$delItems | remove-Item -force -confirm:$false
		$delItems = gci -recurse -Include version.txt,release.dat,cachescrubbed.txt,btpmwin.inf $dir
		Write-Host "New count for extraneous files: " $delItems.count -ForegroundColor Yellow
	}	
}

Function Add-DriverContentToDriverPackage {
    [CmdLetBinding()]
    Param(
    [Parameter(Mandatory=$True,HelpMessage="Please Enter Site Server Site code")]
              $SiteCode,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter Site Server Name")]
              $SiteServer,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter Driver ID")]
              $DriverCI,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter Driver Package Name")]
              $DriverPackageName
    )     
    # Credit for this function to: http://cm12sdk.net/?p=933
    $DriverPackage = Get-WmiObject -Namespace "Root\SMS\Site_$SiteCode" -Class SMS_DriverPackage -ComputerName $SiteServer -Filter "Name='$DriverPackageName'"
    $Driver = Get-WmiObject -Namespace "Root\SMS\Site_$SiteCode" -Class SMS_Driver -ComputerName $SiteServer -Filter "CI_ID='$DriverCI'"
    $DriverContent = Get-WmiObject -Namespace "Root\SMS\Site_$SiteCode" -Class SMS_CIToContent -ComputerName $SiteServer -Filter "CI_ID='$($Driver.CI_ID)'"
    
    $ContentID = $DriverContent.ContentID
    $PkgSource = $Driver.ContentSourcePath

    $inparams = $DriverPackage.psbase.getmethodparameters("AddDriverContent")
    $inParams.ContentIDs = $ContentID
    $inParams.ContentSourcePath = $PkgSource
    $inparams.bRefreshDPs = $false
     
    $DriverPackage.psbase.InvokeMethod("AddDriverContent",$inparams, $null)                       
}


#Initialize the SupportedModels output file:
if (test-path $modelOutFile) {Remove-Item $modelOutFile -Force -Confirm:$false}
[string]$('List of hardware models currently supported for LiteTouch deployments') | out-file -LiteralPath $modelOutFile -Append
[string]$('Last Updated on: '+ [datetime]::Now) | out-file -LiteralPath $modelOutFile -Append
[string]$('') | out-file -LiteralPath $modelOutFile -Append
[string]$('Model names discovered by running the command "wmic computersystem get model"') | out-file -LiteralPath $modelOutFile -Append
[string]$('If drivers are detected for an earlier OS than the OS selected for deployment, and no current drivers are available, the older drivers will be used.') | out-file -LiteralPath $modelOutFile -Append
[string]$('') | out-file -LiteralPath $modelOutFile -Append

#Setup PSDrive to ease access to drivers to import:
if (-not (Test-Path -LiteralPath 'DriverSource:\')) { New-PSDrive -Name DriverSource -Root $driverUncPath -PSProvider FileSystem }
[string] $driverPSRoot = 'DriverSource:\'
#[string] $modelRoot = Join-Path -Path 'DriverSource:\' -ChildPath 'Models' -Resolve -ErrorAction Stop

#Load CM PowerShell module and set working location to the CM PowerShell drive provider:
[string] $CMModName = 'ConfigurationManager.psd1'
[string] $CMModPath = Join-Path -Path $CMBinPath -ChildPath $CMModName -Resolve -ErrorAction Stop
[string] $CMDrive = $CMSiteCode + ':\'
Import-Module -Name $CMModPath
Set-Location $CMDrive

#Driver Package to hold the imported drivers:
$drvPkg = Get-CMDriverPackage -name 'All Drivers'

#Gather current driver categories from CM:
[string[]] $CMCats = @()
$CMCats += Get-CMCategory -CategoryType DriverCategories | % {$_.LocalizedCategoryInstanceName}

#Initialize array of source directories:
$importSources = @()

#Gather current model source directories:
# Generates an array "$importSources", each member of which contain a full import source directory, and the category to which the drivers in this directory are to be assigned.
# Also adds a new CMCategory for the drivers to be imported if none already exists.
[string[]] $DCatList = Get-ChildItem  -LiteralPath $driverPSRoot -ErrorAction Stop | % {$_.Name}
foreach ($DCat in $DCatList) {
    $dirList = @()
    $dirList = Get-ChildItem -LiteralPath $(Join-Path -Path $driverPSRoot -ChildPath $DCat -Resolve)
    foreach ($dir in $dirList) {
        [string] $cat = $DCat + '-' + $dir.Name
        if (-not $CMCats.Contains($cat)) {
            Write-Host $cat "is not defined.  Creating it now."
            $null = New-CMCategory -CategoryType DriverCategories -Name $cat
            $imported = $false
        } else {
            # Write-Host $cat "is already defined in CM."
            $imported = $true
        }
        #create an array for each driver source that combines:
        #  [0] the path to the driver, 
        #  [1] a CMCategory object that the driver will be assigned to and, 
        #  [2] If the category existed before this run of the script.
        $src = @($dir, (Get-CMCategory -CategoryType DriverCategories -Name $cat), $imported)
        #Note the use of the comma to avoid "unrolling" the array $src before adding it to the array $sources:
        $importSources += , $src
    } 
}
Remove-Variable cat,CMCats,DCatList,DCat,dir,dirList,imported,src

#Import all of the .inf and txtsetup.oem drivers in $sources into CM.  This will take a long time!
# Capture the driver source URIs into $allUris
[string[]] $uris = @()
foreach ($src in $importSources) {
    [bool] $doIt = $false
    if ($reImport) {
        $doIt = $true
    } elseif (-not $src[2]) {
        $doIt = $true
    }
    if ($doIt) {
        cleanDriverDir($src[0].PSPath)
        Write-Host "Importing" $src[1].LocalizedCategoryInstanceName
        [string[]] $uris = @()
        $uris += gci $src[0].PSPath -Recurse -Include txtsetup.oem,*.inf | % {$_.FUllName}
        foreach ($uri in $uris) {
            $allUris += $uri
            Write-Host "Importing" $uri "to" $src[1].LocalizedCategoryInstanceName
            #Removed: -DriverPackage $drvPkg `
            #  Because of this bug: https://social.technet.microsoft.com/Forums/en-US/bbc212d3-269d-4245-9177-517c9a241466/importcmdriver-fails-with-importcmdriver-invalid-object-path-?forum=configmanagerosd
            #  This is really inconvenient, because other bugs prevent us from adding the drivers to a package after import!  Argh!
            #Assign output to $null because cmdlet output is noisy.  Cannot pipe to "out-null" because the cmdlet does not output to the pipeline.
            $null = Import-CMDriver -UncFileLocation $uri `
                -AdministrativeCategory $src[1] `
                -ImportDuplicateDriverOption AppendCategory `
                -EnableAndAllowInstall $True `
                -UpdateDistributionPointsforBootImagePackage $False `
                -UpdateDistributionPointsforDriverPackage $False
        } # End foreach $uri
        $src[1].LocalizedCategoryInstanceName | Out-File -LiteralPath $modelOutFile -Append
    } else {
        write-host $src[1].LocalizedCategoryInstanceName "is already imported.  Skipping."
    } # End if $doIt
}
Remove-Variable src,uri,uris


#Get-WmiObject is used to fetch all of our drivers because Get-CMDriver will not allow retrieval of multiple drivers.  Boo!
$wmiDrivers = Get-WmiObject -class SMS_Driver -computername "localhost" -namespace "root\SMS\site_UVM" -Property CI_ID,LocalizedDisplayName
foreach ($wmiDrv in $wmiDrivers) {
    #Set-CMDriver fails, reporting invalid source path, and some garbage about the path "e:\qfe", which is not referenced anywhere in the 
    #  driver object, nor in the driver package object.
    #Set-CMDriver -Id $wmiDrv.CI_ID -AddDriverPackage $drvPkg # -UpdateDistributionPointsforDriverPackage $true
    Add-DriverContentToDriverPackage -SiteCode $CMSiteCode -SiteServer $MPServer -DriverCI $wmiDrv.CI_ID -DriverPackageName $DrvPkg.Name
}

#Will this work for updating a package that already has been distributed once?
#Maybe see if the "RedistributePackage" method on the WMI DistributionPoint object will work if pointed at the driverPackage object?
#  See: http://www.windows-noob.com/forums/index.php?/topic/5836-refresh-package-on-distribution-point/
Start-CMContentDistribution -DriverPackage $drvPkg

<#
Still need to fix:
 - All TXTSETUP.OEM drivers are failing to import.
 - Process to add the drivers to a driver package (bug workaround). (done?)
 - Process to distribute content of the driver package after update. (done?)
#>

