clear-host
$VerbosePreference = "continue"
$environment = "" 
$subscriptionName = "Visual Studio Enterprise" 
$storageAccountName = "griffvnetlk2"
$containerName = "mytestlake"
$configFile = "configuration\griff_raw.json"

##Remove-Module DataLakemanagement
Import-Module ".\Modules\DataLakemanagement"

Set-DataLakeDirectoryAssignment -environment $environment `
    -subscriptionName $subscriptionName `
    -storageAccountName $storageAccountName `
    -containerName $containerName `
    -configFile $configFile 
    
