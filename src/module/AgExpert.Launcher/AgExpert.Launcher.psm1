$script:AgExpertModuleRoot = $PSScriptRoot
$script:AgExpertConfigRoot = $null
$script:AgExpertSettings = $null
$script:AgExpertRegistry = $null
$script:AgExpertAppRegistry = $null

foreach ($folder in 'Private', 'Public') {
    $folderPath = Join-Path $PSScriptRoot $folder
    if (-not (Test-Path $folderPath)) { continue }

    foreach ($file in Get-ChildItem -Path $folderPath -Filter '*.ps1' -File) {
        . $file.FullName
    }
}

$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File |
    Select-Object -ExpandProperty BaseName

Export-ModuleMember -Function $publicFunctions -Alias 'agexpert', 'app'
