' Script to configure the driver categories to be applied to the operating system in the running task sequence.
' Reads driver category information from a file genereted in PowerShell
' OS Image info likely /should/ come from a file.

' Idea is to update the list of driver categories to be applied against an operating system during the "Auto Apply Drivers" TS step:
'		https://technet.microsoft.com/en-us/library/hh273365.aspx
'		https://technet.microsoft.com/en-us/library/dd252750.aspx
'		(Note we will attempt to set the OSDAutoApplyDriverCategoryList, which claims to be a comma-delimited list, not array)
' Following programming guidance in MSDN:
'		https://msdn.microsoft.com/en-us/library/jj217814.aspx
' And sample code provided by Ben Hunter, Deployment Guy:
'		http://blogs.technet.com/b/deploymentguys/archive/2008/04/18/configuration-manager-dynamic-driver-categories.aspx

'
Option Explicit

Dim catFilePath, dict_key, imageFilePath, ImageName, Model, myCat, WinVer 'String variables
Dim driverCats, OSImages 'Objects

Set driverCats = createObject("Scripting.Dictionary")
Set OSImages = createObject("Scripting.Dictionary")

catFilePath = "zUVM-DriverCategories.csv"
imageFilePath = "zUVM-OSImages.csv"


REM Function SetTaskSequenceVariable(tsVar,tsValue)
	REM dim tsEnv: set tsEnv = CreateObject("Microsoft.SMS.TSEnvironment")
	REM dim oldTsValue

	REM ' You can query the environment to get an existing variable.
	REM oldTsValue = tsEnv(tsVar)

	REM 'Some attempt here to figure out what we are getting back from SCCM:
	REM '	http://www.w3schools.com/vbScript/func_vartype.asp
	REM '	https://msdn.microsoft.com/en-us/library/ie/y58s1cs6(v=vs.84).aspx
	REM ' (Note that "TypeName()" likely is the function that we want to use here, not VarType()
	REM Wscript.echo "Variable is of type: " & TypeName(oldTsValue)
	REM ' Set variable:
	REM tsEnv(tsVar) = tsValue
REM End Function

REM Function GetTaskSequenceVariable(tsValue)
	REM dim tsEnv: set tsEnv = CreateObject("Microsoft.SMS.TSEnvironment")
	REM GetTaskSequenceVariable = tsEnv(tsVar)
REM End Function

Function load_dict(dict_name,file_name)
	Dim objFSO,objFile,objText,line,pair_array,index,item
	Const ForReading = 1, ForWriting = 2, ForAppending = 8, ReadOnly = 1

	Set objFSO = CreateObject("Scripting.FileSystemObject")  'Create file object
	Set objText = objFSO.OpenTextFile(file_name, ForReading) 'Open for read
	'Set objFile = ObjFSO.GetFile(file_name)
	
	'wscript.echo file_name
	'wscript.echo objFile.Name
	'wscript.echo objFile.Path

	Do Until objText.AtEndOfStream        'Read to end of file
		line = objText.ReadLine                  'Read line from file
		'wscript.echo line
		pair_array = split(line,",")             'Split Index-Item pair
		index = pair_array(0) 'Decode Index
		item  = pair_array(1) 'Decode Item
		dict_name.Add index,item  'Add to Dictionary
	Loop                                      'Read another line
	objText.Close
End Function

'--- List db content
Function list_dict(dict_name)
	Dim key_array, strKey
	key_array = dict_name.Keys            'Get all Keys
	For Each strKey in key_array        'Scan array
		Wscript.Echo strKey & " = " & dict_name.Item(strKey) 
	Next
End Function

call load_dict(driverCats,catFilePath)
call load_dict(OSImages,imageFilePath)

'list_dict driverCats
'list_dict OSImages


'Retrieve the OSD Image Name from the running task sequence:
'ImageName = GetTaskSequenceVariable("OSDImageName")
ImageName = "Windows 8.1 Update 1 64-bit with Office 2013"
If OSImages.Exists(ImageName) Then
	WinVer = OSImages.Item(ImageName)
Else
	WScript.Quit()
End If

'Model = GetTaskSequenceVariable("Model")
Model = "PunchPad 5000"
dict_key = WinVer & "-" & Model
If driverCats.Exists(dict_key) Then
	myCat =  driverCats.Item(dict_key)
	wscript.echo dict_key & "= " & myCat
'If we are dealing with a Windows 8 image, then check for Windows 7 drivers when Win8 drivers can't be found:
ElseIf InStr(WinVer,"Win8") Then
	WinVer = "Win7"
	dict_key = WinVer & "-" & Model
	myCat =  driverCats.Item(dict_key)
	'wscript.echo "myCat = " & myCat
Else
	myCat = ""
End If

If Not IsEmpty(myCat) Then
	dict_key = "Other-noArch"
	If driverCats.Exists(dict_key) Then
		myCat =  myCat & "," & driverCats.Item(dict_key)
	End If
	dict_key = "Other-x86"
	If driverCats.Exists(dict_key) Then
		myCat =  myCat & "," & driverCats.Item(dict_key)
	End If
	dict_key = "Other-x64"
	If driverCats.Exists(dict_key) Then
		myCat =  myCat & "," & driverCats.Item(dict_key)
	End If
	wscript.echo "myCat = " & myCat
	call SetTaskSequenceVariable("OSDAutoApplyDriverCategoryList",myCat)
Else
	wscript.echo "Unsupported Model"
	call SetTaskSequenceVariable("OSDAutoApplyDriverCategoryList","")
End If