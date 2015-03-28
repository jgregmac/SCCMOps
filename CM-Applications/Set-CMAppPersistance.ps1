<#
Sets the MaxExecuteTime for all non-superseded, non-retired deployment types to 15 minutes (the minimum value).

Requires: Access to Configuration Manager "Admin Console" directory to load CM assemblies.
Compatibility: Tested against SCCM 2012 R2 only.

Adapted from:
http://www.david-obrien.net/2013/04/set-cmdeploymenttype-via-powershell-for-configmgr-2012/
Which in turn was inspired by:
http://blogs.msdn.com/b/one_line_of_code_at_a_time/archive/2012/01/17/microsoft-system-center-configuration-manager-2012-package-conversion-manager-plugin.aspx

#>


Set-PSDebug -Strict

#CM Server info:
[string]$SiteCode = 'UVM'
[string]$MPServer = 'confman3.campus.ad.uvm.edu'

#Directory containing ConfigManager management dll files:
[string] $AdminConsoleDirectory = "F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin"

function Execute-WqlQuery($siteServerName, $query) {
  #Uses ConfigManager assemblies to perform a CM WQL query.
  # Requires: the name of the site server (string format), and the WQL query (string format)
  # Returns: The results of the query
  $returnValue = $null
  $connectionManager = new-object Microsoft.ConfigurationManagement.ManagementProvider.WqlQueryEngine.WqlConnectionManager
  
  if($connectionManager.Connect($siteServerName))
  {
      $result = $connectionManager.QueryProcessor.ExecuteQuery($query)
      
      foreach($i in $result.GetEnumerator())
      {
        $returnValue = $i
        break
      }
      
      $connectionManager.Dispose() 
  }
  
  $returnValue
}

function Get-ApplicationObjectFromServer($appName,$siteServerName) {
    # Uses CM assemblies to retrieve a writable representation of an application object from the "SDMPackageXML" descriptor of a CM application.
    # Modifying this object will not update the CM Application.  You will need to re-serialize the object and use the application's "put" method to trigger the update.

    $resultObject = Execute-WqlQuery -siteServerName $siteServerName -query "select thissitecode from sms_identification" 
    $siteCode = $resultObject["thissitecode"].StringValue
    
    $path = [string]::Format("\\{0}\ROOT\sms\site_{1}", $siteServerName, $siteCode)
    $scope = new-object System.Management.ManagementScope -ArgumentList $path
    
    $query = [string]::Format("select * from sms_application where LocalizedDisplayName='{0}' AND ISLatest='true'", $appName.Trim())
    
    $oQuery = new-object System.Management.ObjectQuery -ArgumentList $query
    $obectSearcher = new-object System.Management.ManagementObjectSearcher -ArgumentList $scope,$oQuery
    $applicationFoundInCollection = $obectSearcher.Get()    
    $applicationFoundInCollectionEnumerator = $applicationFoundInCollection.GetEnumerator()
    
    if($applicationFoundInCollectionEnumerator.MoveNext())
    {
        $returnValue = $applicationFoundInCollectionEnumerator.Current
        $getResult = $returnValue.Get()        
        $sdmPackageXml = $returnValue.Properties["SDMPackageXML"].Value.ToString()
        [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($sdmPackageXml)
    }
}


 function Load-ConfigMgrAssemblies() {
     # Loads the CM .NET assemblies into memory.  
     # Requires: $AdminConsoleDirectory needs to be defined globally or at the script level.
     
     [string[]] $filesToLoad = @("Microsoft.ConfigurationManagement.ApplicationManagement.dll","AdminUI.WqlQueryEngine.dll", "AdminUI.DcmObjectWrapper.dll")
     
     Set-Location $AdminConsoleDirectory
     [System.IO.Directory]::SetCurrentDirectory($AdminConsoleDirectory)
     
      foreach($fileName in $filesToLoad)
      {
         $fullAssemblyName = [System.IO.Path]::Combine($AdminConsoleDirectory, $fileName)
         if([System.IO.File]::Exists($fullAssemblyName ))
         {   
             $FileLoaded = [Reflection.Assembly]::LoadFrom($fullAssemblyName )
         }
         else
         {
              Write-Host ([System.String]::Format("File not found {0}",$fileName )) -backgroundcolor "red"
         }
      }
 }

Load-ConfigMgrAssemblies

# Gather an array of all non-retired, current, non-superseded applications from CM:
[wmi[]]$apps = Get-WmiObject SMS_Application -Namespace root\sms\site_$($SiteCode) |  where {($_.IsLatest) -and ($_.IsExpired -eq $false) -and ($_.IsSuperseded -eq $false)}

foreach ($app in $apps) {
    # Retrieve a writable, de-serialized representation of the applications XML descriptor from CM.
    # This object is not XML, but will be converted to XML later.
    $appXML = Get-ApplicationObjectFromServer -appName "$($app.LocalizedDisplayName)" -siteServerName $MPServer

    if ($appXML.DeploymentTypes -ne $null) { 
	    foreach ($dt in $appXML.DeploymentTypes) {
            write-host 'Testing application:' $app.LocalizedDisplayName
		    if ($dt.installer.Contents.PinOnClient -eq $true) {
                Write-Host 'Application has App cache persistence set.  Boo!'
                # Set the MaxExecutionTime to the minimum allowed value
                <#$dt.installer.MaxExecuteTime = 15
                $newAppXml = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::Serialize($appXML, $false)
                $app.SDMPackageXML = $newAppXml
                $app.Put() | Out-Null#>
            } elseif ($dt.installer.Contents.PinOnClient -eq $false) {
                Write-Host 'Application does not have App cache persistence set.  Hurray!'
            }
	    }
    }
}
