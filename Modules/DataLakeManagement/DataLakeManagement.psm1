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

#region Connect-DataLakeSubscription 
<#
.SYNOPSIS
Connects to an Azure subscription

.DESCRIPTION
Connects to an Azure subscription and sets context to that subscription

.PARAMETER subscriptionName
Azure subscription to connect to and set context to 

.EXAMPLE
$subscriptionName = "Visual Studio Enterprise"
Connect-DataLakeSubscription -subscriptionName $subscriptionName 

.NOTES
#>
function Connect-DataLakeSubscription {
    param (
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName 

    )
    Write-Verbose "***********************Start Connect-DataLakeSubscription******************************************"
    $context = Get-AzContext
    if ($context -eq $null) {
        Connect-AzAccount -Subscription $subscriptionName | Out-Null
    }
    Write-Verbose "Connected to subscription $subscriptionName."
    Write-Verbose "***********************End Connect-DataLakeSubscription******************************************"
}
##Connect-DataLakeSubscription -subscriptionName $subscriptionName
#endregion Connect-DataLakeSubscription 

#region Connect-DataLakeStorageAccount 
<#
.SYNOPSIS
Connects to a data lake storage account

.DESCRIPTION
Connects and sets context to a data lake storage account

.PARAMETER subscriptionName
The name of the azure subscription which contains the data lake. 

.PARAMETER storageAccountName
The name of the data lake storage account.

.EXAMPLE
$subscriptionName = "Visual Studio Enterprise"
$storageAccountName = "myuniquestorageaccount"
Connect-DataLakeStorageAccount  -subscriptionName $subscriptionName `
                                -storageAccountName $storageAccountName

.NOTES
#>
function Connect-DataLakeStorageAccount { 
    param(
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName ,
        [Parameter(Mandatory=$true)]
        [string]$storageAccountName
    
    )
    Write-Verbose "***********************Start Connect-DataLakeStorageAccount******************************************"
    Connect-DataLakeSubscription -subscriptionName subscriptionName
    $ctx = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
    Write-Verbose "Connected to storage account $storageAccountName."
    return $ctx
    Write-Verbose "***********************End Connect-DataLakeStorageAccount******************************************"
}
##Connect-DataLakeStorageAccount -subscriptionName $subscriptionName -StorageAccountName $storageAccountName
#endregion Connect-DataLakeStorageAccount 

#region Set-DataLakeContainer 
<#
.SYNOPSIS
Creates or updates a data lake container

.DESCRIPTION
Creates a data lake container if it does not exist or updates it if already does

.PARAMETER subscriptionName
The name of the azure subscription which contains the data lake. 

.PARAMETER storageAccountName
The name of the data lake storage account.

.PARAMETER containerName
The name of the container for the data lake filesystem.

.EXAMPLE
$subscriptionName = "Visual Studio Enterprise"
$storageAccountName = "myuniquestorageaccount"
$containerName = "mytestlake"
Set-DataLakeContainer -subscriptionName $subscriptionName `
                      -storageAccountName $storageAccountName `
                      -containerName $containerName

.NOTES
#>
function Set-DataLakeContainer { 
    param(
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName ,
        [Parameter(Mandatory=$true)]
        [string]$storageAccountName,
        [Parameter(Mandatory=$true)]
        [string]$containerName    
    )
    Write-Verbose "***********************Start Set-DataLakeContainer******************************************"
    Connect-DataLakeSubscription -subscriptionName $subscriptionName
    $ctx = Connect-DataLakeStorageAccount -subscriptionName $subscriptionName `
        -StorageAccountName $storageAccountName

    Write-Verbose "If storage account container $containerName does not exists create..."
    if (!(Get-AzStorageContainer -Context $ctx `
                -Name $containerName `
                -ErrorAction SilentlyContinue)) {
        Write-Verbose "Storage account container $containerName does not exist so create."
        New-AzStorageContainer -Context $ctx `
            -Name $containerName `
            -Permission off
    }
    else {
        Write-Verbose "Storage account container $containerName does exist so do nothing."
    }

    Write-Verbose "***********************End Set-DataLakeContainer******************************************"
}
#endregion Set-DataLakeContainer 

#region Set-DataLakeContainerACL
<#
.SYNOPSIS
Applies ACL permissions to a data lake container

