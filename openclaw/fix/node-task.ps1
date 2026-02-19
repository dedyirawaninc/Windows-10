param(
  [string]$TaskName = "OpenClaw Node"
)

$ErrorActionPreference = "Stop"
$tmpXml = Join-Path $env:TEMP "OpenClawNode.xml"

Write-Host "Exporting task XML..."
schtasks /Query /TN $TaskName /XML > $tmpXml
if (!(Test-Path $tmpXml)) { throw "Failed to export task XML." }

[xml]$xml = Get-Content $tmpXml

# Task Scheduler default namespace (critical)
$nsUri = $xml.DocumentElement.NamespaceURI
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace("t", $nsUri)

function Get-OrCreate {
  param(
    [string]$XPath,
    [string]$ParentXPath,
    [string]$Name
  )
  $node = $xml.SelectSingleNode($XPath, $ns)
  if (-not $node) {
    $parent = $xml.SelectSingleNode($ParentXPath, $ns)
    if (-not $parent) { throw "Parent not found: $ParentXPath" }
    $node = $xml.CreateElement($Name, $nsUri)
    [void]$parent.AppendChild($node)
  }
  return $node
}

function Set-NodeText {
  param(
    [string]$XPath,
    [string]$ParentXPath,
    [string]$Name,
    [string]$Value
  )
  $n = Get-OrCreate -XPath $XPath -ParentXPath $ParentXPath -Name $Name
  $n.InnerText = $Value
}

# Ensure Principals/Principal
$principals = Get-OrCreate -XPath "/t:Task/t:Principals" -ParentXPath "/t:Task" -Name "Principals"
$principal = $xml.SelectSingleNode("/t:Task/t:Principals/t:Principal", $ns)
if (-not $principal) {
  $principal = $xml.CreateElement("Principal", $nsUri)
  $idAttr = $xml.CreateAttribute("id")
  $idAttr.Value = "Author"
  [void]$principal.Attributes.Append($idAttr)
  [void]$principals.AppendChild($principal)
}

Set-NodeText "/t:Task/t:Principals/t:Principal/t:UserId"    "/t:Task/t:Principals/t:Principal" "UserId"    "$env:USERDOMAIN\$env:USERNAME"
Set-NodeText "/t:Task/t:Principals/t:Principal/t:LogonType" "/t:Task/t:Principals/t:Principal" "LogonType" "S4U"
Set-NodeText "/t:Task/t:Principals/t:Principal/t:RunLevel"  "/t:Task/t:Principals/t:Principal" "RunLevel"  "HighestAvailable"

# Settings
Set-NodeText "/t:Task/t:Settings/t:DisallowStartIfOnBatteries" "/t:Task/t:Settings" "DisallowStartIfOnBatteries" "false"
Set-NodeText "/t:Task/t:Settings/t:StopIfGoingOnBatteries"     "/t:Task/t:Settings" "StopIfGoingOnBatteries"     "false"
Set-NodeText "/t:Task/t:Settings/t:StartWhenAvailable"         "/t:Task/t:Settings" "StartWhenAvailable"         "true"
Set-NodeText "/t:Task/t:Settings/t:MultipleInstancesPolicy"    "/t:Task/t:Settings" "MultipleInstancesPolicy"    "IgnoreNew"

# Triggers
$triggers = Get-OrCreate -XPath "/t:Task/t:Triggers" -ParentXPath "/t:Task" -Name "Triggers"

if (-not $xml.SelectSingleNode("/t:Task/t:Triggers/t:LogonTrigger", $ns)) {
  $logon = $xml.CreateElement("LogonTrigger", $nsUri)
  $en = $xml.CreateElement("Enabled", $nsUri); $en.InnerText = "true"
  [void]$logon.AppendChild($en)
  [void]$triggers.AppendChild($logon)
}
if (-not $xml.SelectSingleNode("/t:Task/t:Triggers/t:BootTrigger", $ns)) {
  $boot = $xml.CreateElement("BootTrigger", $nsUri)
  $en = $xml.CreateElement("Enabled", $nsUri); $en.InnerText = "true"
  [void]$boot.AppendChild($en)
  [void]$triggers.AppendChild($boot)
}

$xml.Save($tmpXml)

Write-Host "Re-registering task..."
schtasks /Create /TN $TaskName /XML $tmpXml /F

Write-Host "Starting task..."
schtasks /Run /TN $TaskName
Start-Sleep -Seconds 2

Write-Host "Verifying..."
schtasks /Query /TN $TaskName /FO LIST /V
