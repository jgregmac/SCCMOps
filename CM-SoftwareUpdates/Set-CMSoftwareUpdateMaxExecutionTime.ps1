Set-PSDebug -Strict

[string] $CMSiteCode = 'UVM'

[string] $CMBinPath = 'F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\'
[string] $CMModName = 'ConfigurationManager.psd1'
[string] $CMModPath = Join-Path -Path $CMBinPath -ChildPath $CMModName

Import-Module -Name $CMModPath

Set-CMQueryResultMaximum 99999

[string] $CMPath = $CMSiteCode + ':\'
set-location $CMPath

Get-CMSoftwareUpdate | ? {$_.IsDeployed -and $_.IsLatest -and ($_.IsExpired -eq $false) -and ($_.MaxExecutionTime -gt 300)} `
    | % {write-host 'Setting MaxExecutionMinutes for:' $_.LocalizedDisplayName ; Set-CMSoftwareUpdate -InputObject $_ -MaximumExecutionMinutes 5 -ea Stop}

Set-CMQueryResultMaximum -Maximum 1000
