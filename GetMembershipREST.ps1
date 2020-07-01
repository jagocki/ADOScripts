function CreateMemeberRecord{
    param ($memberDetails, $parentDescriptor)

    $memberProperties = 
    @{
        descriptor = $memberDetails.descriptor
        ProjectName = $projectName
        DisplayName = $memberDetails.displayName
        Origin = $memberDetails.origin
        Type = $memberDetails.subjectKind
        Domain = $memberDetails.domain
        MailAddress = $memberDetails.mailAddress
        ParentDescriptor = $parentDescriptor    
    }
    return New-Object PSObject -Property $memberProperties
}

function GetMembersFromDescriptorREST {
    param (
        $descriptor, $orgName, $groupName, $indent, $authheader
    )
    $indent += 2
    $lastResult = @()
    Write-Host (' ' * $indent) getting memebers of $groupName with $projectName
    # $members = az devops security group membership list --id $descriptor --relationship members --detect false | ConvertFrom-Json 

    $memberShipUri = "https://vssps.dev.azure.com/$orgName/_apis/Graph/Memberships/" + $descriptor + "?direction=down"
    $members = Invoke-RestMethod -Uri $memberShipUri -Method Get -ContentType "application/json" -Headers $header

    #| ConvertFrom-Json
    #[--relationship {memberof, members}]
    # Write-Host $members
    $memObjects = $members.value 
    # | Get-Member -Type NoteProperty
    foreach($item in $memObjects)
    {
        #get descriptor details
        $lookupUri = "https://vssps.dev.azure.com/$orgName/_apis/graph/subjectlookup?api-version=5.1-preview.1"

        $body= @{
            'lookupKeys' = @(@{'descriptor' = "$($item.memberDescriptor)" })
                } | ConvertTo-Json
        $response = Invoke-RestMethod -Method Post -ContentType 'application/json' -Uri $lookupUri -Body $body -Headers $authheader
        $memberDetails = $response.value."$($item.memberDescriptor)"
        Write-Host (' ' * $indent) 'member ->'  $memberDetails.subjectKind $memberDetails.displayName

        $lastResult += CreateMemeberRecord $memberDetails $($item.containerDescriptor)
        
    }
    $indent -= 2
    return $lastResult
}
$sw = [Diagnostics.Stopwatch]::StartNew()

$pat = "PAT"

Write-Host "Initialize authentication context" -ForegroundColor Yellow
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$header = @{authorization = "Basic $token"}

$orgName = "ORGNAME"

$groupsUri = "https://vssps.dev.azure.com/$orgName/_apis/graph/groups"
$groups = Invoke-RestMethod -Uri $groupsUri -Method Get -ContentType "application/json" -Headers $header

$projectName = "Parts Unlimited"
$CSVpath = "$orgName-REST.csv"

$projectResult = @()

$groups = $groups.value | where { $_.principalName -like "*$projectName*"  }

foreach($group in $groups)
{
    write-host  "$($group.principalName) from $projectName"
    $projectResult += GetMembersFromDescriptorREST $group.descriptor $orgName $group.principalName 2 $header
    if ($group.displayName -eq 'Project Valid Users')
    {
       $projectResult += CreateMemeberRecord $group $projectName
    }
    
}
$projectResult | export-csv -Path $CSVpath -NoTypeInformation -Delimiter ';'
$sw.Stop()
$sw.Elapsed