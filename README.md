# claude-always-on

Keeps one background [Claude Code](https://claude.com/claude-code) session alive on **Windows** across
logons, reboots and crashes, so there is always a session to reach through Remote Control.

A scheduled task runs `watchdog.ps1` at logon and every 5 minutes:

| The session recorded in `session-id.txt` | The watchdog |
|---|---|
| is running | does nothing |
| has stopped | continues it: `claude --bg --resume <sessionId>` |
| does not exist (first run, or the file was deleted) | starts one in the Desktop folder and records its job id: `claude --bg -n always-on --model haiku --add-dir %USERPROFILE% --remote-control` |

The session can work in your whole home folder (`--add-dir`) and can be reached from your other devices
(`--remote-control`). It lives in the Desktop folder because Claude Code does not keep the home folder
itself trusted. Change the name, model or flags on that line of `watchdog.ps1`, and the folder in its
`-Dir` parameter.

## Requirements

Windows 10/11 · Windows PowerShell 5.1 · Claude Code CLI at `%USERPROFILE%\.local\bin\claude.exe`,
signed in (last checked on 2.1.325) · Python on `PATH`, used only by the trust repair below.

## Install

```powershell
git clone https://github.com/ssafy-jinhyeok/claude-always-on "$env:USERPROFILE\.claude\always-on"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\always-on\install.ps1"
```

`install.ps1` registers the task `Claude Always-On` for the current user, without elevation, and runs it
once. The clone is the installation: the task runs `watchdog.ps1` from that folder, so `git pull`
updates it. Run `install.ps1` again if you move the folder.

The task has two triggers, each repeating every 5 minutes: one at logon and one from the time of install.
The second is there because the first only starts repeating at the next logon.

## Trust repair

`claude --bg` does not start in a folder that Claude Code does not trust. When a start is refused with
`Workspace not trusted`, the watchdog sets `hasTrustDialogAccepted` for that one folder in
`~/.claude.json`, and the next run starts the session. This is the watchdog's only write outside its own
folder. It means that installing this tool trusts your Desktop folder (or the `-Dir` you set) without
the trust dialog.

## Files

| File | Holds |
|---|---|
| `session-id.txt` | the job id of the session (not the session id, which `/clear` changes). Other tools can read it to tell whether they run in the always-on session. |
| `watchdog.log` | one line per resume, start or trust repair, and nothing while the session is running. It is not rotated. |

Neither is committed.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\always-on\install.ps1" -Uninstall
```

This removes the task only. The session keeps running until you stop it (`claude agents` lists it); then
delete the folder.

## License

MIT
