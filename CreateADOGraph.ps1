#credits to https://github.com/KevinMarquette/PSGraph

# Install GraphViz from the Chocolatey repo
# Register-PackageSource -Name Chocolatey -ProviderName Chocolatey -Location http://chocolatey.org/api/v2/
# Find-Package graphviz | Install-Package -ForceBootstrap

# Install PSGraph from the Powershell Gallery
#Find-Module PSGraph | Install-Module

# Install-Module -Name PSGraph -RequiredVersion 2.1.35
# Import Module
# choco install graphviz
Import-Module PSGraph

function CreateGraph {
    param (
        $fileName
    )

$membership = Import-Csv -Path $fileName -Delimiter ";"

graph g {
    node $membership -NodeScript { $_.descriptor} @{label={$_.DisplayName}}
    edge $membership -FromScript {$_.ParentDescriptor} -ToScript {$_.descriptor}
} | Export-PSGraph -ShowGraph

}

.\GetMembershipREST.ps1

CreateGraph "filename.csv"

