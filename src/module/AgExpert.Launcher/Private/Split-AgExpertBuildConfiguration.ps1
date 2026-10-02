function Split-AgExpertBuildConfiguration {
    <#
        .SYNOPSIS
            Separates an Angular build configuration word from the other command arguments.
        .DESCRIPTION
            Configuration names never collide with app names or targets, so the word may appear
            anywhere after the app (for example 'field localized' or 'field client localized').
            Returns the configuration ('default' when none is given) and the remaining arguments.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param([Parameter(Position = 0)][AllowNull()][AllowEmptyCollection()][string[]]$Arguments)

    $configurations = @('default', 'localized', 'development', 'production')
    $configuration = 'default'
    $remaining = [System.Collections.Generic.List[string]]::new()

    foreach ($argument in @($Arguments | Where-Object { $_ })) {
        if ($configurations -contains $argument) {
            $configuration = $argument.ToLowerInvariant()
        }
        else {
            $remaining.Add($argument)
        }
    }

    [pscustomobject]@{ Configuration = $configuration; Remaining = $remaining.ToArray() }
}