.DESCRIPTION
Applies ACL permissions to a data lake container for the active directory group and stated permissions supplied

.PARAMETER subscriptionName
The name of the azure subscription which contains the data lake. 

.PARAMETER storageAccountName
The name of the data lake storage account.

.PARAMETER containerName
The name of the container for the data lake filesystem.

.PARAMETER adgroupname
The name of the active directory group for ACLs to be applied for

.PARAMETER permissions
The permissions required for the active directory group on the ACL

.EXAMPLE
$subscriptionName = "Visual Studio Enterprise"
$storageAccountName = "myuniquestorageaccount"
$containerName = "mytestlake"
$adgroupname = "myadgroup"
$permissions =  "--x"
Set-DataLakeContainerACL -subscriptionName $subscriptionName `
    -storageAccountName $storageAccountName `
    -containerName $containerName `
    -adgroupname $adgroupname `
    -permissions $permissions 

.NOTES
#>
function Set-DataLakeContainerACL { 
    param(
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName ,
        [Parameter(Mandatory=$true)]
        [string]$storageAccountName,
        [Parameter(Mandatory=$true)]
        [string]$containerName ,
        [Parameter(Mandatory=$true)]
        [string]$adgroupname   ,
        [Parameter(Mandatory=$true)]
        [string]$permissions
    )

    Write-Verbose "***********************Start Set-DataLakeContainerACL******************************************"

    Connect-DataLakeSubscription -subscriptionName $subscriptionName
    $ctx = Connect-DataLakeStorageAccount -subscriptionName $subscriptionName `
        -StorageAccountName $storageAccountName

    Write-Verbose "Get object id of active directory group $adgroupname"
    $id = (Get-DataLakeActiveDirectoryGroup -adgroupname $adgroupname)
    
    Write-Verbose "Create ACL Object"
    [Collections.Generic.List[System.Object]]$acl
    Write-Verbose "Get current ACL Object of container $containerName"
    $acl = (Get-AzDataLakeGen2Item -Context $ctx `
            -FileSystem $containerName ).ACL
    Write-Verbose "Set permissions $permissions on acl object for ad group $adgroupname"
    $acl = Set-AzDataLakeGen2ItemAclObject   -AccessControlType Group `
        -EntityId $id `
        -Permission $permissions `
        -InputObject $acl
    Write-Verbose "Apply permissions $permissions to container  $containerName  for $adgroupname"
    Update-AzDataLakeGen2Item -Context $ctx `
        -FileSystem $containerName `
        -Acl $acl

    Write-Verbose "***********************End Set-DataLakeContainerACL******************************************"
}
#endregion Set-DataLakeContainerACL 

#region Set-DataLakeDirectory 
<#
.SYNOPSIS
Creates or updates a data lake directory

.DESCRIPTION
Creates a data lake directory if it does not exist and applies the metadata supplied or updates if it does exist.

.PARAMETER subscriptionName
The name of the azure subscription which contains the data lake. 

.PARAMETER storageAccountName
The name of the data lake storage account.

.PARAMETER containerName
The name of the container for the data lake filesystem.

.PARAMETER dirname
The data lake directory to be created

.PARAMETER metadata
The metadata to be appleid to the data lake directory in a hash table 

.EXAMPLE
$subscriptionName = "Visual Studio Enterprise"
$storageAccountName = "myuniquestorageaccount"
$containerName = "mytestlake"
$dirname = "raw\categorya"
$metadata =  @{"Business Owner"="Marketing";"Sensitive"="Yes"}
Set-DataLakeDirectory -subscriptionName $subscriptionName `
    -storageAccountName $storageAccountName `
    -containerName $containerName `
    -dirname $dirname `
    -metadata $metadata 

.NOTES
General notes
#>
function Set-DataLakeDirectory { 
    param(
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName ,
        [Parameter(Mandatory=$true)]
        [string]$storageAccountName,
        [Parameter(Mandatory=$true)]
        [string]$containerName    ,
        [Parameter(Mandatory=$true)]
        [string]$dirname ,
        [Parameter(Mandatory=$true)]
        [hashtable]$metadata
    )

    Write-Verbose "***********************Start Set-DataLakeDirectory******************************************"

    Write-Verbose "Check formatting of directory and throw error if incorrect"
    if ($dirname -like "*\*")
    {
        throw  "Directory $dirname in wrong format. Should use forward slashes. See output above."
    }

    Write-Verbose "Need to confirm read and write accounts exist for directory $dirname before continuing"
    $adgroups = @(Get-DataLakeConfigADGroups -directory $dirname).GroupName
    foreach($a in $adgroups)
    {
        Get-DataLakeActiveDirectoryGroup $a
    }

    Connect-DataLakeSubscription -subscriptionName $subscriptionName
    $ctx = Connect-DataLakeStorageAccount -subscriptionName $subscriptionName `
        -StorageAccountName $storageAccountName

    Write-Verbose "Attempt to get directory $dirname in container $containerName for storage account $storageAccountName"
    $dir = Get-AzDataLakeGen2Item -Context $ctx `
        -FileSystem $containerName `
        -Path $dirname `
        -ErrorAction SilentlyContinue

    if (!$dir ) {
        Write-Verbose "Directory $dirname does not exist so create"
        $dir = New-AzDataLakeGen2Item -Context $ctx `
            -FileSystem $containerName `
            -Path $dirname -Directory `
            -metadata $metadata
    }
    else {
        Write-Verbose "Directory $dirname does exist so update"
        $dir = Update-AzDataLakeGen2Item -Context $ctx `
            -FileSystem $containerName `
            -Path $dirname `
            -metadata $metadata
    }

    Write-Verbose "***********************End Set-DataLakeDirectory******************************************"

}
#endregion Set-DataLakeDirectory 

#region Get-DataLakeDirectoryPaths 
<#
.SYNOPSIS
Splits a directory path into each incrementing folder

.DESCRIPTION
Splits a directory path into each incrementing folder so as to get every route to the final directory folder. This is useful for ensuring execute is applied to every folder up to the destination. 

.PARAMETER dirname
The data lake directory to be created

.EXAMPLE
$dirname = "raw/stuff/categorya"
Get-DataLakeDirectoryPaths -dirname $dirname

.NOTES
#>
function Get-DataLakeDirectoryPaths { 
    param(
        [Parameter(Mandatory=$true)]
        [string]$dirname
    )

    Write-Verbose "***********************Start Get-DataLakeDirectoryPaths******************************************"

    Write-Verbose "Set empty variables for path and paths"
    $path = ""
    $paths = @()

    Write-Verbose "Split folders into array"
    $folders = @($dirname.Split('/'))

    Write-Verbose "Loop through each folder and build up incrementing paths"
    foreach ($folder in $folders) {
        Write-Verbose "Current folder is $folder"
        if ($path -eq "") {
            $path = $folder 
        }
        else {
            $path = $path + "/" + $folder 
        }
        Write-Verbose "Current path is $path"
        $paths += $path
    }
    return $paths
    Write-Verbose "***********************End Get-DataLakeDirectoryPaths******************************************"
}
#endregion Get-DataLakeDirectoryPaths 

#region Set-DataLakeDirectoryACL
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER subscriptionName
The name of the azure subscription which contains the data lake. 

.PARAMETER storageAccountName
The name of the data lake storage account.

.PARAMETER containerName
The name of the container for the data lake filesystem.

.PARAMETER dirname
The data lake directory to be created

.PARAMETER adgroupname
The name of the active directory group for ACLs to be applied for

.PARAMETER permissions
The permissions required for the active directory group on the ACL

.PARAMETER recursePermissions
Whether to recursively apply ACLs to all child items (currently WIP!)

.EXAMPLE
$subscriptionName = "Visual Studio Enterprise"
$storageAccountName = "myuniquestorageaccount"
$containerName = "mytestlake"
$dirname = "raw/categorya"
$adgroupname = "myadgroup"
$permissions =  "r-x"

Set-DataLakeDirectoryACL -subscriptionName $subscriptionName `
    -StorageAccountName $storageAccountName `
    -containerName $containerName `
    -dirname   $directory `
    -adgroupname $adgroupname `
    -permissions $permissions 

.NOTES
General notes
#>
function Set-DataLakeDirectoryACL { 
    param(
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName ,
        [Parameter(Mandatory=$true)]
        [string]$storageAccountName,
        [Parameter(Mandatory=$true)]
        [string]$containerName    ,
        [Parameter(Mandatory=$true)]
        [string]$dirname,
        [Parameter(Mandatory=$true)]
        [string]$adgroupname,
        [Parameter(Mandatory=$true)]
        [string]$permissions,
        [boolean]$recursePermissions = $false

    )
    
    Write-Verbose "***********************Start Set-DataLakeDirectoryACL******************************************"

    Connect-DataLakeSubscription -subscriptionName $subscriptionName
    $ctx = Connect-DataLakeStorageAccount -subscriptionName $subscriptionName `
        -StorageAccountName $storageAccountName

    Write-Verbose "Get object id of active directory group $adgroupname"
    $id = (Get-DataLakeActiveDirectoryGroup -adgroupname $adgroupname)

    Write-Verbose "Create ACL Object"
    [Collections.Generic.List[System.Object]]$acl
    Write-Verbose "Get current ACL Object of directory $dirname"
    $acl = (Get-AzDataLakeGen2Item -Context $ctx `
            -FileSystem $containerName `
            -Path $dirname).ACL
    Write-Verbose "Set permissions $permissions on acl object for ad group $adgroupname"
    $acl = Set-AzDataLakeGen2ItemAclObject   -AccessControlType Group `
        -EntityId $id `
        -Permission $permissions  -DefaultScope `
        -InputObject $acl
    Write-Verbose "Apply permissions $permissions to $dirname for $adgroupname"
    Update-AzDataLakeGen2Item -Context $ctx `
        -FileSystem $containerName `
        -Path $dirname `
        -Acl $acl

    Write-Verbose "Give execute permissions container for $adgroupname"
    Set-DataLakeContainerACL -subscriptionName $subscriptionName `
        -storageAccountName $storageAccountName `
        -containerName $containerName `
        -adgroupname $adgroupname `
        -permissions "--x"
    
    Write-Verbose "Loop through each directory up to the destination and apply execute permissions on each one for AD group $adgroupname"
    foreach ($path in Get-DataLakeDirectoryPaths ($dirname)) {
        Write-Host "Start grant execute on directory $path"
        Write-Verbose "Create ACL Object"
        [Collections.Generic.List[System.Object]]$aclexe
        Write-Verbose "Get current ACL Object of directory $path"
        $aclexe = (Get-AzDataLakeGen2Item -Context $ctx `
                -FileSystem $containerName `
                -Path $path).ACL
        Write-Verbose "Set execute permissions on acl object for ad group $adgroupname"
        $aclexe = Set-AzDataLakeGen2ItemAclObject -AccessControlType Group `
            -EntityId $id `
            -Permission "--x" `
            -InputObject $aclexe
        Write-Verbose "Apply execute permissions to $path for $adgroupname"
        Update-AzDataLakeGen2Item -Context $ctx `
            -FileSystem $containerName `
            -Path $path `
            -Acl $aclexe
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

    Write-Verbose "***********************End Set-DataLakeDirectoryACL******************************************"
}
#endregion Set-DataLakeDirectoryACL

#region Convert-DataLakePSObjectToHashTable
<#
.SYNOPSIS
Converts a powershell object into a hash table

.DESCRIPTION
Converts a powershell object into a hash table

.PARAMETER InputObject
The powershell object to convert into a hash table

.EXAMPLE
An example

.NOTES
https://stackoverflow.com/questions/3740128/pscustomobject-to-hashtable
https://omgdebugging.com/2019/02/25/convert-a-psobject-to-a-hashtable-in-powershell/
#>
function Convert-DataLakePSObjectToHashTable { 
    param ( 
        [Parameter(  
            Position = 0,   
            Mandatory = $true,   
            ValueFromPipeline = $true,  
            ValueFromPipelineByPropertyName = $true  
        )] [object] $psCustomObject 
    );
    Write-Verbose "***********************Start Convert-DataLakePSObjectToHashTable******************************************"

    $output = @{}; 
    $psCustomObject | Get-Member -MemberType *Property | % {
        $output.($_.name) = $psCustomObject.($_.name); 
    } 

    return  $output;

    Write-Verbose "***********************End Convert-DataLakePSObjectToHashTable******************************************"
}
#endregion Convert-DataLakePSObjectToHashTable

#region Get-DataLakeConfigADGroups
<#
.SYNOPSIS
Generates standard Active Directory group objects for directory supplied

.DESCRIPTION
Generates standard reader (rdr) and writer (wrt) Active Directory group objects for directory supplied and returns them as an array of objects

.PARAMETER environment
This is the environment for which the active directory groups will be created for. e.g. TEST, PROD, DEV or whatever you use. This will prefix the name of the active directory group. If blank there will be no prefix to the active directory group names.

.PARAMETER directory
The data lake directory path. 

.PARAMETER description
The description of the directory path. This will be appended with a description of whether can read or write directory depending on active directory group being created. 

.EXAMPLE
$environment = "test"
$directory = "raw/cata"
Get-DataLakeConfigADGroups  -directory $directory `
                            -environment $environment

.NOTES
General notes
#>
function Get-DataLakeConfigADGroups {
    param (
        [string]$environment = "",
        [Parameter(Mandatory=$true)]
        [string]$directory,
        [string]$description = ""
    )

    Write-Verbose "***********************Start Get-DataLakeConfigADGroups******************************************"

    $dirad = $directory.Replace("/", "")
    $administrativeUnit = $environment + "DataLake"

    $adgroups = New-Object System.Collections.ArrayList

    foreach ($p in @("rdr", "wrt")) {
        $adgroup = New-Object -TypeName psobject 
        $adgroupname = "${environment}datalake${dirad}$p"
        Write-Verbose "Configure permissions for AD group object $adgroupname"
        if ($p -eq "rdr") {
            $permissions = "r-x"
            $descriptionAD = $description + " This account has read permissions."
        }
        if ($p -eq "wrt") {
            $permissions = "-wx"
            $descriptionAD = $description + " This account has write permissions."
        }

        $adgroup | Add-Member  -MemberType NoteProperty  -Name GroupName -Value "datalake${dirad}$p"
        $adgroup | Add-Member  -MemberType NoteProperty  -Name PermissionType -Value $p
        $adgroup | Add-Member  -MemberType NoteProperty  -Name LakePermissions -Value $permissions
        $adgroup | Add-Member  -MemberType NoteProperty  -Name Description -Value $descriptionAD
        $adgroup | Add-Member  -MemberType NoteProperty  -Name AdministrativeUnit -Value $administrativeUnit

        $adgroups.Add($adgroup) | Out-Null
    }    
    return $adgroups
    
    Write-Verbose "***********************End Get-DataLakeConfigADGroups******************************************"
}
#endregion Get-DataLakeConfigADGroups

#region Get-DataLakeActiveDirectoryGroup
<#
.SYNOPSIS
Gets an active directory group id

.DESCRIPTION
Gets an active directory group id and errors if does not exist so acts as a check

.PARAMETER adgroupname
The name of the active directory group

.EXAMPLE
$adgroupname = "MyTestGroup"
Get-DataLakeActiveDirectoryGroup -adgroupname $adgroupname 

.NOTES
#>
function Get-DataLakeActiveDirectoryGroup {
    param (
        [Parameter(Mandatory=$true)]
        [string]$adgroupname
    )
    Write-Verbose "***********************Start Get-DataLakeActiveDirectoryGroup******************************************"
    Write-Verbose "Get object id of active directory group $adgroupname"
    $id = (Get-AzADGroup -DisplayName $adgroupname).Id
    if (!$id) {
        throw "$adgroupname not found in active directory so cannot continue to create ACL."
        break
    }
    else {
        Write-Verbose "$adgroupname  found in active directory so continue."
    }
    return $id
    Write-Verbose "***********************Start Get-DataLakeActiveDirectoryGroup******************************************"
}
#endregion Get-DataLakeActiveDirectoryGroup

#region Set-DataLakeDirectoryAssignment
<#
.SYNOPSIS
Deploys data lake folders, metadata and permissions from config file

.DESCRIPTION
Reads configuration content from JSON file that includes metadata around data lake folders. It checks to see if there are any duplicates as data lake file systems are not case sensitive so this prevents confusion. The depth of each directory from the config file is then esablished so that folders and their resultant permissions are generated from the top down and inherited appropriately. A loop then begins and each directory has its active directory group generated based on standards, the process expects one reader (rdr) and one writer (wrt) group. If these groups are not present the process will fail as folders should not be created until active directory groups are in place. If all the checks have then succeeded the folder is created with appropriate metadata along with the appropriate ACLs for the activity groups.

.PARAMETER environment
This is the environment for which the active directory groups will be created for. e.g. TEST, PROD, DEV or whatever you use. This will prefix the name of the active directory group. If blank there will be no prefix to the active directory group names.

.PARAMETER subscriptionName
The name of the azure subscription which contains the data lake. 

.PARAMETER storageAccountName
The name of the data lake storage account.

.PARAMETER containerName
The name of the container for the data lake filesystem.

.PARAMETER configFile
The path to the config file containins all the metadata. 

.EXAMPLE
$VerbosePreference = "continue"
$environment = "" 
$subscriptionName = "Visual Studio Enterprise" 
$storageAccountName = "griffvnetlk2"
$containerName = "mytestlake"
$configFile = "configuration\griff_raw.json"

Set-DataLakeDirectoryAssignment -environment $environment `
    -subscriptionName $subscriptionName `
    -storageAccountName $storageAccountName `
    -containerName $containerName `
    -configFile $configFile 

.NOTES
Data lakes folder structures are case insensitive so beware of duplication! This code handles it but worthwhile creating pester tests to monitor. 
Data lake folders should be deployed in order of directory depth so that each folder created inherits from above. This is now built-in. 
#>
function Set-DataLakeDirectoryAssignment {
    param (
        [string]$environment,
        [Parameter(Mandatory=$true)]
        [string]$subscriptionName,
        [Parameter(Mandatory=$true)]
        [string]$storageAccountName,
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$configFile
    )
    $ErrorActionPreference = "Stop" ##leave this as calls so many nested things want to maintain this

    Write-Verbose "***********************Start Set-DataLakeDirectoryAssignment******************************************"

    Write-Verbose "Get configuration of directories from json configuration file $configFile"
    $directories = (Get-Content -Raw -Path $configFile | ConvertFrom-Json) 

    Write-Verbose "Check for duplicates in configuration JSON and throw error if present"
    $duplicates = $directories | Group-Object -Property Directory -NoElement | Where-Object {$_.Count -gt 1}
    if($duplicates)
    {
        Write-Host $duplicates.Name
        throw  "Duplicate directories found in JSON. See output above."
    }

    Write-Verbose "Add depth property for each path to ensure top directory permissions get done first when sort by in loop"
    Write-Verbose "This means permissions get inherited appropriately"
    foreach ($d in $directories)
    {
        $depth = (($d.Directory).ToCharArray() | Where-Object {$_ -eq '/'} | Measure-Object).Count
        $d | Add-Member  -MemberType NoteProperty  -Name Depth -Value $depth
    }

    Write-Verbose "Loop through configured directories in order of depth and apply to data lake $storageAccountName container $containerName in subscription $subscriptionName"
    foreach ($d in $directories | Sort-Object -Property Depth ) {
        $directory = $d.directory 
        Write-Verbose "Start directory $directory"
        $metaobject = $d.metadata
        $metadata = @{}
        $metadata = Convert-DataLakePSObjectToHashTable ($metaobject)
        Write-Verbose "With metadata $metadata"

        Write-Verbose "Loop and apply permissions for both rdr and wrt groups"
        foreach ($adgroup in (Get-DataLakeConfigADGroups -environment $environment -directory $directory)) {
            $adgroupname = $adgroup.GroupName
            $permissions = $adgroup.LakePermissions

            Write-Verbose "Confirm group $adgroupname for directory $directory before continuing"
            Get-DataLakeActiveDirectoryGroup -adgroupname $adgroupname

            Write-Verbose "Permissions for AD group $adgroupname are $permissions"

            Set-DataLakeDirectory -subscriptionName $subscriptionName `
                -StorageAccountName $storageAccountName `
                -containerName $containerName `
                -dirname  $directory `
                -metadata $metadata

            Set-DataLakeDirectoryACL -subscriptionName $subscriptionName `
                -StorageAccountName $storageAccountName `
                -containerName $containerName `
                -dirname   $directory `
                -adgroupname $adgroupname `
                -permissions $permissions 
        }
    }

    Write-Verbose "***********************End Set-DataLakeDirectoryAssignment ******************************************"

}
#endregion Set-DataLakeDirectoryAssignment



