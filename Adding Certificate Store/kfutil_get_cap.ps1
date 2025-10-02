$env:KFUTIL_EXP = 0
$env:KFUTIL_DEBUG = 0
$list = kfutil store-types templates-fetch
$hashTable = @{}
$list = $list | ConvertFrom-Json
$list.psobject.properties | ForEach-Object {$hashTable[$_.Name] = $_.Value}
$hashTable.keys