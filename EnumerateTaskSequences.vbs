Dim connection
Dim computer
Dim userName
Dim userPassword
Dim password 'Password object

Wscript.StdOut.Write "Computer you want to connect to (Enter . for local): "
computer = WScript.StdIn.ReadLine

If computer = "." Then
    userName = ""
    userPassword = ""
Else
    Wscript.StdOut.Write "Please enter the user name: "
    userName = WScript.StdIn.ReadLine
    
    'Set password = CreateObject("ScriptPW.Password") 
    WScript.StdOut.Write "Please enter your password:" 
    'userPassword = password.GetPassword() 
    userPassword = WScript.StdIn.ReadLine
End If
      
Set connection = Connect(computer,userName,userPassword)
wscript.echo "connection object is " & TypeName(connection)

If Err.Number<>0 Then
    Wscript.Echo "Call to connect failed"
End If

Call EnumerateTaskSequencePackages(connection)

Sub EnumerateTaskSequencePackages(connection)
    Set taskSequencePackages= connection.ExecQuery("Select * from SMS_TaskSequencePackage")
    For Each package in taskSequencePackages
        WScript.Echo package.Name
        WScript.Echo package.Sequence
        WScript.Echo package.SourceDate
        wscript.echo package.packageid
        wscript.echo "Getting Task Sequence Object for the package..."
        Set taskSequence =  ReadTaskSequence(connection, package)
        wscript.echo "Enumerating task sequence steps..."
        Call RecurseTaskSequenceSteps(taskSequence, 4)
    Next
End Sub

Function ReadTaskSequence(connection, taskSequencePackage)
    ' Get the parameters object.
    Set packageClass = connection.Get("SMS_TaskSequencePackage")
    Set objInParam = packageClass.Methods_("GetSequence"). _
        inParameters.SpawnInstance_()
    ' Add the input parameters.
     objInParam.Properties_.Item("TaskSequencePackage") =  taskSequencePackage
    ' Get the sequence.
     Set objOutParams = connection.ExecMethod("SMS_TaskSequencePackage", "GetSequence", objInParam)
     Set ReadTaskSequence = objOutParams.TaskSequence
End Function

Sub RecurseTaskSequenceSteps(taskSequence, indent)
    Dim osdStep 
    Dim i
    ' Indent each new group.
    for each osdStep in taskSequence.Steps
        for i=0 to indent
            WScript.StdOut.Write " "
        next
        If osdStep.SystemProperties_("__CLASS")="SMS_TaskSequence_Group" Then
            wscript.StdOut.Write "Group: " 
        End If  
        WScript.Echo osdStep.Name
        ' Recurse into each group found.
        If osdStep.SystemProperties_("__CLASS")="SMS_TaskSequence_Group" Then
            If IsNull(osdStep.Steps) Then
                Wscript.Echo "No steps"
            Else
                Call RecurseTaskSequenceSteps (osdStep, indent+3)
            End If    
        End If
     Next   
End Sub   

Function Connect(server, userName, userPassword)
    On Error Resume Next
    Dim net
    Dim localConnection
    Dim swbemLocator
    Dim swbemServices
    Dim providerLoc
    Dim location
    Set swbemLocator = CreateObject("WbemScripting.SWbemLocator")
    swbemLocator.Security_.AuthenticationLevel = 6 'Packet Privacy
    ' If  the server is local, don not supply credentials.
    Set net = CreateObject("WScript.NetWork") 
    If UCase(net.ComputerName) = UCase(server) Then
        localConnection = true
        userName = ""
        userPassword = ""
        server = "."
    End If
    
    ' Connect to the server.
    Set swbemServices= swbemLocator.ConnectServer _
            (server, "root\sms",userName,userPassword)
    If Err.Number<>0 Then
        Wscript.Echo "Couldn't connect: " + Err.Description
        Connect = null
        Exit Function
    End If
    

    ' Determine where the provider is and connect.
    Set providerLoc = swbemServices.InstancesOf("SMS_ProviderLocation")

        For Each location In providerLoc
            If location.ProviderForLocalSite = True Then
                Set swbemServices = swbemLocator.ConnectServer _
                 (location.Machine, "root\sms\site_" + _
                    location.SiteCode,userName,userPassword)
                If Err.Number<>0 Then
                    Wscript.Echo "Couldn't connect:" + Err.Description
                    Connect = Null
                    Exit Function
                End If
                Set Connect = swbemServices
                Exit Function
            End If
        Next
    Set Connect = null ' Failed to connect.
End Function