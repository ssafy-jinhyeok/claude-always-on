# Keeps one background Claude Code session alive across logons, reboots and crashes.
# Run by the "Claude Always-On" scheduled task (at logon + every 5 min). Windows PowerShell 5.1 compatible.
param(
    [string]$Name   = 'always-on',
    [string]$Dir    = ([Environment]::GetFolderPath('Desktop')),   # home itself can't host --bg sessions (never persistently trusted)
    [string]$IdFile = (Join-Path $PSScriptRoot 'session-id.txt')   # job id, not sessionId: /clear changes the sessionId
)
$claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
$log    = Join-Path $PSScriptRoot 'watchdog.log'

function Get-Agents {
    $json = & $claude agents --json --all
    if ($LASTEXITCODE -ne 0) { exit 1 }   # can't tell the state: do nothing rather than spawn a duplicate
    $json | ConvertFrom-Json | ForEach-Object { $_ }   # 5.1 emits a JSON array as one object; unroll it
}

$id = if (Test-Path $IdFile) { (Get-Content $IdFile -Raw).Trim() }
$s  = if ($id) { Get-Agents | Where-Object { $_.id -eq $id } | Select-Object -First 1 }
if ($s -and $s.pid) { exit 0 }   # alive

# A just-crashed session is respawned by the built-in daemon within ~20s; if we race it, the extra
# copy ends up in state "failed" and is harmless.
Set-Location $Dir
if ($s) {
    $out = & $claude --bg --resume $s.sessionId 2>&1   # extra flags would make --bg start a copy instead of continuing it
} else {
    $out = & $claude --bg -n $Name --model haiku --add-dir $env:USERPROFILE --remote-control 2>&1   # kept across wake
    if (($out -join ' ') -match 'backgrounded\D+([0-9a-f]{8})') {
        $new = Get-Agents | Where-Object { $_.id -eq $Matches[1] } | Select-Object -First 1
        if ($new) { Set-Content $IdFile $new.id }
    }
}
"{0:s} {1} -> {2}" -f (Get-Date), $(if ($s) { 'resume' } else { 'create' }), ($out -join ' | ') | Add-Content $log

# ~/.claude.json once got recreated from scratch (2026-10-25), dropping trust for $Dir and blocking every
# spawn for 38h. Re-grant it for this one folder (atomic replace); the next run then spawns normally.
if (($out -join ' ') -match 'Workspace not trusted') {
    $py = @'
import json, os, sys
p = os.path.expanduser('~/.claude.json')
with open(p, encoding='utf-8') as f: c = json.load(f)
c.setdefault('projects', {}).setdefault(sys.argv[1], {})['hasTrustDialogAccepted'] = True
with open(p + '.watchdog-tmp', 'w', encoding='utf-8') as f: json.dump(c, f, indent=2, ensure_ascii=False)
os.replace(p + '.watchdog-tmp', p)
'@
    $res = try { & python -I -c $py ($Dir -replace '\\', '/') 2>&1 } catch { "$_" }   # no python on PATH: log it
    "{0:s} trust re-grant for {1} -> exit {2} {3}" -f (Get-Date), $Dir, $LASTEXITCODE, ($res -join ' | ') | Add-Content $log
}
