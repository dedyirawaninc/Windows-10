$ErrorActionPreference = 'Stop'

$VBoxManage = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$SampleSeconds = 2

Write-Host '=========================================='
Write-Host 'VirtualBox VM CPU Usage Monitor'
Write-Host '=========================================='

if (-not (Test-Path -LiteralPath $VBoxManage)) {
    Write-Host "ERROR: VBoxManage.exe was not found at:"
    Write-Host $VBoxManage
    exit 1
}

try {
    $runningVmLines = & $VBoxManage list runningvms 2>&1
}
catch {
    Write-Host 'ERROR: VBoxManage could not connect to VirtualBox.'
    Write-Host 'Try opening VirtualBox once, then run this script again.'
    exit 1
}

if ($LASTEXITCODE -ne 0) {
    Write-Host 'ERROR: VBoxManage could not list running VMs.'
    $runningVmLines | ForEach-Object { Write-Host $_ }
    exit $LASTEXITCODE
}

$vms = foreach ($line in $runningVmLines) {
    if ($line -match '^"(?<name>.*)"\s+\{(?<id>[^}]+)\}\s*$') {
        [pscustomobject]@{
            Name = $Matches.name
            Id = $Matches.id
        }
    }
}

if (-not $vms) {
    Write-Host 'No running VirtualBox VMs found.'
    exit 0
}

function Get-CommandLineOption {
    param(
        [Parameter(Mandatory)]
        [string]$CommandLine,

        [Parameter(Mandatory)]
        [string]$OptionName
    )

    $pattern = '(?i)(?:^|\s)' + [regex]::Escape($OptionName) + '(?:=|\s+)(?:"(?<quoted>[^"]*)"|(?<plain>\S+))'
    $match = [regex]::Match($CommandLine, $pattern)
    if (-not $match.Success) {
        return $null
    }

    if ($match.Groups['quoted'].Success) {
        return $match.Groups['quoted'].Value
    }

    return $match.Groups['plain'].Value
}

function Normalize-VmId {
    param([string]$VmId)

    if ([string]::IsNullOrWhiteSpace($VmId)) {
        return $null
    }

    return $VmId.Trim().Trim('{', '}').ToLowerInvariant()
}

$vmProcesses = @()
try {
    $vmProcesses = Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            $_.Name -in @('VBoxHeadless.exe', 'VirtualBoxVM.exe')
        }
}
catch {
    try {
        $vmProcesses = Get-WmiObject Win32_Process -ErrorAction Stop |
            Where-Object {
                $_.Name -in @('VBoxHeadless.exe', 'VirtualBoxVM.exe')
            }
    }
    catch {
        Write-Host 'WARNING: Could not read process command lines; VM-to-process matching may be limited.'
    }
}

$vmProcessMap = @(foreach ($vmProcess in ($vmProcesses | Where-Object { $_.CommandLine })) {
    $startVm = Get-CommandLineOption -CommandLine $vmProcess.CommandLine -OptionName '--startvm'
    $comment = Get-CommandLineOption -CommandLine $vmProcess.CommandLine -OptionName '--comment'

    [pscustomobject]@{
        ProcessId = [int]$vmProcess.ProcessId
        ProcessName = $vmProcess.Name
        StartVm = $startVm
        StartVmId = Normalize-VmId $startVm
        Comment = $comment
        CommandLine = $vmProcess.CommandLine
    }
})

function Get-VmProcessTreeIds {
    param(
        [Parameter(Mandatory)]
        [int]$RootProcessId,

        [Parameter(Mandatory)]
        [object[]]$ProcessInfos
    )

    $ids = New-Object 'System.Collections.Generic.HashSet[int]'
    [void]$ids.Add($RootProcessId)

    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($processInfo in $ProcessInfos) {
            if ($ids.Contains([int]$processInfo.ParentProcessId) -and -not $ids.Contains([int]$processInfo.ProcessId)) {
                [void]$ids.Add([int]$processInfo.ProcessId)
                $changed = $true
            }
        }
    }

    return @($ids)
}

function Get-ProcessorTimes {
    param([int[]]$ProcessIds)

    $user = 0.0
    $kernel = 0.0
    $aliveProcessIds = @()

    foreach ($processId in $ProcessIds) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (-not $process) {
            continue
        }

        $aliveProcessIds += $processId
        $user += $process.UserProcessorTime.TotalSeconds
        $kernel += $process.PrivilegedProcessorTime.TotalSeconds
    }

    [pscustomobject]@{
        ProcessIds = $aliveProcessIds
        User = $user
        Kernel = $kernel
    }
}

