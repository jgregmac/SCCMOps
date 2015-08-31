' Sets computer name to the current computer name
strComputer = "."
' Connect to the WMI Service
Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
' Fetch all details from Win32_computersystem
Set colComputerSystem = objWMIService.ExecQuery ("Select * from Win32_computersystem")
Set colBIOS = objWMIService.ExecQuery ("Select * from Win32_BIOS")
' Look through all values, and make variables for manufacturer and model
For each objComputerSystem in colComputerSystem
	GetComputerManufacturer = objComputerSystem.Manufacturer
	GetComputerModel = objComputerSystem.Model
Next
Wscript.echo "The system you are on is a " & GetComputerManufacturer & " " & GetComputerModel

