function Test-AgExpertVSCodeHost {
    <#
        .SYNOPSIS
            Indicates whether the current shell is a VS Code integrated terminal.
    #>
    [CmdletBinding()]
    param()

    $env:TERM_PROGRAM -eq 'vscode'
}
