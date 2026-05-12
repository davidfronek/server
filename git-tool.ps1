param(
  [string]$BaseDir = "C:\development\Node.js"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers – stejny styl jako server-control.ps1
# ---------------------------------------------------------------------------
function Read-MenuNumberOrQuit {
  param([string]$Prompt, [int]$Min, [int]$Max)
  while ($true) {
    $raw = (Read-Host $Prompt).Trim()
    if ($raw.Equals("q", [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
    if ([int]::TryParse($raw, [ref]$null)) {
      $value = [int]$raw
      if ($value -ge $Min -and $value -le $Max) { return $value }
    }
    Write-Host "  Neplatna volba. Zadejte cislo $Min-$Max nebo Q." -ForegroundColor Yellow
  }
}

function Read-ActionChoice {
  param([string]$Prompt, [array]$Actions, [hashtable]$Shortcuts)
  while ($true) {
    $raw = (Read-Host $Prompt).Trim()
    if ($raw.Equals("q", [System.StringComparison]::OrdinalIgnoreCase)) { return "__QUIT__" }
    $key = $raw.ToUpperInvariant()
    if ($Shortcuts.ContainsKey($key)) { return $Shortcuts[$key] }
    if ([int]::TryParse($raw, [ref]$null)) {
      $idx = [int]$raw
      if ($idx -ge 1 -and $idx -le $Actions.Count) { return $Actions[$idx - 1].Key }
    }
    Write-Host "  Neplatna volba. Pouzijte cislo, zkratku nebo Q." -ForegroundColor Yellow
  }
}

function Invoke-Git {
  param([string]$WorkDir, [string[]]$Arguments)
  Push-Location $WorkDir
  try {
    & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git skoncil s kodem $LASTEXITCODE" }
  }
  finally { Pop-Location }
}

function Get-CurrentBranch {
  param([string]$WorkDir)
  Push-Location $WorkDir
  try { return (& git rev-parse --abbrev-ref HEAD 2>$null) }
  finally { Pop-Location }
}

function Get-GitStatus {
  param([string]$WorkDir)
  Push-Location $WorkDir
  try { return (& git status --porcelain) }
  finally { Pop-Location }
}

# ---------------------------------------------------------------------------
# Zjisteni projektu
# ---------------------------------------------------------------------------
if (-not (Test-Path $BaseDir)) {
  Write-Host "Adresar nenalezen: $BaseDir" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Git Tool" -ForegroundColor Cyan
Write-Host "  Workspace: $BaseDir" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$rootGit = Test-Path (Join-Path $BaseDir ".git")
$projects = @()

if ($rootGit) {
  $projects += [PSCustomObject]@{ Name = "(workspace root)"; Path = $BaseDir }
  foreach ($d in Get-ChildItem -Path $BaseDir -Directory | Where-Object { $_.Name -notmatch '^\.' }) {
    $projects += [PSCustomObject]@{ Name = $d.Name; Path = $d.FullName }
  }
} else {
  foreach ($d in Get-ChildItem -Path $BaseDir -Directory) {
    if (Test-Path (Join-Path $d.FullName ".git")) {
      $projects += [PSCustomObject]@{ Name = $d.Name; Path = $d.FullName }
    }
  }
}

if ($projects.Count -eq 0) {
  Write-Host "V adresari '$BaseDir' nebyl nalezen zadny git repozitar." -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------------------
# Vyber projektu
# ---------------------------------------------------------------------------
Write-Host "Dostupne projekty:"
Write-Host ""
for ($i = 0; $i -lt $projects.Count; $i++) {
  $branch = Get-CurrentBranch $projects[$i].Path
  $st = Get-GitStatus $projects[$i].Path
  $dirty = if (($st | Measure-Object).Count -gt 0) { " [*]" } else { "" }
  Write-Host ("  {0}) {1}  [{2}]{3}" -f ($i + 1), $projects[$i].Name, $branch, $dirty)
}
Write-Host ""

$selectedIdx = Read-MenuNumberOrQuit -Prompt ("Zvolte projekt (1-{0}) nebo Q" -f $projects.Count) -Min 1 -Max $projects.Count
if ($null -eq $selectedIdx) { Write-Host "Zruseno."; exit 0 }

$project = $projects[$selectedIdx - 1]
$gitDir  = if ($rootGit) { $BaseDir } else { $project.Path }

# ---------------------------------------------------------------------------
# Info o projektu
# ---------------------------------------------------------------------------
$branch     = Get-CurrentBranch $gitDir
$status     = Get-GitStatus $gitDir
$dirtyCount = ($status | Measure-Object).Count
$dirtyLabel = if ($dirtyCount -gt 0) { "$dirtyCount zmen" } else { "zadne zmeny" }

$remoteUrl = ""
try {
  Push-Location $gitDir
  $remoteUrl = (& git remote get-url origin 2>$null)
  Pop-Location
} catch { if ($PWD.Path -ne $gitDir) { Pop-Location } }

Write-Host ""
Write-Host "Projekt : $($project.Name)"
Write-Host "Cesta   : $($project.Path)"
Write-Host "Vetev   : $branch"
Write-Host "Remote  : $(if ($remoteUrl) { $remoteUrl } else { 'N/A' })"
Write-Host "Stav    : $dirtyLabel" -ForegroundColor $(if ($dirtyCount -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

# ---------------------------------------------------------------------------
# Menu akci
# ---------------------------------------------------------------------------
$actions = @()
if ($dirtyCount -gt 0) {
  $actions += [PSCustomObject]@{ Key = "commit";      Label = "Commit" }
  $actions += [PSCustomObject]@{ Key = "commit-push"; Label = "Commit + Push" }
}
$actions += [PSCustomObject]@{ Key = "push";     Label = "Push" }
$actions += [PSCustomObject]@{ Key = "pull";     Label = "Pull" }
$actions += [PSCustomObject]@{ Key = "status";   Label = "Status" }
$actions += [PSCustomObject]@{ Key = "log";      Label = "Log (poslednich 15 commitu)" }
$actions += [PSCustomObject]@{ Key = "diff";     Label = "Diff (zmeny vs HEAD)" }
$actions += [PSCustomObject]@{ Key = "branches"; Label = "Sprava vetvi" }
$actions += [PSCustomObject]@{ Key = "stash";    Label = "Stash" }

Write-Host "Akce:"
Write-Host ""
for ($i = 0; $i -lt $actions.Count; $i++) {
  Write-Host ("  {0}) {1}" -f ($i + 1), $actions[$i].Label)
}
Write-Host ""

$shortcuts = @{}
if (($actions | Where-Object Key -eq "commit").Count)      { $shortcuts["C"] = "commit" }
if (($actions | Where-Object Key -eq "commit-push").Count) { $shortcuts["A"] = "commit-push" }
$shortcuts["P"] = "push"
$shortcuts["L"] = "pull"
$shortcuts["S"] = "status"
$shortcuts["G"] = "log"
$shortcuts["D"] = "diff"
$shortcuts["B"] = "branches"
$shortcuts["T"] = "stash"

$shortcutPairs = $shortcuts.GetEnumerator() | Sort-Object Name | ForEach-Object { "{0}={1}" -f $_.Name, $_.Value }
Write-Host ("Zkratky: {0} | Q=konec" -f ($shortcutPairs -join ", "))
Write-Host ""

$action = Read-ActionChoice -Prompt ("Zvolte akci (1-{0}) nebo zkratku" -f $actions.Count) -Actions $actions -Shortcuts $shortcuts
if ($action -eq "__QUIT__") { Write-Host "Zruseno."; exit 0 }

# ---------------------------------------------------------------------------
# Pomocna funkce pro commit
# ---------------------------------------------------------------------------
function Do-Commit {
  param([string]$WorkDir)
  $st = Get-GitStatus $WorkDir
  if (($st | Measure-Object).Count -eq 0) {
    Write-Host "Zadne zmeny ke commitu." -ForegroundColor Yellow
    return $false
  }
  Write-Host ""
  Write-Host "Zmeny:" -ForegroundColor Cyan
  $st | ForEach-Object { Write-Host "  $_" }
  Write-Host ""
  $addMode = (Read-Host "  Pridat vsechny zmeny? (A=vsechny / R=rucni vyber)").Trim().ToUpperInvariant()
  if ($addMode -eq "R") {
    Push-Location $WorkDir
    try {
      & git status --short
      Write-Host ""
      $files = (Read-Host "  Soubory oddelene mezerou (nebo . pro vsechny)").Trim()
      if ($files -eq ".") { & git add -A }
      else { $files -split '\s+' | Where-Object { $_ } | ForEach-Object { & git add $_ } }
    }
    finally { Pop-Location }
  } else {
    Invoke-Git $WorkDir "add", "-A"
  }
  Write-Host ""
  $msg = (Read-Host "  Commit zprava").Trim()
  if ([string]::IsNullOrWhiteSpace($msg)) {
    Write-Host "Commit zprava nesmi byt prazdna." -ForegroundColor Red
    return $false
  }
  Invoke-Git $WorkDir "commit", "-m", $msg
  Write-Host "Commit dokoncen." -ForegroundColor Green
  return $true
}

# ---------------------------------------------------------------------------
# Provedeni akce
# ---------------------------------------------------------------------------
try {
  switch ($action) {

    "status" {
      Write-Host ""
      Invoke-Git $gitDir "status"
    }

    "log" {
      Write-Host ""
      Invoke-Git $gitDir "log", "--oneline", "--graph", "--decorate", "-n", "15"
    }

    "diff" {
      Write-Host ""
      Invoke-Git $gitDir "diff", "HEAD"
    }

    "commit" {
      Write-Host ""
      Do-Commit -WorkDir $gitDir | Out-Null
    }

    "push" {
      Write-Host ""
      Write-Host "Pushuju vetev '$branch' -> origin..." -ForegroundColor Cyan
      Invoke-Git $gitDir "push", "origin", $branch
      Write-Host "Push dokoncen." -ForegroundColor Green
    }

    "pull" {
      Write-Host ""
      Write-Host "Pulluju vetev '$branch' z origin..." -ForegroundColor Cyan
      Invoke-Git $gitDir "pull", "origin", $branch
      Write-Host "Pull dokoncen." -ForegroundColor Green
    }

    "commit-push" {
      Write-Host ""
      $ok = Do-Commit -WorkDir $gitDir
      if ($ok) {
        Write-Host ""
        Write-Host "Pushuju vetev '$branch' -> origin..." -ForegroundColor Cyan
        Invoke-Git $gitDir "push", "origin", $branch
        Write-Host "Push dokoncen." -ForegroundColor Green
      }
    }

    "stash" {
      Write-Host ""
      Write-Host "Stash:"
      Write-Host "  1) Ulozit zmeny (stash push)"
      Write-Host "  2) Obnovit posledni (stash pop)"
      Write-Host "  3) Zobrazit seznam (stash list)"
      Write-Host ""
      $sub = Read-MenuNumberOrQuit -Prompt "Volba (1-3) nebo Q" -Min 1 -Max 3
      if ($null -ne $sub) {
        switch ($sub) {
          1 {
            $m = (Read-Host "  Popis (Enter = vychozi)").Trim()
            if ($m) { Invoke-Git $gitDir "stash", "push", "-m", $m }
            else    { Invoke-Git $gitDir "stash", "push" }
            Write-Host "Stash ulozen." -ForegroundColor Green
          }
          2 { Invoke-Git $gitDir "stash", "pop";  Write-Host "Stash obnoven." -ForegroundColor Green }
          3 { Invoke-Git $gitDir "stash", "list" }
        }
      }
    }

    "branches" {
      Write-Host ""
      Write-Host "Sprava vetvi:"
      Write-Host "  1) Zobrazit vsechny vetve"
      Write-Host "  2) Prepnout vetev"
      Write-Host "  3) Vytvorit novou vetev"
      Write-Host "  4) Smazat vetev"
      Write-Host ""
      $sub = Read-MenuNumberOrQuit -Prompt "Volba (1-4) nebo Q" -Min 1 -Max 4
      if ($null -ne $sub) {
        switch ($sub) {
          1 { Invoke-Git $gitDir "branch", "-a" }
          2 {
            Invoke-Git $gitDir "branch", "-a"
            Write-Host ""
            $b = (Read-Host "  Nazev vetve").Trim()
            Invoke-Git $gitDir "checkout", $b
            Write-Host "Prepnuto na '$b'." -ForegroundColor Green
          }
          3 {
            $b = (Read-Host "  Nazev nove vetve").Trim()
            Invoke-Git $gitDir "checkout", "-b", $b
            Write-Host "Vetev '$b' vytvorena." -ForegroundColor Green
          }
          4 {
            Invoke-Git $gitDir "branch", "-a"
            Write-Host ""
            $b = (Read-Host "  Nazev vetve ke smazani").Trim()
            $confirm = (Read-Host "  Opravdu smazat '$b'? (a/N)").Trim().ToUpperInvariant()
            if ($confirm -eq "A") {
              Invoke-Git $gitDir "branch", "-d", $b
              Write-Host "Vetev '$b' smazana." -ForegroundColor Green
            } else {
              Write-Host "Zruseno." -ForegroundColor Yellow
            }
          }
        }
      }
    }
  }
}
catch {
  Write-Host ""
  Write-Host "Chyba: $_" -ForegroundColor Red
  exit 1
}

Write-Host ""
