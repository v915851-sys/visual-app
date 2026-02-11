# push_and_run.ps1
# Prompt for GitHub PAT securely, push repo to GitHub, trigger workflow and print Actions URL.
# Usage: powershell -ExecutionPolicy Bypass -File .\push_and_run.ps1

param()

function Read-Secret {
  param([string]$prompt = "Enter secret")
  $s = Read-Host -AsSecureString -Prompt $prompt
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Write-Host "This script will push the current repo to GitHub and trigger the Debug APK workflow.`nIt will ask for a GitHub Personal Access Token (repo + workflow scopes)." -ForegroundColor Yellow

# Prompt text uses double quotes because it contains an apostrophe (won't)
$token = Read-Secret -prompt "Enter GitHub PAT (won't be saved)"
if (-not $token) { Write-Error "No token provided; aborting."; exit 1 }
$headers = @{ Authorization = "token $token"; 'User-Agent'='visual-app-ci-script' ; 'Accept'='application/vnd.github.v3+json' }

# Get authenticated user
try {
  $user = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -Method Get
  $owner = $user.login
  Write-Host "Authenticated as: $owner" -ForegroundColor Green
} catch {
  Write-Error "Failed to authenticate with provided token: $_"; exit 1
}

# Ensure git repo
if (-not (Test-Path .git)) { git init | Out-Null }

# Set default user if missing
$curName = git config user.name
if (-not $curName) { git config user.name "$owner" }
$curEmail = git config user.email
if (-not $curEmail) { git config user.email "$owner@users.noreply.github.com" }

# Add remote if not exists
$remote = git remote get-url origin 2>$null
if (-not $remote) {
  $remoteUrl = "https://github.com/$owner/visual-app.git"
  git remote add origin $remoteUrl
  Write-Host "Added remote origin -> $remoteUrl"
} else { Write-Host "Remote origin exists: $remote" }

# Commit if needed
$status = git status --porcelain
if ($status) {
  git add -A
  git commit -m "CI: push for APK build"
  Write-Host "Committed local changes." -ForegroundColor Green
} else {
  Write-Host "No local changes to commit." -ForegroundColor Gray
}

# Force push to main
try {
  git branch -M main
  # Use ${} to safely expand variables when adjacent to punctuation
  $pushUrl = "https://${owner}:${token}@github.com/${owner}/visual-app.git"
  Write-Host "Pushing to $pushUrl (token is used only for this push)..." -ForegroundColor Yellow
  git push --force $pushUrl main
  Write-Host "Push completed." -ForegroundColor Green
} catch {
  Write-Error "Push failed: $_"; exit 1
}

# Trigger workflow dispatch
$workflow = 'build-debug-apk.yml'
$dispatchUrl = "https://api.github.com/repos/$owner/visual-app/actions/workflows/$workflow/dispatches"
# Use double quotes for the ref value to avoid single-quote parse issues in some environments
$body = @{ ref = "main" } | ConvertTo-Json
try {
  Invoke-RestMethod -Uri $dispatchUrl -Headers $headers -Method Post -Body $body
  Write-Host "Workflow dispatched (workflow: $workflow)." -ForegroundColor Green
} catch {
  Write-Error "Failed to dispatch workflow: $_"; exit 1
}

# Poll recent runs for the dispatched workflow
Start-Sleep -Seconds 2
$runsUrl = "https://api.github.com/repos/$owner/visual-app/actions/runs?event=workflow_dispatch&per_page=5"
try {
  $runs = Invoke-RestMethod -Uri $runsUrl -Headers $headers -Method Get
  if ($runs.workflow_runs -and $runs.workflow_runs.Count -gt 0) {
    $latest = $runs.workflow_runs | Select-Object -First 1
    Write-Host "Latest run: $($latest.html_url)" -ForegroundColor Cyan
    Write-Host "You can open that URL in your browser to follow progress and download artifacts." -ForegroundColor Cyan
  } else {
    Write-Host "No workflow runs found yet; check the Actions page in the repo." -ForegroundColor Yellow
  }
} catch {
  Write-Error "Failed to list workflow runs: $_"
}

# Clear token from memory
$token = $null
Write-Host "Done." -ForegroundColor Green
