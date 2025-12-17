function Test-OOBEComplete {
    [CmdletBinding()]
    param()

    try {
        if (-not ('Api.Kernel32' -as [type])) {
            $typeDef = @"
using System.Runtime.InteropServices;

namespace Api
{
    public class Kernel32
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int OOBEComplete(ref int bIsOOBEComplete);
    }
}
"@
            Add-Type -TypeDefinition $typeDef -Language CSharp -ErrorAction Stop
        }

        $isComplete = 0
        $hr = [Api.Kernel32]::OOBEComplete([ref] $isComplete)

        [pscustomobject]@{
            Success        = ($hr -eq 0)
            HResult        = $hr
            IsOOBEComplete = ($isComplete -ne 0)
        }
    }
    catch {
        [pscustomobject]@{
            Success        = $false
            HResult        = $null
            IsOOBEComplete = $false
            Error          = $_.Exception.Message
        }
    }
}