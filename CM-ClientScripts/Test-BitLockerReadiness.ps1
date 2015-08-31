<#
  Test-BitLockerReadiness.ps1
  by J. Greg Mackinnon, 2015-08-31

  Tests to see if a system is ready for BitLocker support.  Readiness is determined by evaluating the following criteria:
    -The BIOS release date passes an arbitrary age test (see $noSuppDate)
    -A battery is present (proof that the device is "mobile")
    -If Windows 7, a TPM must be present and enabled
    
  The script returns a simple 'True' boolean if the criteria are satisfied, otherwise 'False' is returned.
  
  Set $verbosePreference = 'Continue' for advanced output. 
#>
Set-PSDebug -Strict

#Set an arbitrary date which represents a cut-off for BitLocker support.  
# Bios older than this date will be considered "too old to be supported".
$noSuppDate = [datetime] '2010-01-01'
Write-Verbose ('Date before which the system will be considered too old to run BitLocker: ' + $noSuppDate)

##### Age test: #####
try {
    $bios = Get-WmiObject -Namespace root/cimv2 -Class Win32_Bios -ErrorAction Stop
} catch {
    [string]$out = "Could not process WMI query for BIOS information."
    Write-Error $out
}
if ($bios.ReleaseDate -ne $null) {
    $biosDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)
    if ($biosDate -lt $noSuppDate) {
        [bool]$newEnough = $false
    } else {
        [bool]$newEnough = $true
    }
} else {
    #Bios release date is not available.  Assume too old...
    [bool]$newEnough = $false
}
Write-Verbose ('newEnough value: ' + $newEnough)
if (-not $newEnough) {
    Write-Verbose 'System is not of recent vintage. NO GO!'
    return $false
    exit
} else {
    Write-Verbose 'System appears to be new enough to support BitLocker.'
}

##### Battery Test: #####
try {
    $battery = Get-WmiObject -Namespace root/cimv2 -Class Win32_Battery -ErrorAction Stop
} catch {
    [string]$out = "Could not process WMI query for BIOS information."
    Write-Error $out
}
if (($battery.BatteryStatus -ne $null) -and ($battery.BatteryStatus -ne '0')) {
    Write-Verbose 'System battery detected.  Assuming the system is a laptop.'
} else {
    Write-Verbose 'System has no battery, and therefore is not a laptop.  NO GO!'
    return $false
    exit
}

##### Win7 Test: #####
try {
    $os = Get-WmiObject -Namespace root/cimv2 -Class Win32_OperatingSystem -ErrorAction Stop
} catch {
    [string]$out = "Could not process WMI query for Operating System information."
    Write-Error $out
}
if ($os.caption -match 'Windows 7 ') {
    try {
        $tpm = Get-WmiObject -Namespace root/cimv2/security/MicrosoftTpm -Class Win32_Tpm -ErrorAction SilentlyContinue
    } catch {
        $out = "Could not get the Win32_Tpm class from the root/cimv2/security/MicrosoftTpm namespace. `n" `
            + "Possibly there is no TPM present?  Note that if this script is running as a non-admin user, it`n" `
            +  "will appear that there is no TPM present, even if one is available.  Assuming no TPM..."
        Write-Verbose $out
        return $false
        exit
    }
    if ($tpm -ne $null) { 
        if ($tpm.isEnabled().isEnabled) {
        	Write-Verbose 'TPM is present and enabled. GO!'
        	return $true
        	exit
    	} else {
            Write-Verbose 'TPM is not enabled.  NO GO!'
            return $false
            exit
        }
    } else {
        Write-Verbose 'TPM is not present.  NO GO!'
        return $false
        exit
    }
} elseif ($os.ProductType = '1') {
    Write-Verbose "System is a Windows client, version 8 or later.  GO!"
    return $true
}
