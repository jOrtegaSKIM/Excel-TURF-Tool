Public WorkSpacePath As String
Public WorkSpacePathSystem As String
Public WorkbookName As String
Public RScriptPath As String

Function GetRScriptPath() As String
    Dim objShell As Object
    Dim regCommand As String
    Dim retValue As String
    Dim arrOutput As Variant
    Dim RInstallPath As String
    
    On Error GoTo ErrHandler
    Set objShell = CreateObject("WScript.Shell")
    
    ' Try the standard (64-bit) registry key first
    regCommand = "reg query ""HKEY_LOCAL_MACHINE\SOFTWARE\R-core\R"" /v InstallPath"
    retValue = objShell.Exec(regCommand).StdOut.ReadAll
    If InStr(retValue, "InstallPath") > 0 Then
        arrOutput = Split(retValue, "REG_SZ")
        RInstallPath = Trim(arrOutput(1))
        GetRScriptPath = RInstallPath & "\bin\Rscript.exe"
        Exit Function
    End If
    
    ' If not found, try the Wow6432Node key (for 32-bit R on 64-bit Windows)
    regCommand = "reg query ""HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\R-core\R"" /v InstallPath"
    retValue = objShell.Exec(regCommand).StdOut.ReadAll
    If InStr(retValue, "InstallPath") > 0 Then
        arrOutput = Split(retValue, "REG_SZ")
        RInstallPath = Trim(arrOutput(1))
        GetRScriptPath = RInstallPath & "\bin\Rscript.exe"
        Exit Function
    End If
    
    ' If both attempts fail, return a not found message
    GetRScriptPath = "Rscript.exe not found via registry."
    Exit Function
    
ErrHandler:
    GetRScriptPath = "Error: " & Err.Description
End Function

Sub SaveWorkSpaceVarables()
    ' Save the current workbook path to global variable
    WorkSpacePath = ThisWorkbook.path
    WorkSpacePathSystem = WorkSpacePath & Application.PathSeparator & "system"

    ' Save the name of current workbook to global variable
    WorkbookName = ThisWorkbook.name

    ' Save the Rscript.exe path to global variable
    RScriptPath = GetRScriptPath()

End Sub

Sub RunRScript()
    Dim objShell As Object
    Dim RScriptPath As String
    Dim RScriptFile As String
    Dim Command As String
    
    ' Create WScript.Shell object
    Set objShell = CreateObject("WScript.Shell")
    
    ' Full path to the R script you want to execute
    RScriptFile = WorkSpacePathSystem & Application.PathSeparator & "linking.R"
    
    ' Build the command - using cmd /k keeps the window open
    Command = RScriptPath & " " & RScriptFile & " " & WorkSpacePathSystem 
    
    ' Run the command and keep the window open
    objShell.Run Command, 1, True
    
   Set objShell = Nothing
End Sub




