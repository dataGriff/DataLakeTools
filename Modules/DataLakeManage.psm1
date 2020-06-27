##Uninstall-AzureRm
##Import-Module Az.Storage -force  -RequiredVersion 1.14
##Install-Module Az.Storage -Repository PSGallery -Force  
##Install-Module -Name Az.Storage -RequiredVersion 1.13.3-preview -allowclobber -force
##Import-Module -Name Az.Storage -Version 1.14.0
##install-module az.resources -force
##Get-Module
##remove-module Az.Storage 
##echo $PSVersionTable.PSVersion.ToString() 
##Get-Command -ListImported -Module Az.Storage

clear-host
$VerbosePreference ="continue"
$susbcriptionName = "Visual Studio Enterprise" 
$storageAccountName = "griffvnetlk2"
$containerName = "mytestlake"
$dirname = "raw/yes"
$adgroupname = "datalakerawyesrdr"

#region Connect-DataLakeSubscription 
function Connect-DataLakeSubscription {
    param (
        [string]$susbcriptionName 

    )
    $context = Get-AzContext
    if ($context -eq $null) {
        Connect-AzAccount -Subscription $susbcriptionName | Out-Null
    }
}
##Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
#endregion Connect-DataLakeSubscription 

#region Connect-DataLakeStorageAccount 
function Connect-DataLakeStorageAccount { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName
    
    )
    Connect-DataLakeSubscription -susbcriptionName susbcriptionName
    $ctx = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
    return $ctx
}
##Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName
#endregion Connect-DataLakeStorageAccount 

#region Set-DataLakeContainer 
function Set-DataLakeContainer { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName    
    )
    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName
    if (!(Get-AzStorageContainer -Context $ctx -Name $containerName -ErrorAction SilentlyContinue)) {
        New-AzStorageContainer -Context $ctx -Name $containerName -Permission off
    }
}
Set-DataLakeContainer -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName -containerName $containerName
#endregion Set-DataLakeContainer 

#region Set-DataLakeContainerACL
function Set-DataLakeContainerACL { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName ,
        [string]$adgroupname   ,
        [string]$permissions="--x"
    )

    Write-Verbose "***********************Start Set-DataLakeContainerACL******************************************"

    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName

    $id = (Get-AzADGroup -DisplayName $adgroupname).Id

    Write-Verbose "Create new acl object"
    [Collections.Generic.List[System.Object]]$acl
    Write-Verbose "Get current acl object"
    $acl = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName).ACL
    Write-Verbose "Add permissions to acl object"
    $acl = Set-AzDataLakeGen2ItemAclObject -AccessControlType Group -EntityId $id -Permission $permissions 
    Write-Verbose "Update acl on container with the new acl object created"
    Update-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName -Acl $acl

    Write-Verbose "***********************End Set-DataLakeContainerACL******************************************"
}
##Set-DataLakeContainerACL -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName -containerName $containerName -adgroupname $adgroupname
#endregion Set-DataLakeContainerACL 

#region Set-DataLakeDirectory 
function Set-DataLakeDirectory { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName    ,
        [string]$dirname,
        [string]$adgroupname   

    )
    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName

    Write-Verbose "Attempt to get directory $dirname in container $containerName for storage account $storageAccountName"
    $dir = Get-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName -Path $dirname -ErrorAction SilentlyContinue
    if (!$dir ) {
        Write-Verbose "Directory does not exist so create"
        $dir = New-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName -Path $dirname -Directory
    }
    else {
        Write-Verbose "Directory does exist so don't create"
    }

}
Set-DataLakeDirectory -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName -containerName $containerName -dirname $dirname
#endregion Set-DataLakeDirectory 

function Get-DataLakeDirectoryPaths { 
    param(
        [string]$dirname
    )

    $path = ""
    $paths = @()
    $folders = @($dirname.Split('/'))
    foreach ($folder in $folders) {
        if ($path -eq "") {
            $path = $folder 
        }
        else {
            $path = $path + "/" + $folder 
        }
        $paths += $path
    }
    return $paths
}

#region Set-DataLakeDirectoryACL
function Set-DataLakeDirectoryACL { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName    ,
        [string]$dirname,
        [boolean]$recursePermissions = $false

    )
    
    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName
    $id = (Get-AzADGroup -DisplayName $adgroupname).Id

    # First do the final directory permissions
    [Collections.Generic.List[System.Object]]$acl
    $acl = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName -Path $dirname).ACL
    $acl =  Set-AzDataLakeGen2ItemAclObject   -AccessControlType Group -EntityId $id -Permission "r-x" -DefaultScope -InputObject $acl
    Update-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName -Path $dirname -Acl $acl

    # Give exe on container
    Set-DataLakeContainerACL -susbcriptionName $susbcriptionName -storageAccountName $storageAccountName -containerName $containerName -adgroupname $adgroupname
    
    #Then loop back up the chain to ensure that execute is applied to all root directories
    foreach ($path in Get-DataLakeDirectoryPaths ($dirname)) {
            write-Host "Grant execute on directory $path"
           [Collections.Generic.List[System.Object]]$aclexe
           $aclexe = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName -Path $path).ACL
           $aclexe = Set-AzDataLakeGen2ItemAclObject -AccessControlType Group -EntityId $id -Permission "--x" -InputObject $aclexe
           Update-AzDataLakeGen2Item -Context $ctx -FileSystem $containerName -Path $path -Acl $aclexe
    }

    <#
    #If need to reset permissions on all folders and files below directory again, choose recursePermissions is true
    if ($recursePermissions) {
        $Token = $Null
        do {
            $items = Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem $containerName -Recurse -ContinuationToken $Token -Path  $dirname
            Write-Output $items
            if ($items.Count -le 0) { Break; }
            $items | Update-AzDataLakeGen2Item -Acl $acl
            $Token = $items[$items.Count - 1].ContinuationToken;
        }
        While ($Token -ne $Null) 
    }
    #>
}
Set-DataLakeDirectoryACL -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName -containerName $containerName -dirname $dirname -adgroupname $adgroupname -recursePermissions $true
#endregion Set-DataLakeDirectoryACL



