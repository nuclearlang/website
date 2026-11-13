# NuclearLang installer for Windows (PowerShell 5.1 or 7):
#
#   irm https://nuclearlang.github.io/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://nuclearlang.github.io/install.ps1))) -Version 0.2.0
#   & ([scriptblock]::Create((irm https://nuclearlang.github.io/install.ps1))) -Uninstall
#
# It downloads the release of this architecture (x86_64 or arm64) from
# GitHub, checks its SHA-256, installs it in %LOCALAPPDATA%\nuclearlang, puts its bin folder in your user PATH, gives the
# AI agents the `nuclear` skill and, when VS Code is there, installs its extension. No administrator rights. Then the
# set-up of the AI services (`nuclear-loop setup`: it reads this machine, suggests a profile and asks before anything
# is downloaded; a machine already set up is brought up to date without questions). -NoAi skips it; -AiProfile
# remote|lite|medium|hard takes that profile without questions.
#
# Environment: NUCLEAR_VERSION, NUCLEAR_INSTALL (the folder), NUCLEAR_REPO (owner/name), NUCLEAR_DOWNLOAD (a mirror),
# NUCLEAR_AI_PROFILE.
param(
  [string]$Version = $(if ($env:NUCLEAR_VERSION) { $env:NUCLEAR_VERSION } else { 'latest' }),
  [switch]$NoModifyPath,
  [switch]$NoVSCode,
  [switch]$NoAgent,
  [switch]$NoAi,
  [string]$AiProfile = $env:NUCLEAR_AI_PROFILE,
  [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = if ($env:NUCLEAR_REPO) { $env:NUCLEAR_REPO } else { 'nuclearlang/nuclear' }
$Install = if ($env:NUCLEAR_INSTALL) { $env:NUCLEAR_INSTALL } else { Join-Path $env:LOCALAPPDATA 'nuclearlang' }
$Bin = Join-Path $Install 'bin'
$SkillDirs = @('.claude\skills', '.agents\skills', '.codex\skills') | ForEach-Object { Join-Path $HOME $_ }

function Set-UserPath([string[]]$Parts) {
  [Environment]::SetEnvironmentVariable('Path', ($Parts | Where-Object { $_ }) -join ';', 'User')
}
$UserPath = @(([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') | Where-Object { $_ })

$Loop = Join-Path $Bin 'nuclear-loop.cmd'
$env:NUCLEAR_INSTALL = $Install

if ($Uninstall) {
  # the AI services first (what starts them at login, the graph's tool): their set-up takes them away
  if ((Test-Path $Loop) -and (Get-Command node -ErrorAction SilentlyContinue)) { & $Loop setup --remove *> $null }
  Remove-Item -Recurse -Force $Install -ErrorAction SilentlyContinue
  foreach ($d in $SkillDirs) { Remove-Item -Recurse -Force (Join-Path $d 'nuclear') -ErrorAction SilentlyContinue }
  Set-UserPath ($UserPath | Where-Object { $_ -ne $Bin })
  if (Get-Command code -ErrorAction SilentlyContinue) { code --uninstall-extension nuclearlang.nuclearlang *> $null }
  Write-Host 'NuclearLang uninstalled.'
  return
}

# --- this system ---
$Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
  'AMD64' { 'x86_64' }
  'ARM64' { 'aarch64' }
  default { throw "unsupported architecture: $env:PROCESSOR_ARCHITECTURE (x86_64 and arm64 are)" }
}

# --- which release ---
if ($Version -eq 'latest') {
  if ($env:NUCLEAR_DOWNLOAD) {
    $Version = (Invoke-RestMethod "$($env:NUCLEAR_DOWNLOAD)/latest").ToString().Trim()
  } else {
    $Version = (Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'nuclearlang-installer' }).tag_name
  }
}
$Version = $Version.TrimStart('v')
$Name = "nuclearlang-$Version-windows-$Arch.zip"
$Base = if ($env:NUCLEAR_DOWNLOAD) { $env:NUCLEAR_DOWNLOAD } else { "https://github.com/$Repo/releases/download/v$Version" }

# --- download and check ---
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("nuclearlang-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
  Write-Host "Downloading NuclearLang $Version for Windows $Arch..."
  $Zip = Join-Path $Tmp $Name
  Invoke-WebRequest "$Base/$Name" -OutFile $Zip -UseBasicParsing
  $Want = ((Invoke-WebRequest "$Base/$Name.sha256" -UseBasicParsing).Content.ToString() -split '\s+')[0].ToLower()
  $Got = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLower()
  if ($Want -ne $Got) { throw 'the download is damaged (SHA-256 does not match); try again' }

  # --- install ---
  Expand-Archive $Zip -DestinationPath $Tmp -Force
  Remove-Item -Recurse -Force $Install -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path (Split-Path $Install) -Force | Out-Null
  Move-Item (Join-Path $Tmp 'nuclearlang') $Install
  & (Join-Path $Bin 'nuclear.exe') dialect list | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'the installed nuclear does not run on this system' }

  if (-not $NoAgent) {
    foreach ($d in $SkillDirs) {
      New-Item -ItemType Directory -Path $d -Force | Out-Null
      Remove-Item -Recurse -Force (Join-Path $d 'nuclear') -ErrorAction SilentlyContinue
      Copy-Item -Recurse (Join-Path $Install 'agents\skills\nuclear') $d
    }
  }

  if (-not $NoVSCode -and (Get-Command code -ErrorAction SilentlyContinue)) {
    $Vsix = Join-Path $Tmp "nuclearlang-$Version.vsix"
    try {
      Invoke-WebRequest "$Base/nuclearlang-$Version.vsix" -OutFile $Vsix -UseBasicParsing
      code --install-extension $Vsix --force *> $null
      Write-Host 'VS Code extension installed.'
    } catch { }
  }
} finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

# --- the PATH ---
if (-not $NoModifyPath -and -not ($UserPath -contains $Bin)) {
  Set-UserPath (@($Bin) + $UserPath)
  $env:Path = "$Bin;$env:Path"
}

# --- the AI services (ADR-0106) ---
# Their environments live inside the installation: a machine already set up gets them again for this version, with
# the profile it had. A new one is asked; nothing is downloaded before the user chooses.
$Machine = Join-Path $env:APPDATA 'nuclearlang\ai.env'
if (-not $AiProfile -and (Test-Path $Machine)) {
  $AiProfile = (Get-Content $Machine | Where-Object { $_ -like 'NUCLEAR_AI_PROFILE=*' } | Select-Object -First 1) -replace '^NUCLEAR_AI_PROFILE=', ''
}
$AiNote = ''
if (-not $NoAi) {
  if (-not (Test-Path $Loop) -or -not (Get-Command node -ErrorAction SilentlyContinue)) {
    $AiNote = 'The AI services need Node.js for their set-up: install it and run `nuclear-loop setup`, or use the set-up of the VS Code extension.'
  } elseif ($AiProfile) {
    Write-Host ''
    Write-Host "The AI services, profile $AiProfile..."
    & $Loop setup --profile $AiProfile --yes
    if ($LASTEXITCODE -ne 0) { $AiNote = 'The AI services are not set up: run `nuclear-loop setup`.' }
  } elseif (-not $env:CI -and [Environment]::UserInteractive) {
    Write-Host ''
    Write-Host 'The AI services: local agents that write the code, and the Smart Graph. You choose what is downloaded.'
    & $Loop setup
    if ($LASTEXITCODE -ne 0) { $AiNote = 'The AI services are not set up: run `nuclear-loop setup` when you want them.' }
  } else {
    $AiNote = 'The AI services are not set up (no terminal here): run `nuclear-loop setup`.'
  }
}

Write-Host ''
Write-Host "NuclearLang $Version is installed: nuclear and dragonfly in $Bin."
if ($AiNote) { Write-Host $AiNote }
Write-Host 'Open a new terminal, then start with: nuclear help   ·   dragonfly new my_app   ·   dragonfly doctor'
