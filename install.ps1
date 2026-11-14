# Registers the scheduled task that runs watchdog.ps1 from this folder (at logon + every 5 min) for the
# current user, without elevation, and runs it once. -Uninstall removes the task. Windows PowerShell 5.1 compatible.
param(
    [switch]$Uninstall,
    [string]$TaskName = 'Claude Always-On'
)
$ErrorActionPreference = 'Stop'

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false   # the session, session-id.txt and the log stay
    return
}

$me     = [Security.Principal.WindowsIdentity]::GetCurrent()
$script = [Security.SecurityElement]::Escape((Join-Path $PSScriptRoot 'watchdog.ps1'))
# Two triggers: the logon trigger's repetition only starts at the next logon (a task registered mid-session
# ran once and did not repeat within 400 s), so the time trigger repeats from the moment of install.
$xml = @"
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Keeps one background Claude Code session alive (at logon + every 5 min). Script: $script</Description>
  </RegistrationInfo>
  <Principals>
    <Principal id="Author">
      <UserId>$($me.User.Value)</UserId>
      <LogonType>InteractiveToken</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
    <Hidden>true</Hidden>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
  </Settings>
  <Triggers>
    <LogonTrigger>
      <Delay>PT30S</Delay>
      <Repetition>
        <Interval>PT5M</Interval>
      </Repetition>
      <UserId>$([Security.SecurityElement]::Escape($me.Name))</UserId>
    </LogonTrigger>
    <TimeTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
      </Repetition>
      <StartBoundary>$(Get-Date -Format s)</StartBoundary>
    </TimeTrigger>
  </Triggers>
  <Actions Context="Author">
    <Exec>
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$script"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
Register-ScheduledTask -TaskName $TaskName -Xml $xml -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
