' Based on VBScript code from Script Center 
'    http://bit.ly/br8luP
' and this example in PowerShell 
'    http://bit.ly/b9P84b


strComputer                = "."
strCpuArchitecture         = ""
intCurrentAddressWidth     = 0
intSupportableAddressWidth = 0

Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Set colProcessors = objWMIService.ExecQuery _
    ("Select * From Win32_Processor")

For Each objProcessor in colProcessors

    intCurrentAddressWidth = objProcessor.AddressWidth
    intSupportableAddressWidth = objProcessor.DataWidth

    Select Case objProcessor.Architecture
        Case 0 strCpuArchitecture = "x86"
        Case 1 strCpuArchitecture = "MIPS"
        Case 2 strCpuArchitecture = "Alpha"
        Case 3 strCpuArchitecture = "PowerPC"
        Case 6 strCpuArchitecture = "Itanium"
        Case 9 strCpuArchitecture = "x64"
    End Select

    if strCpuArchitecture <> "" then
        Exit For
    end if
Next

if intCurrentAddressWidth = intSupportableAddressWidth then
    Echo intCurrentAddressWidth & "-bit OS : " & _
                 strCpuArchitecture & " CPU"
else
    Echo intCurrentAddressWidth & "-bit OS " & _
                 "( " & intSupportableAddressWidth & "-bit capable ) : " & _
                 strCpuArchitecture & " CPU"
end if

