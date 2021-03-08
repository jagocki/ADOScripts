#credits to https://github.com/KevinMarquette/PSGraph
#Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
#choco install graphviz
#Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Find-Module PSGraph | Install-Module

# alternative ways of installing GraphViz are provided here
# https://graphviz.org/download/


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

.\GetMembershipREST.ps1 -orgName adamjag-demo
Get-ChildItem -Path *.csv | ForEach-Object { CreateGraph $_.Name }
