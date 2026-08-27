function Test-AgExpertPortResponding {
    <#
        .SYNOPSIS
            Returns whether a TCP port is accepting connections.
        .DESCRIPTION
            Attempts a short-timeout TCP connect so environment readiness can be polled without
            blocking indefinitely on a port that is not up yet.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)][int]$Port,
        [Parameter(Position = 1)][string]$ComputerName = 'localhost',
        [int]$TimeoutMilliseconds = 1000
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) { return $false }
        try {
            $client.EndConnect($async)
            return $true
        }
        catch {
            return $false
        }
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}