$targets = @(foreach ($vm in $vms) {
    $info = & $VBoxManage showvminfo $vm.Id --machinereadable 2>$null
    $vmProcessId = $null
    $matchSource = 'showvminfo'

    foreach ($line in $info) {
        if ($line -match '^(VMProcessID|SessionPID)="?(?<vmProcessId>\d+)"?$') {
            $vmProcessId = [int]$Matches.vmProcessId
            break
        }
    }

    if (-not $vmProcessId) {
        $normalizedVmId = Normalize-VmId $vm.Id
        $escapedVmName = [regex]::Escape($vm.Name)
        $matchedProcess = $vmProcessMap |
            Where-Object {
                $_.StartVmId -eq $normalizedVmId -or
                $_.StartVm -eq $vm.Name -or
                $_.Comment -eq $vm.Name -or
                $_.CommandLine -match $escapedVmName
            } |
            Select-Object -First 1

        if ($matchedProcess) {
            $vmProcessId = [int]$matchedProcess.ProcessId
            if ($matchedProcess.StartVmId -eq $normalizedVmId) {
                $matchSource = 'matched --startvm'
            }
            elseif ($matchedProcess.StartVm -eq $vm.Name) {
                $matchSource = 'matched --startvm name'
            }
            elseif ($matchedProcess.Comment -eq $vm.Name) {
                $matchSource = 'matched --comment'
            }
            else {
                $matchSource = 'matched command line'
            }
        }
    }

    if (-not $vmProcessId) {
        [pscustomobject]@{
            Name = $vm.Name
            Pid = $null
            ProcessIds = @()
            UserStart = $null
            KernelStart = $null
            Status = 'No process match'
        }
        continue
    }

    $processIds = Get-VmProcessTreeIds -RootProcessId $vmProcessId -ProcessInfos $vmProcesses
    $startTimes = Get-ProcessorTimes -ProcessIds $processIds
    if (-not $startTimes.ProcessIds) {
        [pscustomobject]@{
            Name = $vm.Name
            Pid = $vmProcessId
            ProcessIds = $processIds
            UserStart = $null
            KernelStart = $null
            Status = 'Process not found'
        }
        continue
    }

    [pscustomobject]@{
        Name = $vm.Name
        Pid = $vmProcessId
        ProcessIds = $startTimes.ProcessIds
        UserStart = $startTimes.User
        KernelStart = $startTimes.Kernel
        Status = "$matchSource ($($startTimes.ProcessIds.Count) procs)"
    }
})

$knownProcessIds = @($targets | Where-Object { $_.ProcessIds } | ForEach-Object { $_.ProcessIds })
$unmatchedProcesses = Get-Process -Name VBoxHeadless,VirtualBoxVM -ErrorAction SilentlyContinue |
    Where-Object { $knownProcessIds -notcontains $_.Id }

$unmatchedTargets = @(foreach ($process in $unmatchedProcesses) {
    [pscustomobject]@{
        Name = $process.ProcessName
        Pid = $process.Id
        ProcessIds = @($process.Id)
        UserStart = $process.UserProcessorTime.TotalSeconds
        KernelStart = $process.PrivilegedProcessorTime.TotalSeconds
        Status = 'Unmatched VM process'
    }
})

if ($unmatchedTargets) {
    if (-not ($targets | Where-Object { $null -ne $_.UserStart -and $null -ne $_.KernelStart })) {
        $targets = $unmatchedTargets
    }
    else {
        $targets += $unmatchedTargets
    }
}

$startedAt = Get-Date
Start-Sleep -Seconds $SampleSeconds
$elapsed = ((Get-Date) - $startedAt).TotalSeconds
$logicalCpuCount = [Environment]::ProcessorCount

Write-Host ('{0,-44} {1,8} {2,8} {3,8} {4,8}  {5}' -f 'VM', 'PID', 'User%', 'Kernel%', 'Total%', 'Status')
Write-Host ('{0,-44} {1,8} {2,8} {3,8} {4,8}  {5}' -f ('-' * 44), ('-' * 8), ('-' * 8), ('-' * 8), ('-' * 8), ('-' * 6))

foreach ($target in $targets) {
    if ($null -eq $target.UserStart -or $null -eq $target.KernelStart) {
        Write-Host ('{0,-44} {1,8} {2,8} {3,8} {4,8}  {5}' -f $target.Name, $target.Pid, '', '', '', $target.Status)
        continue
    }

    $endTimes = Get-ProcessorTimes -ProcessIds $target.ProcessIds
    if (-not $endTimes.ProcessIds) {
        Write-Host ('{0,-44} {1,8} {2,8} {3,8} {4,8}  {5}' -f $target.Name, $target.Pid, '', '', '', 'Process ended')
        continue
    }

    $userPercent = (($endTimes.User - $target.UserStart) / $elapsed) / $logicalCpuCount * 100
    $kernelPercent = (($endTimes.Kernel - $target.KernelStart) / $elapsed) / $logicalCpuCount * 100
    $totalPercent = $userPercent + $kernelPercent

    Write-Host ('{0,-44} {1,8} {2,8:F2} {3,8:F2} {4,8:F2}  {5}' -f $target.Name, $target.Pid, $userPercent, $kernelPercent, $totalPercent, $target.Status)
}
