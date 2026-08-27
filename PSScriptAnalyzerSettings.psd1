@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Get-AgExpertProxyPublishedPorts and Get-AgExpertSettings return collections and a
        # settings object; the plural reads correctly and matches the config vocabulary.
        'PSUseSingularNouns',

        # Status output is deliberately console-only. These commands report to an interactive
        # operator and must not emit that text onto the pipeline as data.
        'PSAvoidUsingWriteHost'
    )
}
