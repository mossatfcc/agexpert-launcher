function ConvertTo-AgExpertKey {
    <#
        .SYNOPSIS
            Normalizes a product name for comparison, ignoring case, punctuation, and an API suffix.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][AllowNull()][string]$Name,
        [switch]$KeepApiSuffix
    )

    $key = $Name -replace '[^a-zA-Z0-9]', ''
    if (-not $KeepApiSuffix -and $key -match '.+api$') { $key = $key -replace 'api$', '' }
    $key.ToLowerInvariant()
}
