#ConvertTo-Json -InputObject $template -Depth 1024 | Out-File -File testTemplate.json -Force
$json = Get-Content 'parameters.json' | Out-String | ConvertFrom-Json 
$json.parameters | Add-Member -PassThru NoteProperty vmName @{value='BC-Test-DimaTTTTTTT'}
$json | ConvertTo-JSON -Depth 1024 | Out-File -File parameters2.json -Force;
