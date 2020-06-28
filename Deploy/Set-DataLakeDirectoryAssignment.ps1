clear-host
$VerbosePreference = "continue"
$susbcriptionName = "Visual Studio Enterprise" 
$storageAccountName = "griffvnetlk2"
$containerName = "mytestlake"
$path = "configuration\griff_raw.json"

Import-Module ".\Modules\DataLakemanagement"

Set-DataLakeDirectoryAssignment -subscriptionName $susbcriptionName `
    -storageAccountName $storageAccountName `
    -containerName $containerName `
    -path $path
