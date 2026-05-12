param(
  [string]$BaseDir = "C:\development\Node.js"
)

$ErrorActionPreference = "Stop"
$RunnerRetentionHours = 24

function Read-MenuNumberOrQuit {
  param(
    [string]$Prompt,
    [int]$Min,
    [int]$Max
  )

  while ($true) {
    $raw = (Read-Host $Prompt).Trim()
    if ($raw.Equals("q", [System.StringComparison]::OrdinalIgnoreCase)) {
      return $null
    }

    if (-not [int]::TryParse($raw, [ref]$null)) {
      Write-Host "Invalid input. Enter a number or Q to quit." -ForegroundColor Yellow
      continue
    }

    $value = [int]$raw
    if ($value -lt $Min -or $value -gt $Max) {
      Write-Host "Out of range. Expected $Min-$Max." -ForegroundColor Yellow
      continue
    }

    return $value
  }
}

function Read-ActionChoice {
  param(
    [string]$Prompt,
    [array]$Actions,
    [hashtable]$Shortcuts
  )

  while ($true) {
    $raw = (Read-Host $Prompt).Trim()
    if ($raw.Equals("q", [System.StringComparison]::OrdinalIgnoreCase)) {
      return "__QUIT__"
    }

    $key = $raw.ToUpperInvariant()
    if ($Shortcuts.ContainsKey($key)) {
      return $Shortcuts[$key]
    }

    if ([int]::TryParse($raw, [ref]$null)) {
      $idx = [int]$raw
      if ($idx -ge 1 -and $idx -le $Actions.Count) {
        return $Actions[$idx - 1].Key
      }
    }

    Write-Host "Invalid action. Use number, shortcut key, or Q to quit." -ForegroundColor Yellow
  }
}

function Get-PidsByListeningPort {
  param([int]$Port)

  $pids = @()
  $regex = "^\s*TCP\s+\S+:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$"

  foreach ($line in (netstat -ano -p tcp)) {
    if ($line -match $regex) {
      $pids += [int]$Matches[1]
    }
  }

  return $pids | Sort-Object -Unique
}

function Test-ProcessBelongsToProject {
  param(
    [int]$ProcessId,
    [string]$ProjectRoot
  )

  $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
  if (-not $proc -or -not $proc.CommandLine) {
    return $false
  }

  $escapedRoot = [regex]::Escape($ProjectRoot)
  return [regex]::IsMatch($proc.CommandLine, $escapedRoot, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Get-BackendPort {
  param([string]$RunDir)

  $port = 3001
  $envPath = Join-Path $RunDir ".env"
  if (Test-Path $envPath) {
    foreach ($line in Get-Content $envPath) {
      if ($line -match "^\s*PORT\s*=\s*(.+)\s*$") {
        $candidate = ($Matches[1] -replace "\s", "")
        if ([int]::TryParse($candidate, [ref]$null)) {
          $port = [int]$candidate
        }
      }
    }
  }

  return $port
}

function Test-ManagedWindowRunning {
  param([string]$TitlePrefix)

  return @(Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
      $_.MainWindowTitle -like "$TitlePrefix*"
    }).Count -gt 0
}

function Stop-ManagedWindows {
  param([string]$TitlePrefix)

  $targets = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -like "$TitlePrefix*"
  }

  foreach ($target in $targets) {
    Stop-Process -Id $target.Id -Force -ErrorAction SilentlyContinue
  }
}

function Remove-OldRunnerFiles {
  param(
    [string]$RunnerRoot,
    [int]$RetentionHours = 24
  )

  if ([string]::IsNullOrWhiteSpace($RunnerRoot) -or -not (Test-Path $RunnerRoot)) {
    return
  }

  $cutoff = (Get-Date).AddHours(-1 * [math]::Abs($RetentionHours))
  $oldRunners = Get-ChildItem -Path $RunnerRoot -Filter "runner-*.ps1" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff }

  foreach ($runner in $oldRunners) {
    Remove-Item -Path $runner.FullName -Force -ErrorAction SilentlyContinue
  }
}

