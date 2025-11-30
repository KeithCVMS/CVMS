	Function Log() {
		[CmdletBinding()]
		param (
			[Parameter(Mandatory=$false)] [String] $message
		)

		$tz = [Regex]::Replace([System.TimeZoneInfo]::Local.StandardName, '([A-Z])\w+\s*', '$1')
		$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
		if ($message) { Write-Output "$ts $tz -  $message"} else {write-output ""}
	}
