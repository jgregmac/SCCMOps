Set-PSDebug -Strict

[string] $CMSiteCode = 'UVM'

[string] $CMBinPath = 'F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\'
[string] $CMModName = 'ConfigurationManager.psd1'
[string] $CMModPath = Join-Path -Path $CMBinPath -ChildPath $CMModName

Import-Module -Name $CMModPath

$dts = Get-CMApplication | ? {$_.IsEnabled -EQ $true} | % {Get-CMDeploymentType -ApplicationName $_.LocalizedDisplayName | ? {$_.IsSuperseded -EQ $false} | ? {$_.Technology -match "MSI|Script"}}
