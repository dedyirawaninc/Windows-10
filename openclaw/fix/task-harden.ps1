param(
  [string]$TaskName = "OpenClaw Node",

  # Set to $true to remove runtime limit entirely (PT0S)
  [bool]$RemoveExecutionTimeLimit = $false
)

$ErrorActionPreference = "Stop"
$tmpXml = Join-Path $env:TEMP "OpenClawNode.hardened.xml"

Write-Host "Exporting task XML..."
schtasks /Query /TN $TaskName /XML > $tmpXml
if (!(Test-Path $tmpXml)) { throw "Failed to export task XML." }

[xml]$xml = Get-Content $tmpXml
$nsUri = $xml.DocumentElement.NamespaceURI
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace("t", $nsUri)

function Get-OrCreateNode([string]$xpath, [string]$parentXpath, [string]$name) {
  $node = $xml.SelectSingleNode($xpath, $ns)
  if (-not $node) {
    $parent = $xml.SelectSingleNode($parentXpath, $ns)
    if (-not $parent) { throw "Parent not found: $parentXpath" }
    $node = $xml.CreateElement($name, $nsUri)
    [void]$parent.AppendChild($node)
  }
  return $node
}

function Set-NodeText([string]$xpath, [string]$parentXpath, [string]$name, [string]$value) {
  $n = Get-OrCreateNode $xpath $parentXpath $name
  $n.InnerText = $value
}

# Ensure Settings exists
$null = Get-OrCreateNode "/t:Task/t:Settings" "/t:Task" "Settings"

# Restart on failure: 1 minute, 3 attempts
$null = Get-OrCreateNode "/t:Task/t:Settings/t:RestartOnFailure" "/t:Task/t:Settings" "RestartOnFailure"
Set-NodeText "/t:Task/t:Settings/t:RestartOnFailure/t:Interval" "/t:Task/t:Settings/t:RestartOnFailure" "Interval" "PT1M"
Set-NodeText "/t:Task/t:Settings/t:RestartOnFailure/t:Count"    "/t:Task/t:Settings/t:RestartOnFailure" "Count"    "3"

# ExecutionTimeLimit: either PT12H or PT0S (unlimited)
if ($RemoveExecutionTimeLimit) {
  Set-NodeText "/t:Task/t:Settings/t:ExecutionTimeLimit" "/t:Task/t:Settings" "ExecutionTimeLimit" "PT0S"
} else {
  Set-NodeText "/t:Task/t:Settings/t:ExecutionTimeLimit" "/t:Task/t:Settings" "ExecutionTimeLimit" "PT12H"
}

$xml.Save($tmpXml)

Write-Host "Re-registering task..."
schtasks /Create /TN $TaskName /XML $tmpXml /F

Write-Host "Starting task..."
schtasks /Run /TN $TaskName
Start-Sleep -Seconds 2

Write-Host "Verifying..."
schtasks /Query /TN $TaskName /FO LIST /V
Write-Host "Done."
