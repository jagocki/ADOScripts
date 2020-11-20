# set environment variable for current process

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

function GetMembersFromDescriptor {
    param (
        $descriptor, $projectName, $groupName, $indent
    )
    $indent += 2
    $lastResult = @()
    Write-Host (' ' * $indent) getting memebers of $groupName with $projectName
    $members = az devops security group membership list --id $descriptor --relationship members --detect false | ConvertFrom-Json 

    $memObjects = $members | Get-Member -Type NoteProperty
    foreach($item in $memObjects)
    {
        $memberDetails =  $members."$($item.Name)"
        Write-Host (' ' * $indent) 'member ->'  $memberDetails.subjectKind $memberDetails.displayName
        $lastResult += CreateMemeberRecord $memberDetails $descriptor
        
    }
    $indent -= 2
    return $lastResult
}
$sw = [Diagnostics.Stopwatch]::StartNew()

$orgMembers = @()
$CSVpath = "adamjag-msftCLI.csv"
$Env:AZURE_DEVOPS_EXT_PAT = ''


$projectName = "Parts Unlimited"
az devops configure --defaults project=$projectName organization=https://dev.azure.com/adamjag-msft
get-content .\adamjag_msft_pat.txt |  az devops login


$groups = az devops security group list --detect false | ConvertFrom-Json
$projectResult = @()
foreach($group in  $groups.graphGroups)
{
    write-host  "$($group.principalName) from $projectName"
    $projectResult += GetMembersFromDescriptor $group.descriptor $projectName $group.principalName 2
    if ($group.displayName -eq 'Project Valid Users')
    {
       $projectResult += CreateMemeberRecord $group $projectName
    }
}

$projectResult | export-csv -Path $CSVpath -NoTypeInformation -Delimiter ';'
$sw.Stop()
$sw.Elapsed


