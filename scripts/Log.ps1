$sw = [System.Diagnostics.Stopwatch]::StartNew()

function Log {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Message = '',

        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO',

        [switch]$NoTimestamp
    )

    # Support blank line logging cleanly
    if ([string]::IsNullOrEmpty($Message)) {
        if ($script:LogFile) {
            try { Add-Content -LiteralPath $script:LogFile -Value '' -Encoding UTF8 } catch {}
        }
        Write-Host ''
        return
    }

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = if ($NoTimestamp) {
        $Message
    } else {
        "[$timestamp] [$Level] $Message"
    }

    if ($script:LogFile) {
        try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 } catch {}
    }

    # IMPORTANT: no Write-Output
    Write-Host $line
}
