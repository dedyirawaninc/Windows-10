# 1) Is OpenClaw node process actually alive?
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -match "openclaw.*node run" } | Select-Object ProcessId, CommandLine
# 2) Can this machine reach your gateway host/port?
Test-NetConnection 192.168.100.107 -Port 8789
# 3) Run node in foreground with debug logs (watch for register/pair/connect errors)
$env:DEBUG="openclaw:*"; & "C:\Program Files\nodejs\node.exe" "C:\Users\Dedy\AppData\Roaming\npm\node_modules\openclaw\dist\index.js" node run --host 192.168.100.107 --port 8789 --display-name WD11PRO64
