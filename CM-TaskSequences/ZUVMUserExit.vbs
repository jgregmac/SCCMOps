' // ZUVMUserExit.vbs
' // Custom Function library for use with the Microsoft Deployment Toolkit
' // Currently includes "GenUniComp" - a function for generating unique computer names 

' code adapted from source content:
'   http://blogs.technet.com/benhunter/archive/2007/03/17/understanding-bdd-rule-processing.aspx

Function UserExit(sType, sWhen, sDetail, bSkip) 
    UserExit = Success
End Function 

Function GenSimDate()
    'Generates a simple date string in the format of YYMMDD
    Dim dNow, sYear, sMonth, sDay
    dNow = Date()
    sYear = Right(cStr(Year(dNow)), 2)
    sMonth = cStr(Month(dNow))
    sDay = cStr(Day(dNow))
    ' The + symbol will concatenate the previously defined strings:
    GenSimDate = sYear + sMonth + sDay
End Function

Function CleanStr(str)
    'Strips colon (:) , hyphen (-), or whitespace ( ) characters from the variable passed to this function. 
    Dim oRegExp 
    Set oRegExp = new RegExp 
    oRegExp.IgnoreCase = true 
    oRegExp.Global = true 
    oRegExp.Pattern = ":|-| " 
    CleanStr = oRegExp.Replace(str, "") 
End Function

Function GenUniComp()
    'Generates a hopefully unique computer name by:
    '   Selecting from available MacAddress, SerialNumber, or Asset Tag then
    '   triming the right eight digits from the value and appending a hyphen with the current date.
    Dim sMac, sTag, sSerial
    Dim sSimDate, sUniVal
    sMac = oEnvironment.Item("MACAddress")
    sTag = oEnvironment.Item("AssetTag")
    sSerial = oEnvironment.Item("SerialNumber")
    oLogging.CreateEntry "ZUVMUserExit: sMac value in UserExit script is: " & sMac,LogTypeInfo
    oLogging.CreateEntry "ZUVMUserExit: sSerial value in UserExit script is: " & sSerial,LogTypeInfo
    oLogging.CreateEntry "ZUVMUserExit: sTag value in UserExit script is: " & sTag,LogTypeInfo
    if Len(sSerial) > 0 then
        oLogging.CreateEntry "ZUVMUserExit: Using Serial Number to generate computer name.",LogTypeInfo
        sUniVal = sSerial
    elseif Len(sTag) > 0 then
        oLogging.CreateEntry "ZUVMUserExit: Using Asset Tag to generate computer name.",LogTypeInfo
        sUniVal = sTag
    elseif Len(sMac) > 0 then
        oLogging.CreateEntry "ZUVMUserExit: Using Mac Address to generate computer name",LogTypeInfo
        sUniVal = sMac
    else
        oLogging.CreateEntry "ZUVMUserExit: Using Fallback Computer Name",LogTypeInfo
        sUniVal = "UVMMDT"
    end if
    oLogging.CreateEntry "ZUVMUserExit: sUniVal now set to: " & sUniVal,LogTypeInfo
    sSimDate = GenSimDate()
    sUniVal = CleanStr(sUniVal)
    oLogging.CreateEntry "ZUVMUserExit: Cleaned sUniVal value now is: " & sUniVal,LogTypeInfo
    GenUniComp = Right(sUniVal, 8) + "-" + sSimDate
    oLogging.CreateEntry "ZUVMUserExit: Unique Computer Name will be: " & GenUniComp,LogTypeInfo
End Function
