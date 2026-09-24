# Public entry point:  irm https://boot.azif.ca/go|iex
#
# Signs in to GitHub, then fetches and runs the real bootstrap from a
# private repo. Nothing secret or environment-specific lives here.
#
# Sign-in uses GitHub's device flow (the same one `gh auth login` uses): you
# approve a one-time code at github.com/login/device in the browser. If `gh`
# is already on PATH and logged in, its token is reused and no prompt shows.

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$REPO = "cplewes/work_startup_script"
$ENTRY = "bootstrap.ps1"
$CLIENT_ID = "178c6fc778ccc68e1d6a"   # GitHub CLI's public OAuth app
$SCOPES = "repo read:org gist"

function Get-ExistingToken {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $null }
    try {
        $t = (& gh auth token --hostname github.com 2>$null)
        if ($LASTEXITCODE -eq 0 -and $t) { return $t.Trim() }
    } catch { }
    return $null
}

function Get-DeviceFlowToken {
    $headers = @{ Accept = "application/json" }
    $code = Invoke-RestMethod -Method Post -Uri "https://github.com/login/device/code" -Headers $headers `
        -Body @{ client_id = $CLIENT_ID; scope = $SCOPES }

    Write-Host ""
    Write-Host "  Enter code $($code.user_code) at $($code.verification_uri)" -ForegroundColor Yellow
    Write-Host ""
    try { Set-Clipboard -Value $code.user_code } catch { }
    try { Start-Process $code.verification_uri } catch { }

    $interval = [int]$code.interval
    $deadline = (Get-Date).AddSeconds([int]$code.expires_in)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $interval
        $r = Invoke-RestMethod -Method Post -Uri "https://github.com/login/oauth/access_token" -Headers $headers `
            -Body @{ client_id = $CLIENT_ID; device_code = $code.device_code; grant_type = "urn:ietf:params:oauth:grant-type:device_code" }
        if ($r.access_token) { return $r.access_token }
        switch ($r.error) {
            "authorization_pending" { }
            "slow_down" { $interval += 5 }
            default { throw "GitHub sign-in failed: $($r.error) $($r.error_description)" }
        }
    }
    throw "GitHub sign-in timed out."
}

$token = Get-ExistingToken
if (-not $token) { $token = Get-DeviceFlowToken }

$resp = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/$REPO/contents/$ENTRY" `
    -Headers @{ Authorization = "token $token"; Accept = "application/vnd.github.raw" }
$script = [Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())

$env:WORK_GH_TOKEN = $token
Invoke-Expression $script
