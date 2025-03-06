Public Const vbDoubleQuote As String = """"
Public WorkSpacePath As String
Public WorkSpacePathSystem As String
Public WorkbookName As String
Public RScriptPath As String

Sub ImportUtils()
    Dim filePath As Variant
    Dim ws As Worksheet
    Dim csvWb As Workbook
    Dim csvWs As Worksheet
    Dim wb As Workbook
    
    ' Prompt the user to select a CSV file
    filePath = Application.GetOpenFilename("CSV Files (*.csv), *.csv", , "Select CSV File")
    If filePath = False Then Exit Sub  ' Exit if user cancels
    
    Set wb = ThisWorkbook
    
    ' Check if the "Utilities" sheet exists; if so, clear it, otherwise add a new sheet
    On Error Resume Next
    Set ws = wb.Sheets("Utilities")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = wb.Sheets.Add(After:=wb.Sheets(wb.Sheets.Count))
        ws.Name = "Utilities"
    Else
        ws.Cells.Clear
    End If
    
    ' Open the CSV file (it will open as a new workbook)
    Set csvWb = Workbooks.Open(filePath)
    Set csvWs = csvWb.Sheets(1)
    
    ' Copy the entire used range from the CSV sheet into the "Utilities" sheet
    csvWs.UsedRange.Copy Destination:=ws.Range("A1")
    
    ' Change headers
    ws.Cells(1, 1).Value = "id"
    ws.Cells(1, 2).Value = "weight"
    
    Dim numProds As Long
    numProds = wb.Sheets("Main").Range("num_prods")
    
    Dim addNone As Boolean
    addNone = wb.Sheets("Main").Range("add_none")
    
    If addNone Then
        numProds = numProds + 1
    End If
    
    Dim lastCol As Long
    lastCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column
    If (lastCol - 2) <> numProds Then
        csvWb.Close SaveChanges:=False
        MsgBox "Utilities file should contain " & (numProds + 2) & " columns"
        Exit Sub
    End If
    
    Dim methodology As String
    methodology = wb.Sheets("Main").Range("methodology")
    If methodology <> "CBC" Then
        If lastCol > 2 Then
            For i = 3 To lastCol
                ws.Cells(1, i).Value = "item" & (i - 2)
            Next i
        End If
    End If
    
    ' Clear all values in the second column (leaving the header intact)
    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 2).End(xlUp).Row
    If lastRow > 1 Then
        ws.Range(ws.Cells(2, 2), ws.Cells(lastRow, 2)).Value = 1
    End If
    
    ' Close the CSV workbook without saving changes
    csvWb.Close SaveChanges:=False
    
    ws.Activate
    MsgBox "All respondent weights have been set to 1. Remember to update the 'weight' column in the 'Utilities' sheet if you are using any respondent weights.", vbInformation, "Import Complete"
End Sub

Sub SetupTURF()
    
    Dim methodology As String
    methodology = ThisWorkbook.Sheets("Main").Range("methodology").Value
    
    Dim numProds As Long
    numProds = ThisWorkbook.Sheets("Main").Range("num_prods").Value

    Dim addNone As Boolean
    addNone = ThisWorkbook.Sheets("Main").Range("add_none").Value
    
    If methodology = "MaxDiff" And addNone Then
        MsgBox "For MaxDiff, Add none should be FALSE."
        Exit Sub
    End If
    
    If methodology = "Anchored MaxDiff" And Not addNone Then
        MsgBox "For Anchored MaxDiff, Add none should be TRUE."
        Exit Sub
    End If
    
    Dim ws As Worksheet
    If methodology = "CBC" Then
        ThisWorkbook.Sheets("CBC").Visible = True
        ThisWorkbook.Sheets("MaxDiff").Visible = False
        
        Set ws = ThisWorkbook.Sheets("CBC")
        
        ws.Activate
        ws.Range("cbc_calc").Value = "SoP"
        ws.Range("cbc_kpi").Value = "Preference"
    Else
        ThisWorkbook.Sheets("CBC").Visible = False
        ThisWorkbook.Sheets("MaxDiff").Visible = True
        
        Set ws = ThisWorkbook.Sheets("MaxDiff")
        
        ws.Activate
        ws.Range("maxdiff_calc").Value = "SoP"
    End If
    
    '------------------------------------------------------------------
    ' Reset Calculation method and Optimization KPI
    '------------------------------------------------------------------
    'ws.Range("B13").Value = "SoP"
    'ws.Range("B16").Value = "Preference Share"

    '------------------------------------------------------------------
    ' Clear the area for the new table
    '------------------------------------------------------------------
    ws.Range("G1:N1000").ClearContents

    '------------------------------------------------------------------
    ' Create the correct column headers based on methodology
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
    ' Add products Prod1 to ProdN and fill default values
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
    ' If "Add none option" is TRUE, add a "None" row at the end
    '------------------------------------------------------------------
    If addNone Then
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
    WorkSpacePathSystem = WorkSpacePath & Application.PathSeparator & "system"

    ' Save the name of current workbook to global variable
    WorkbookName = ThisWorkbook.Name

    ' Save the Rscript.exe path to global variable
    RScriptPath = GetRScriptPath()

End Sub

Sub RunRScript()
    
    Dim k As Variant
    k = InputBox("Please enter the number of items to draw:", "Numeric Input")
    
    If k = "" Then
        MsgBox "No value provided."
        Exit Sub
    End If
    
    Dim methodology As String
    methodology = ThisWorkbook.Sheets("Main").Range("methodology").Value
    
    Dim ws As Worksheet
    If methodology = "CBC" Then
        Set ws = ThisWorkbook.Sheets("CBC")
    Else
        Set ws = ThisWorkbook.Sheets("MaxDiff")
    End If
    
    Dim maxK As Long
    maxK = Application.WorksheetFunction.CountIfs(ws.Range("H:H"), "Client", Range("I:I"), "No")
    
    If Not IsNumeric(k) Or k > maxK Or k < 0 Then
        MsgBox "k should be a number greater than 0 and less than " & maxK
        Exit Sub
    End If
    
    ' Create WScript.Shell object
    Dim objShell As Object
    Set objShell = CreateObject("WScript.Shell")
    
    ' Full path to the R script you want to execute
    Dim RScriptFile As String
    RScriptFile = WorkSpacePathSystem & Application.PathSeparator & "TURF_linking.R"
    
    ' Build the command - using cmd /k keeps the window open
    Dim Command As String
    Command = vbDoubleQuote & RScriptPath & vbDoubleQuote & " " & RScriptFile & " " & WorkSpacePathSystem & " " & k
    Command = Replace(Command, Chr(10), "") ' Hard fix for any line break
    
    ws.Range("Q3").Value = Command
    
    ' Run the command and keep the window open
    objShell.Run Command, 1, True
    
    Set objShell = Nothing
End Sub

Sub RunTURF()
    Call SaveWorkSpaceVariables
    Call RunRScript
End Sub