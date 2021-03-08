param($orgName, $projectName)

function GetMemberDetails{ 
    param($orgName, $memberDescriptor, $authheader, $indent)

    $lookupUri = "https://vssps.dev.azure.com/$orgName/_apis/graph/subjectlookup?api-version=5.1-preview.1"

    $body= @{
        'lookupKeys' = @(@{'descriptor' = "$($memberDescriptor)" })
            } | ConvertTo-Json
    $response = Invoke-RestMethod -Method Post -ContentType 'application/json' -Uri $lookupUri -Body $body -Headers $authheader
    $memberDetails = $response.value."$($memberDescriptor)"
    Write-Host (' ' * $indent) 'member ->'  $memberDetails.subjectKind $memberDetails.displayName
    return $memberDetails 
}

function CreateMemeberRecord{
    param ($memberDetails, $parentDescriptor)

    $memberProperties = 
    @{
        descriptor = $memberDetails.descriptor
        ProjectName = $projectName
        PrincipalName = $memberDetails.principalName
        DisplayName = $memberDetails.displayName
        Origin = $memberDetails.origin
        Type = $memberDetails.subjectKind
        Domain = $memberDetails.domain
        MailAddress = $memberDetails.mailAddress
        ParentDescriptor = $parentDescriptor    
    }
    return New-Object PSObject -Property $memberProperties
}

function GetDescriptorMembership {
    param (
        $descriptor, $orgName, $authheader, $direction
    )
    $memberShipUri = "https://vssps.dev.azure.com/$orgName/_apis/Graph/Memberships/" + $descriptor + "?direction=$direction"
    $members = Invoke-RestMethod -Uri $memberShipUri -Method Get -ContentType "application/json" -Headers $header
    return $members.value 
}


function GetMembersFromDescriptorREST {
    param (
        $descriptor, $orgName, $groupName, $indent, $authheader
    )
    $indent += 2
    Write-Host (' ' * $indent) getting memebers of $groupName with $projectName
    $lastResult = @()
    $membersObjects = GetDescriptorMembership $descriptor $orgName $authheader 'down'
    foreach($item in $membersObjects)
    {
        $memberDetails = GetMemberDetails $orgName $item.memberDescriptor $authheader $indent
        $lastResult += CreateMemeberRecord $memberDetails $($item.containerDescriptor)
    }
    $indent -= 2
    return $lastResult
}

function GetMembersOfFromDescriptorREST {
    param (
        $descriptor, $orgName, $identityName, $indent, $authheader
    )
    $indent += 2
    Write-Host (' ' * $indent) getting groupps of $identityName with $projectName
    $lastResult = @()
    $membersObjects = GetDescriptorMembership $descriptor $orgName $authheader 'up'
    foreach($item in $membersObjects)
    {
        $memberDetails = GetMemberDetails $orgName $item.containerDescriptor $authheader $indent
        $lastResult += CreateMemeberRecord $memberDetails $orgName
    }
    $indent -= 2
    return $lastResult
}


$sw = [Diagnostics.Stopwatch]::StartNew()

$pat = get-content .\pat.txt

Write-Host "Initialize authentication context" -ForegroundColor Yellow
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$header = @{authorization = "Basic $token"}

$groupsUri = "https://vssps.dev.azure.com/$orgName/_apis/graph/groups"
$groupsResponse = Invoke-RestMethod -Uri $groupsUri -Method Get -ContentType "application/json" -Headers $header

$projectsUrl = "https://dev.azure.com/$orgName/_apis/projects?api-version=5.0"

$projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $header

$projects.value | ForEach-Object {

    $projectName = $_.name
    $projectResult = @()

    #we get the flat list of project's group
    #process each of them, get its direct membership and add to the results
    $projectGroups = $groupsResponse.value | where { $_.principalName -like "*$projectName*"  }

    foreach($group in $projectGroups)
    {
        write-host  "$($group.principalName) from $projectName"
        $projectResult += GetMembersFromDescriptorREST $group.descriptor $orgName $group.principalName 2 $header
        if ($group.displayName -eq 'Project Valid Users')
        {
            $projectResult += CreateMemeberRecord $group $projectName
        }
    }

    #to fix issue #2 we need to add to the project scoped membership the membership to organization scoped groups 
    # we reiterate the lists to find the 'up' directed membership
    $discoveredOrgScopedIdentities = @()
    $uniqueProjectDescriptors = $projectResult | select descriptor -Unique
    foreach($itemDescriptor in $uniqueProjectDescriptors  )
    {
        $proejctIdentity = $projectResult | Where-Object {$_.descriptor -eq $itemDescriptor.descriptor} 
        $identityMemberOfObjects = GetMembersOfFromDescriptorREST $proejctIdentity.descriptor $orgName $proejctIdentity.principalName 2 $header
       
        foreach ($parentIdentity in $identityMemberOfObjects)
        {
            if( $projectGroups.descriptor -notcontains $parentIdentity.descriptor)
            {
                $parentDetails = GetMemberDetails $orgName $parentIdentity.descriptor $header 0
                $discoveredOrgScopedIdentities += CreateMemeberRecord $parentDetails $orgName
                $discoveredOrgScopedIdentities += CreateMemeberRecord $proejctIdentity $parentIdentity.descriptor
            }
        }
    }
    $projectResult += $discoveredOrgScopedIdentities

    $CSVpath = "$orgName-$projectName-memebership.csv"
    $projectResult | export-csv -Path $CSVpath -NoTypeInformation -Delimiter ';' 
}

$sw.Stop()
$sw.Elapsed