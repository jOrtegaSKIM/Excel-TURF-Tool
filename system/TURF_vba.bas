Public Const vbDoubleQuote As String = """"
Public WorkSpacePath As String
Public WorkSpacePathSystem As String
Public WorkbookName As String
Public RScriptPath As String

Sub SetupTURF()

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets("Settings")
    
    '------------------------------------------------------------------
    ' 1. Read inputs: Methodology, Number of prods, Add none option
    '------------------------------------------------------------------
    Dim methodology As String
    methodology = ws.Range("B3").Value

    Dim numProds As Long
    numProds = ws.Range("D5").Value

    Dim addNoneOption As Boolean
    addNoneOption = ws.Range("D6").Value
    
    '------------------------------------------------------------------
    ' 2. Reset Calculation method and Optimization KPI
    '------------------------------------------------------------------
    ws.Range("B13").Value = "SoP"
    ws.Range("B16").Value = "Preference Share"

    '------------------------------------------------------------------
    ' 3. Clear the area for the new table
    '------------------------------------------------------------------
    ws.Range("G1:N1000").ClearContents

    '------------------------------------------------------------------
    ' 4. Create the correct column headers based on methodology
    '------------------------------------------------------------------
    ws.Range("G3").Value = "Item"
    ws.Range("H3").Value = "Owner"
    ws.Range("I3").Value = "Fixed"
    ws.Range("J3").Value = "Weight"

    Dim hasSizePriceDist As Boolean
    hasSizePriceDist = (methodology = "CBC" Or methodology = "Unspoken")

    If hasSizePriceDist Then
        ' CBC or Unspoken ? include Size, Price and Distribution columns
        ws.Range("K3").Value = "Size"
        ws.Range("L3").Value = "Price"
        ws.Range("M3").Value = "Distribution"
        ws.Range("N3").Value = "Bucket"
    Else
        ' MaxDiff or Anchored MaxDiff ? omit Size, Price and Distribution
        ws.Range("K3").Value = "Bucket"
    End If

    '------------------------------------------------------------------
    ' 5. Add products Prod1 to ProdN and fill default values
    '------------------------------------------------------------------
    Dim i As Long
    For i = 1 To numProds
        ' Row for product i will be (i+1)
        ws.Cells(i + 3, 7).Value = i           ' Product
        ws.Cells(i + 3, 8).Value = ""          ' Owner (left blank unless specified)
        ws.Cells(i + 3, 9).Value = ""          ' Fixed (left blank unless specified)
        ws.Cells(i + 3, 10).Value = 1          ' Weight = 1

        If hasSizePriceDist Then
            ' CBC/Unspoken
            ws.Cells(i + 3, 11).Value = 1      ' Size = 1
            ws.Cells(i + 3, 12).Value = ""     ' Price (left blank unless specified)
            ws.Cells(i + 3, 13).Value = 1      ' Distribution = 1
            ws.Cells(i + 3, 14).Value = ""     ' Bucket (left blank unless specified)
        Else
            ' MaxDiff/Anchored MaxDiff
            ws.Cells(i + 3, 11).Value = ""     ' Bucket (left blank unless specified)
        End If
    Next i

    '------------------------------------------------------------------
    ' 6. If "Add none option" is TRUE, add a "None" row at the end
    '------------------------------------------------------------------
    If addNoneOption Then
        Dim noneRow As Long
        noneRow = numProds + 4

        ws.Cells(noneRow, 7).Value = "none"    ' Product = "None"
        ws.Cells(noneRow, 8).Value = ""
        ws.Cells(noneRow, 9).Value = ""
        ws.Cells(noneRow, 10).Value = 1        ' Weight = 1

        If hasSizePriceDist Then
            ' If CBC/Unspoken, fill Size=1, Price=0, Distribution=1
            ws.Cells(noneRow, 11).Value = 1    ' Size = 1
            ws.Cells(noneRow, 12).Value = 0    ' Price = 0
            ws.Cells(noneRow, 13).Value = 1    ' Distribution = 1
            ws.Cells(noneRow, 14).Value = ""
        Else
            ' If MaxDiff/Anchored MaxDiff, no Size/Price/Distribution columns
            ws.Cells(noneRow, 11).Value = ""
        End If
    End If

End Sub

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
        RInstallPath = Replace(RInstallPath, Chr(13), "")
        GetRScriptPath = RInstallPath & "\bin\Rscript.exe"
        Exit Function
    End If
    
    ' If not found, try the Wow6432Node key (for 32-bit R on 64-bit Windows)
    regCommand = "reg query ""HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\R-core\R"" /v InstallPath"
    retValue = objShell.Exec(regCommand).StdOut.ReadAll
    If InStr(retValue, "InstallPath") > 0 Then
        arrOutput = Split(retValue, "REG_SZ")
        RInstallPath = Trim(arrOutput(1))
        RInstallPath = Replace(RInstallPath, Chr(13), "")
        GetRScriptPath = RInstallPath & "\bin\Rscript.exe"
        Exit Function
    End If
    
    ' If both attempts fail, return a not found message
    GetRScriptPath = "Rscript.exe not found via registry."
    Exit Function
    
ErrHandler:
    GetRScriptPath = "Error: " & Err.Description
End Function

Sub SaveWorkSpaceVariables()
    ' Save the current workbook path to global variable
    WorkSpacePath = ThisWorkbook.Path
    WorkSpacePathSystem = WorkSpacePath ' & Application.PathSeparator & "system"

    ' Save the name of current workbook to global variable
    WorkbookName = ThisWorkbook.Name

    ' Save the Rscript.exe path to global variable
    RScriptPath = GetRScriptPath()

End Sub

Sub RunRScript()
    Dim objShell As Object
    Dim RScriptFile As String
    Dim Command As String
    Dim k As Long
    
    k = 3
    
    ' Create WScript.Shell object
    Set objShell = CreateObject("WScript.Shell")
    
    ' Full path to the R script you want to execute
    RScriptFile = WorkSpacePathSystem & Application.PathSeparator & "TURF_linking.R"
    
    ' Build the command - using cmd /k keeps the window open
    Command = vbDoubleQuote & RScriptPath & vbDoubleQuote & " " & RScriptFile & " " & WorkSpacePathSystem & " " & k
    Command = Replace(Command, Chr(10), "") ' Hard fix for any line break
    
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets("Settings")
    ws.Range("Q3").Value = Command
    
    ' Run the command and keep the window open
    objShell.Run Command, 1, True
    
    Set objShell = Nothing
End Sub

Sub RunTURF()
    Call SaveWorkSpaceVariables
    Call RunRScript
End Sub
