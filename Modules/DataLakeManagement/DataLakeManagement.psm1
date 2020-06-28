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
Short description

.DESCRIPTION
Long description

.PARAMETER susbcriptionName
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Connect-DataLakeSubscription {
    param (
        [string]$susbcriptionName 

    )
    Write-Verbose "***********************Start Connect-DataLakeSubscription******************************************"
    $context = Get-AzContext
    if ($context -eq $null) {
        Connect-AzAccount -Subscription $susbcriptionName | Out-Null
    }
    Write-Verbose "Connected to subscription $susbcriptionName."
    Write-Verbose "***********************End Connect-DataLakeSubscription******************************************"
}
##Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
#endregion Connect-DataLakeSubscription 

#region Connect-DataLakeStorageAccount 
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER susbcriptionName
Parameter description

.PARAMETER storageAccountName
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Connect-DataLakeStorageAccount { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName
    
    )
    Write-Verbose "***********************Start Connect-DataLakeStorageAccount******************************************"
    Connect-DataLakeSubscription -susbcriptionName susbcriptionName
    $ctx = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
    Write-Verbose "Connected to storage account $storageAccountName."
    return $ctx
    Write-Verbose "***********************End Connect-DataLakeStorageAccount******************************************"
}
##Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName -StorageAccountName $storageAccountName
#endregion Connect-DataLakeStorageAccount 

#region Set-DataLakeContainer 
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER susbcriptionName
Parameter description

.PARAMETER storageAccountName
Parameter description

.PARAMETER containerName
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-DataLakeContainer { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName    
    )
    Write-Verbose "***********************Start Set-DataLakeContainer******************************************"
    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName `
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
Short description

.DESCRIPTION
Long description

.PARAMETER susbcriptionName
Parameter description

.PARAMETER storageAccountName
Parameter description

.PARAMETER containerName
Parameter description

.PARAMETER adgroupname
Parameter description

.PARAMETER permissions
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-DataLakeContainerACL { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName ,
        [string]$adgroupname   ,
        [string]$permissions = "--x"
    )

    Write-Verbose "***********************Start Set-DataLakeContainerACL******************************************"

    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName `
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
Short description

.DESCRIPTION
Long description

.PARAMETER susbcriptionName
Parameter description

.PARAMETER storageAccountName
Parameter description

.PARAMETER containerName
Parameter description

.PARAMETER dirname
Parameter description

.PARAMETER metadata
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-DataLakeDirectory { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName    ,
        [string]$dirname ,
        [hashtable]$metadata
    )

    Write-Verbose "***********************Start Set-DataLakeDirectory******************************************"

    Write-Verbose "Need to confirm read and write accounts exist for directory $dirname before continuing"
    $adgroups = @(Get-DataLakeConfigADGroups -directory $dirname).GroupName
    foreach($a in $adgroups)
    {
        Get-DataLakeActiveDirectoryGroup $a
    }

    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName `
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
Short description

.DESCRIPTION
Long description

.PARAMETER dirname
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-DataLakeDirectoryPaths { 
    param(
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

.PARAMETER susbcriptionName
Parameter description

.PARAMETER storageAccountName
Parameter description

.PARAMETER containerName
Parameter description

.PARAMETER dirname
Parameter description

.PARAMETER adgroupname
Parameter description

.PARAMETER permissions
Parameter description

.PARAMETER recursePermissions
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-DataLakeDirectoryACL { 
    param(
        [string]$susbcriptionName ,
        [string]$storageAccountName,
        [string]$containerName    ,
        [string]$dirname,
        [string]$adgroupname,
        [string]$permissions,
        [boolean]$recursePermissions = $false

    )
    
    Write-Verbose "***********************Start Set-DataLakeDirectoryACL******************************************"

    Connect-DataLakeSubscription -susbcriptionName $susbcriptionName
    $ctx = Connect-DataLakeStorageAccount -susbcriptionName $susbcriptionName `
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
    Set-DataLakeContainerACL -susbcriptionName $susbcriptionName `
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
Short description

.DESCRIPTION
Long description

.PARAMETER InputObject
Parameter description

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
Short description

.DESCRIPTION
Long description

.PARAMETER environment
Parameter description

.PARAMETER directory
Parameter description

.PARAMETER description
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-DataLakeConfigADGroups {
    param (
        [string]$environment,
        [string]$directory,
        [string]$description
    )

    Write-Verbose "***********************Start Get-DataLakeConfigADGroups******************************************"

    $dirad = $directory.Replace("/", "")
    $administrativeUnit = $environment + "DataLake"

    $adgroups = New-Object System.Collections.ArrayList

    foreach ($p in @("rdr", "wrt")) {
        $adgroup = New-Object -TypeName psobject 
        $adgroupname = "datalake${dirad}$p"
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
Get-DataLakeConfigADGroups -environment "Test" -directory "raw/yes" -description "la la."
#endregion Get-DataLakeConfigADGroups

#region Get-DataLakeActiveDirectoryGroup
<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER adgroupname
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-DataLakeActiveDirectoryGroup {
    param (
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
Short description

.DESCRIPTION
Long description

.PARAMETER susbcriptionName
Parameter description

.PARAMETER storageAccountName
Parameter description

.PARAMETER containerName
Parameter description

.PARAMETER path
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-DataLakeDirectoryAssignment {
    param (
        [string]$susbcriptionName,
        [string]$storageAccountName,
        [string]$containerName,
        [string]$path
    )
    $ErrorActionPreference = "Stop" ##leave this as calls so many nested things want to maintain this

    Write-Verbose "***********************Start Set-DataLakeDirectoryAssignment******************************************"

    Write-Verbose "Get configuration of directories from json configuration file $path"
    $directories = (Get-Content -Raw -Path $path | ConvertFrom-Json) 

    Write-Verbose "Add depth property for each path to ensure top directory permissions get done first when sort by in loop"
    Write-Verbose "This means permissions get inherited appropriately"
    foreach ($d in $directories)
    {
        $depth = (($d.Directory).ToCharArray() | Where-Object {$_ -eq '/'} | Measure-Object).Count
        $d | Add-Member  -MemberType NoteProperty  -Name Depth -Value $depth
    }

    Write-Verbose "Loop through configured directories in order of depth and apply to data lake $storageAccountName container $containerName in subscription $susbcriptionName"
    foreach ($d in $directories | Sort-Object -Property Depth ) {
        $directory = $d.directory 
        Write-Verbose "Start directory $directory"
        $metaobject = $d.metadata
        $metadata = @{}
        $metadata = Convert-DataLakePSObjectToHashTable ($metaobject)
        Write-Verbose "With metadata $metadata"

        Write-Verbose "Loop and apply permissions for both rdr and wrt groups"
        foreach ($adgroup in (Get-DataLakeConfigADGroups -directory $directory)) {
            $adgroupname = $adgroup.GroupName
            $permissions = $adgroup.LakePermissions

            Write-Verbose "Confirm group $adgroupname for directory $directory before continuing"
            Get-DataLakeActiveDirectoryGroup -adgroupname $adgroupname

            Write-Verbose "Permissions for AD group $adgroupname are $permissions"

            Set-DataLakeDirectory -susbcriptionName $susbcriptionName `
                -StorageAccountName $storageAccountName `
                -containerName $containerName `
                -dirname  $directory `
                -metadata $metadata

            Set-DataLakeDirectoryACL -susbcriptionName $susbcriptionName `
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