function Start-ManagedPowerShell {
  param(
    [string]$Title,
    [string]$WorkDir,
    [string]$Command
  )

  $safeTitle = $Title.Replace("'", "''")
  $safeDir = $WorkDir.Replace("'", "''")

  $runnerRoot = Join-Path $env:TEMP "server-control-runners"
  if ([string]::IsNullOrWhiteSpace($env:TEMP) -or -not (Test-Path $env:TEMP)) {
    $runnerRoot = Join-Path $WorkDir ".logs"
  }
  if (-not (Test-Path $runnerRoot)) {
    New-Item -ItemType Directory -Path $runnerRoot -Force | Out-Null
  }

  Remove-OldRunnerFiles -RunnerRoot $runnerRoot -RetentionHours $RunnerRetentionHours

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
  $runnerFile = Join-Path $runnerRoot ("runner-{0}-{1}.ps1" -f $safeTitle.Replace(" ", "_"), $stamp)
  $runnerScript = @"
[Console]::Title = '$safeTitle'
`$Host.UI.RawUI.WindowTitle = '$safeTitle'
Set-Location -LiteralPath '$safeDir'
$Command
"@
  Set-Content -Path $runnerFile -Value $runnerScript -Encoding UTF8

  $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
  if ($wt) {
    # Open in an existing Windows Terminal window (id 0) as a new tab.
    Start-Process $wt.Source -ArgumentList "-w", "0", "new-tab", "--title", $Title, "--suppressApplicationTitle", "-d", $WorkDir, "powershell.exe", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $runnerFile | Out-Null
    return
  }

  Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $runnerFile | Out-Null
}

function Get-DetectedVitePort {
  param(
    [string]$ProjectRoot,
    [int]$StartPort,
    [int]$EndPort
  )

  foreach ($port in $StartPort..$EndPort) {
    $portPids = Get-PidsByListeningPort -Port $port
    foreach ($procId in $portPids) {
      if (Test-ProcessBelongsToProject -ProcessId $procId -ProjectRoot $ProjectRoot) {
        return $port
      }
    }
  }

  return $null
}

function Get-VitePortFromLog {
  param([string]$LogFile)

  if (-not (Test-Path $LogFile)) {
    return $null
  }

  $text = Get-Content -Raw -Path $LogFile -ErrorAction SilentlyContinue
  if (-not $text) {
    return $null
  }

  $urlMatches = [regex]::Matches($text, "https?://(?:localhost|127\.0\.0\.1):(\d+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($urlMatches.Count -eq 0) {
    return $null
  }

  return [int]$urlMatches[$urlMatches.Count - 1].Groups[1].Value
}

function Open-AppUrls {
  param(
    [int]$BackendPort,
    [string]$ViteDir,
    [string]$ViteLogFile,
    [string]$ProjectRoot,
    [int]$VitePortStart,
    [int]$VitePortEnd
  )

  $apiUrl = "http://localhost:$BackendPort/api/health"
  Start-Process $apiUrl | Out-Null
  Write-Host "Opened API health: $apiUrl"

  if (-not $ViteDir) {
    return
  }

  $vitePort = Get-VitePortFromLog -LogFile $ViteLogFile
  if (-not $vitePort) {
    $vitePort = Get-DetectedVitePort -ProjectRoot $ProjectRoot -StartPort $VitePortStart -EndPort $VitePortEnd
  }
  if (-not $vitePort) {
    $vitePort = 5173
  }

  $uiUrl = "http://localhost:$vitePort"
  Start-Process $uiUrl | Out-Null
  Write-Host "Opened frontend: $uiUrl"
}

if (-not (Test-Path $BaseDir)) {
  Write-Host "Base directory not found: $BaseDir" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "==============================================="
Write-Host "  Server Control Tool (PowerShell)"
Write-Host "  Base: $BaseDir"
Write-Host "==============================================="
Write-Host ""

$projects = @()
foreach ($dir in Get-ChildItem -Path $BaseDir -Directory) {
  $serverPkg = Join-Path $dir.FullName "server\package.json"
  $rootPkg = Join-Path $dir.FullName "package.json"
  $clientPkg = Join-Path $dir.FullName "client\package.json"

  if (Test-Path $serverPkg) {
    $projects += [PSCustomObject]@{
      Name = $dir.Name
      Root = $dir.FullName
      RunDir = (Join-Path $dir.FullName "server")
      ViteDir = if (Test-Path $clientPkg) { Join-Path $dir.FullName "client" } else { $null }
    }
  } elseif (Test-Path $rootPkg) {
    $projects += [PSCustomObject]@{
      Name = $dir.Name
      Root = $dir.FullName
      RunDir = $dir.FullName
      ViteDir = if (Test-Path $clientPkg) { Join-Path $dir.FullName "client" } else { $null }
    }
  }
}

if ($projects.Count -eq 0) {
  Write-Host "No server-capable projects found in $BaseDir." -ForegroundColor Red
  Write-Host "Expected <project>\server\package.json or <project>\package.json."
  exit 1
}

Write-Host "Available projects:"
for ($i = 0; $i -lt $projects.Count; $i++) {
  Write-Host ("  {0}) {1}" -f ($i + 1), $projects[$i].Name)
}
Write-Host ""

$selectedIdx = Read-MenuNumberOrQuit -Prompt ("Select project number (1-{0}) or Q to quit" -f $projects.Count) -Min 1 -Max $projects.Count
if ($null -eq $selectedIdx) {
  Write-Host "Canceled."
  exit 0
}
$project = $projects[$selectedIdx - 1]

$serverTitle = "$($project.Name)-server"
$viteTitle = "$($project.Name)-client"
$backendPort = Get-BackendPort -RunDir $project.RunDir
$vitePortStart = 5173
$vitePortEnd = 5180
$detectedVitePort = $null
$logRoot = $env:TEMP
if ([string]::IsNullOrWhiteSpace($logRoot) -or -not (Test-Path $logRoot)) {
  $logRoot = Join-Path $project.Root ".logs"
}
if (-not (Test-Path $logRoot)) {
  New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
}

$logPrefix = Join-Path $logRoot ("server-control-{0}" -f $project.Name)
$serverLogFile = "$logPrefix-server.log"
$viteLogFile = "$logPrefix-client.log"

$serverLogFileSafe = $serverLogFile.Replace("'", "''")
$viteLogFileSafe = $viteLogFile.Replace("'", "''")

$serverDevCommand = "npm.cmd run dev 2>&1 | Tee-Object -FilePath '$serverLogFileSafe'"
$viteDevCommand = "npm.cmd run dev 2>&1 | Tee-Object -FilePath '$viteLogFileSafe'"

$serverRunning = (Test-ManagedWindowRunning -TitlePrefix $serverTitle) -or ((Get-PidsByListeningPort -Port $backendPort).Count -gt 0)
$viteRunning = $false
if ($project.ViteDir) {
  $detectedVitePort = Get-VitePortFromLog -LogFile $viteLogFile
  if (-not $detectedVitePort) {
    $detectedVitePort = Get-DetectedVitePort -ProjectRoot $project.Root -StartPort $vitePortStart -EndPort $vitePortEnd
  }
  $viteRunning = (Test-ManagedWindowRunning -TitlePrefix $viteTitle) -or ($null -ne $detectedVitePort)
}

Write-Host ""
Write-Host "Project : $($project.Name)"
Write-Host "Root    : $($project.Root)"
Write-Host "Run dir : $($project.RunDir)"
Write-Host "API port: $backendPort"
if ($project.ViteDir) {
  Write-Host "Vite dir: $($project.ViteDir)"
  if ($detectedVitePort) {
    Write-Host "Vite detected port: $detectedVitePort"
  }
} else {
  Write-Host "Vite dir: N/A"
}
Write-Host ""

if ($serverRunning) {
  Write-Host "Backend state: RUNNING (port $backendPort)" -ForegroundColor Green
} else {
  Write-Host "Backend state: STOPPED" -ForegroundColor Yellow
}

if ($project.ViteDir) {
  if ($viteRunning) {
    $label = if ($detectedVitePort) { "RUNNING (port $detectedVitePort)" } else { "RUNNING" }
    Write-Host "Vite state   : $label" -ForegroundColor Green
  } else {
    Write-Host "Vite state   : STOPPED" -ForegroundColor Yellow
  }
} else {
  Write-Host "Vite state   : NOT AVAILABLE" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "Choose action:"

$actions = @()
if ($project.ViteDir) {
  $actions += [PSCustomObject]@{ Key = "both-sync"; Label = "Start/Restart backend + Vite" }
  $actions += [PSCustomObject]@{ Key = "both-stop"; Label = "Stop backend + Vite" }
}

$actions += [PSCustomObject]@{ Key = "open-urls"; Label = "Open app URLs (API + frontend if available)" }

if ($serverRunning) {
  $actions += [PSCustomObject]@{ Key = "server-stop"; Label = "Stop backend server" }
  $actions += [PSCustomObject]@{ Key = "server-restart"; Label = "Restart backend server" }
} else {
  $actions += [PSCustomObject]@{ Key = "server-start"; Label = "Start backend server (npm run dev)" }
}

if ($project.ViteDir) {
  if ($viteRunning) {
    $actions += [PSCustomObject]@{ Key = "vite-stop"; Label = "Stop Vite frontend" }
    $actions += [PSCustomObject]@{ Key = "vite-restart"; Label = "Restart Vite frontend" }
  } else {
    $actions += [PSCustomObject]@{ Key = "vite-start"; Label = "Start Vite frontend (npm run dev)" }
  }
}

for ($i = 0; $i -lt $actions.Count; $i++) {
  Write-Host ("  {0}) {1}" -f ($i + 1), $actions[$i].Label)
}
Write-Host ""

$shortcuts = @{}
if ($actions.Key -contains "both-sync") { $shortcuts["A"] = "both-sync" }
if ($actions.Key -contains "both-stop") { $shortcuts["X"] = "both-stop" }
if ($actions.Key -contains "server-start") { $shortcuts["S"] = "server-start" }
if ($actions.Key -contains "server-restart") { $shortcuts["S"] = "server-restart" }
if ($actions.Key -contains "vite-start") { $shortcuts["V"] = "vite-start" }
if ($actions.Key -contains "vite-restart") { $shortcuts["V"] = "vite-restart" }
if ($actions.Key -contains "open-urls") { $shortcuts["O"] = "open-urls" }

if ($shortcuts.Count -gt 0) {
  $shortcutPairs = $shortcuts.GetEnumerator() | Sort-Object Name | ForEach-Object { "{0}={1}" -f $_.Name, $_.Value }
  Write-Host ("Shortcuts: {0} | Q=quit" -f ($shortcutPairs -join ", "))
} else {
  Write-Host "Shortcuts: Q=quit"
}
Write-Host ""

$action = Read-ActionChoice -Prompt ("Select action (1-{0}) or shortcut" -f $actions.Count) -Actions $actions -Shortcuts $shortcuts
if ($action -eq "__QUIT__") {
  Write-Host "Canceled."
  exit 0
}

function Stop-Backend {
  param(
    [string]$Title,
    [int]$Port
  )

  Stop-ManagedWindows -TitlePrefix $Title
  foreach ($procId in (Get-PidsByListeningPort -Port $Port)) {
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
  }
  Stop-ManagedWindows -TitlePrefix $Title
}

function Stop-Vite {
  param(
    [string]$Title,
    [string]$ProjectRoot,
    [int]$StartPort,
    [int]$EndPort
  )

  Stop-ManagedWindows -TitlePrefix $Title
  foreach ($port in $StartPort..$EndPort) {
    foreach ($procId in (Get-PidsByListeningPort -Port $port)) {
      if (Test-ProcessBelongsToProject -ProcessId $procId -ProjectRoot $ProjectRoot) {
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
      }
    }
  }
  Stop-ManagedWindows -TitlePrefix $Title
}

switch ($action) {
  "server-start" {
    Write-Host "Starting backend in new PowerShell terminal: $serverTitle"
    Start-ManagedPowerShell -Title $serverTitle -WorkDir $project.RunDir -Command $serverDevCommand
  }
  "server-stop" {
    Write-Host "Stopping backend: $serverTitle"
    Stop-Backend -Title $serverTitle -Port $backendPort
  }
  "server-restart" {
    Write-Host "Restarting backend: $serverTitle"
    Stop-Backend -Title $serverTitle -Port $backendPort
    Start-ManagedPowerShell -Title $serverTitle -WorkDir $project.RunDir -Command $serverDevCommand
  }
  "vite-start" {
    if (-not $project.ViteDir) {
      Write-Host "Vite is not available for this project." -ForegroundColor Red
      exit 1
    }
    Write-Host "Starting Vite in new PowerShell terminal: $viteTitle"
    Start-ManagedPowerShell -Title $viteTitle -WorkDir $project.ViteDir -Command $viteDevCommand
  }
  "vite-stop" {
    if (-not $project.ViteDir) {
      Write-Host "Vite is not available for this project." -ForegroundColor Red
      exit 1
    }
    Write-Host "Stopping Vite: $viteTitle"
    Stop-Vite -Title $viteTitle -ProjectRoot $project.Root -StartPort $vitePortStart -EndPort $vitePortEnd
  }
  "vite-restart" {
    if (-not $project.ViteDir) {
      Write-Host "Vite is not available for this project." -ForegroundColor Red
      exit 1
    }
    Write-Host "Restarting Vite: $viteTitle"
    Stop-Vite -Title $viteTitle -ProjectRoot $project.Root -StartPort $vitePortStart -EndPort $vitePortEnd
    Start-ManagedPowerShell -Title $viteTitle -WorkDir $project.ViteDir -Command $viteDevCommand
  }
  "both-sync" {
    if (-not $project.ViteDir) {
      Write-Host "Vite is not available for this project." -ForegroundColor Red
      exit 1
    }

    Write-Host "Syncing backend + Vite..."
    if ($serverRunning) {
      Stop-Backend -Title $serverTitle -Port $backendPort
    }
    if ($viteRunning) {
      Stop-Vite -Title $viteTitle -ProjectRoot $project.Root -StartPort $vitePortStart -EndPort $vitePortEnd
    }

    Start-ManagedPowerShell -Title $serverTitle -WorkDir $project.RunDir -Command $serverDevCommand
    Start-ManagedPowerShell -Title $viteTitle -WorkDir $project.ViteDir -Command $viteDevCommand
  }
  "both-stop" {
    if (-not $project.ViteDir) {
      Write-Host "Vite is not available for this project." -ForegroundColor Red
      exit 1
    }

    Write-Host "Stopping backend + Vite..."
    Stop-Backend -Title $serverTitle -Port $backendPort
    Stop-Vite -Title $viteTitle -ProjectRoot $project.Root -StartPort $vitePortStart -EndPort $vitePortEnd
  }
  "open-urls" {
    Open-AppUrls -BackendPort $backendPort -ViteDir $project.ViteDir -ViteLogFile $viteLogFile -ProjectRoot $project.Root -VitePortStart $vitePortStart -VitePortEnd $vitePortEnd
  }
  default {
    Write-Host "Unknown action." -ForegroundColor Red
    exit 1
  }
}

Write-Host "Done." -ForegroundColor Green
