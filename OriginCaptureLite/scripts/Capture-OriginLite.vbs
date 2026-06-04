Option Explicit

Dim fso, shell, root, captureCsv, exceptionCsv
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

root = fso.GetParentFolderName(WScript.ScriptFullName)
captureCsv = fso.BuildPath(root, "surface_release_capture.csv")
exceptionCsv = fso.BuildPath(fso.BuildPath(root, "logs"), "exceptions.csv")

If Not fso.FolderExists(fso.BuildPath(root, "logs")) Then
  fso.CreateFolder(fso.BuildPath(root, "logs"))
End If

EnsureCsv captureCsv, "SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO"
EnsureCsv exceptionCsv, "ERROR_TYPE,SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO,ERROR_MESSAGE"

ShowHeader "CAPTURING", "Capturing device information..."

Dim serialNumber, manufacturer, deviceInfo
serialNumber = FirstValue(Array( _
  QuerySingleValue("Win32_BIOS", "SerialNumber"), _
  QuerySingleValue("Win32_ComputerSystemProduct", "IdentifyingNumber") _
))
manufacturer = QuerySingleValue("Win32_ComputerSystem", "Manufacturer")
deviceInfo = QuerySingleValue("Win32_ComputerSystem", "Model")

If IsBlank(serialNumber) Then
  LogException "CAPTURE_VALIDATION_FAILED", "", manufacturer, deviceInfo, "Serial number is blank."
  ShowFailure "Serial number is blank."
  WScript.Quit 1
End If

If IsBlank(manufacturer) Then
  LogException "CAPTURE_VALIDATION_FAILED", serialNumber, "", deviceInfo, "Manufacturer is blank."
  ShowFailure "Manufacturer is blank."
  WScript.Quit 1
End If

If IsBlank(deviceInfo) Then
  LogException "CAPTURE_VALIDATION_FAILED", serialNumber, manufacturer, "", "Device info is blank."
  ShowFailure "Device info is blank."
  WScript.Quit 1
End If

If SerialExists(captureCsv, serialNumber) Then
  LogException "DUPLICATE_SERIAL", serialNumber, manufacturer, deviceInfo, "Duplicate serial detected before append."
  ShowHeader "DUPLICATE SERIAL", "DUPLICATE SERIAL DETECTED"
  ShowData serialNumber, manufacturer, deviceInfo, captureCsv
  WScript.Echo "This serial number already exists in the current capture output. Review before proceeding."
  WScript.Quit 2
End If

AppendLine captureCsv, CsvLine(Array(serialNumber, manufacturer, deviceInfo))

ShowHeader "SUCCESS", "ORIGIN INFO GATHERED"
WScript.Echo "Device identity captured and saved successfully."
WScript.Echo ""
ShowData serialNumber, manufacturer, deviceInfo, captureCsv
WScript.Echo "It is safe to power off this device or move to the next unit."
WScript.Quit 0

Function QuerySingleValue(className, propertyName)
  On Error Resume Next
  Dim svc, items, item, value
  QuerySingleValue = ""
  Set svc = GetObject("winmgmts:\\.\root\cimv2")
  If Err.Number <> 0 Then
    Err.Clear
    Exit Function
  End If
  Set items = svc.ExecQuery("SELECT " & propertyName & " FROM " & className)
  If Err.Number <> 0 Then
    Err.Clear
    Exit Function
  End If
  For Each item In items
    value = Trim(CStr(item.Properties_(propertyName).Value))
    If Len(value) > 0 Then
      QuerySingleValue = value
      Exit Function
    End If
  Next
End Function

Function FirstValue(values)
  Dim i
  FirstValue = ""
  For i = LBound(values) To UBound(values)
    If Not IsBlank(values(i)) Then
      FirstValue = Trim(CStr(values(i)))
      Exit Function
    End If
  Next
End Function

Function IsBlank(value)
  IsBlank = Len(Trim(CStr(value))) = 0
End Function

Sub EnsureCsv(path, header)
  If fso.FileExists(path) Then
    Dim current, reader, archive
    Set reader = fso.OpenTextFile(path, 1, False)
    If Not reader.AtEndOfStream Then current = reader.ReadLine Else current = ""
    reader.Close
    If current <> header Then
      archive = path & ".old-format-" & TimestampForFile() & ".csv"
      fso.MoveFile path, archive
    End If
  End If
  If Not fso.FileExists(path) Then
    AppendLine path, header
  End If
End Sub

Sub AppendLine(path, line)
  Dim file
  Set file = fso.OpenTextFile(path, 8, True)
  file.WriteLine line
  file.Close
End Sub

Function SerialExists(path, serial)
  SerialExists = False
  If Not fso.FileExists(path) Then Exit Function
  Dim file, line, needle
  needle = """" & UCase(serial) & """"
  Set file = fso.OpenTextFile(path, 1, False)
  Do Until file.AtEndOfStream
    line = UCase(file.ReadLine)
    If InStr(1, line, needle, vbTextCompare) > 0 Then
      SerialExists = True
      Exit Do
    End If
  Loop
  file.Close
End Function

Function CsvLine(values)
  Dim i, output
  output = ""
  For i = LBound(values) To UBound(values)
    If i > LBound(values) Then output = output & ","
    output = output & CsvEscape(values(i))
  Next
  CsvLine = output
End Function

Function CsvEscape(value)
  CsvEscape = """" & Replace(CStr(value), """", """""") & """"
End Function

Sub LogException(errorType, serial, maker, info, message)
  AppendLine exceptionCsv, CsvLine(Array(errorType, serial, maker, info, message))
End Sub

Sub ShowFailure(message)
  ShowHeader "FAILED CAPTURE", "CAPTURE FAILED"
  WScript.Echo "Origin could not collect the required device information. Review this device before continuing."
  WScript.Echo ""
  WScript.Echo message
  WScript.Echo "Exception log was saved if the USB was writable."
End Sub

Sub ShowHeader(state, message)
  WScript.Echo ""
  WScript.Echo "===================================================================================================="
  WScript.Echo " ORIGIN CAPTURE LITE"
  WScript.Echo " Device Identity & Serialization Capture"
  WScript.Echo "===================================================================================================="
  WScript.Echo ""
  WScript.Echo " STATE: " & state
  WScript.Echo ""
  WScript.Echo " " & message
  WScript.Echo ""
  WScript.Echo "----------------------------------------------------------------------------------------------------"
  WScript.Echo ""
  WScript.Echo " Designed and developed by Jordan Brown | LDG Systems"
  WScript.Echo ""
End Sub

Sub ShowData(serial, maker, info, csvPath)
  WScript.Echo " Serial Number : " & serial
  WScript.Echo " Manufacturer  : " & maker
  WScript.Echo " Model         : " & info
  WScript.Echo " CSV Path      : " & csvPath
  WScript.Echo " Timestamp     : " & Now
  WScript.Echo ""
  WScript.Echo "----------------------------------------------------------------------------------------------------"
  WScript.Echo ""
End Sub

Function TimestampForFile()
  Dim d
  d = Now
  TimestampForFile = Year(d) & Right("0" & Month(d), 2) & Right("0" & Day(d), 2) & "-" & Right("0" & Hour(d), 2) & Right("0" & Minute(d), 2) & Right("0" & Second(d), 2)
End Function
