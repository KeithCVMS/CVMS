function Test-OOBEComplete {
    [CmdletBinding()]
    param()

    if (-not ('Api.Kernel32' -as [type])) {
        $typeDef = @"
using System.Runtime.InteropServices;

namespace Api
{
    public static class Kernel32
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool OOBEComplete([MarshalAs(UnmanagedType.Bool)] out bool isOOBEComplete);
    }
}
"@
        Add-Type -TypeDefinition $typeDef -Language CSharp -ErrorAction Stop
    }

    $isComplete = $false
    $ok = [Api.Kernel32]::OOBEComplete([ref]$isComplete)  # out bool

    $lastErr = if (-not $ok) { [Runtime.InteropServices.Marshal]::GetLastWin32Error() } else { 0 }

    [pscustomobject]@{
        Success        = $ok
        Win32Error     = $lastErr
        IsOOBEComplete = $isComplete
    }
}
