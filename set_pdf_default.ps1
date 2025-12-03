$xmlPath = "C:\Temp\AdobeDefaults.xml"
$xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".pdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".pdfxml" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".acrobatsecuritysettings" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".fdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".xfdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
</DefaultAssociations>
"@

$xmlContent | Out-File -FilePath $xmlPath -Encoding UTF8

Write-Host "Importing Default Application Associations for New Users..."
# This applies to all NEW user profiles (essential for AVD)
Dism.exe /Online /Import-DefaultAppAssociations:$xmlPath

Write-Host "Verifying Image Defaults:"
Dism.exe /Online /Get-DefaultAppAssociations | Select-String "Adobe"
