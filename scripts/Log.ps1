$sw = [System.Diagnostics.Stopwatch]::StartNew()

Function Log() {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$false)] [String] $message )

	$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
	$tz = [Regex]::Replace([System.TimeZoneInfo]::Local.StandardName, '([A-Z])\w+\s*', '$1')
	$et = " TET: $($sw.Elapsed.ToString('hh\:mm\:ss'))"
	$fts = "$ts $tz "
	if ($message) { Write-Output "$($ts) $($tz): $message @$et"} else {write-output ""}
}