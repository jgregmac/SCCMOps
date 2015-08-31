# function Load-CMAssemblies {
    # [string[]] $files = @("Microsoft.ConfigurationManagement.ManagementProvider.dll","AdminUI.WqlQueryEngine.dll")
    # [string] $AdminConsoleDirectory = "F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin"
    # [string[]] $filesToLoad = @()
    # foreach ($file in $files) {
        # [string] $fullPath = join-path $AdminConsoleDirectory $file
        # if (Test-Path $fullPath) {
            # $filesToLoad += $fullPath
            # Add-Type -AssemblyName $fullPath
            # Write-Host ("Loaded assembly: $file") -ForegroundColor Green
        # } else {
            # Write-Host ("File not found: $file") -ForegroundColor Red
        # }
    # }
    # #add-type -ReferencedAssemblies $filesToLoad
# }

 function Load-CMAssemblies($adminConsoleDirectory) {
     # Loads the CM .NET assemblies into memory.  
     # Requires: $AdminConsoleDirectory needs to be defined globally or at the script level.
     
     [string[]] $filesToLoad = @("Microsoft.ConfigurationManagement.ManagementProvider.dll","AdminUI.WqlQueryEngine.dll")
     
     Push-Location $AdminConsoleDirectory
     [System.IO.Directory]::SetCurrentDirectory($AdminConsoleDirectory)
     
      foreach($fileName in $filesToLoad)
      {
         $fullAssemblyName = [System.IO.Path]::Combine($AdminConsoleDirectory, $fileName)
         if([System.IO.File]::Exists($fullAssemblyName ))
         {   
             $FileLoaded = [Reflection.Assembly]::LoadFrom($fullAssemblyName )
              Write-Host ([String]::Format("Loaded assemblies from {0}",$fileName )) -ForegroundColor Green
         }
         else
         {
              Write-Host ([String]::Format("File not found {0}",$fileName )) -ForegroundColor Red
         }
      }
      Pop-Location
 }

function Execute-WqlQuery($siteServerName, $query) {
  #Uses ConfigManager assemblies to perform a CM WQL query.
  # Requires: the name of the site server (string format), and the WQL query (string format)
  # Returns: The results of the query
  $returnValue = $null
  $connectionManager = new-object Microsoft.ConfigurationManagement.ManagementProvider.WqlQueryEngine.WqlConnectionManager
  
  if($connectionManager.Connect($siteServerName,))
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

[string] $CMAdminDir = "F:\Program Files\Microsoft Configuration Manager\AdminConsole\bin"
Load-CMAssemblies($CMAdminDir)
$CMSiteServer = "."
$query = "select * from SMS_TaskSequencePackage"
$results = Execute-WqlQuery ($CMSiteServer, $query)
