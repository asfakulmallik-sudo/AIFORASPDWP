# Invoke-TempCleanup.ps1

Read-only-safe PowerShell 5.1 script for DWP engineers to clean temporary files from Windows endpoints.

Files are **moved to a backup folder**, not permanently deleted. A rollback option restores them.

---

## Requirements

| Requirement | Detail |
|---|---|
| PowerShell | 5.1 or later |
| Rights | Standard user for `%TEMP%`; local admin for `%SystemRoot%\Temp` |
| Execution policy | `RemoteSigned` or `Bypass` (confirm your local policy) |

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-DryRun` | Switch | Off | Lists files that **would** be moved; makes no changes |
| `-OlderThanDays` | Int (0–3650) | `0` | Only target files last modified more than N days ago. `0` = all files |
| `-Rollback` | Switch | Off | Restores all files from the **most recent** backup session |
| `-BackupRoot` | String | `%TEMP%\_CleanupBackup` | Root folder for backup sessions |
| `-LogRoot` | String | `<script folder>\Logs` | Folder where log files are written |
| `-TargetFolders` | String[] | User temp + System temp | One or more folders to scan |

---

## Usage Examples

### 1. Preview what would be removed (no changes)
```powershell
.\Invoke-TempCleanup.ps1 -DryRun
```

### 2. Preview files older than 30 days
```powershell
.\Invoke-TempCleanup.ps1 -DryRun -OlderThanDays 30
```

### 3. Live run — clean all temp files
```powershell
.\Invoke-TempCleanup.ps1
```

### 4. Live run — only files older than 14 days
```powershell
.\Invoke-TempCleanup.ps1 -OlderThanDays 14
```

### 5. Clean a custom folder
```powershell
.\Invoke-TempCleanup.ps1 -TargetFolders 'C:\CustomTemp' -OlderThanDays 7
```

### 6. Use a custom backup and log location
```powershell
.\Invoke-TempCleanup.ps1 -BackupRoot 'D:\Backups\TempCleanup' -LogRoot 'D:\Logs'
```

### 7. Roll back the most recent cleanup session
```powershell
.\Invoke-TempCleanup.ps1 -Rollback
```

---

## How It Works

### Cleanup (live run)
1. Scans each target folder recursively for files matching the age filter.
2. Tests whether each file is locked by another process; locked files are skipped and logged.
3. Moves qualifying files to a timestamped backup session folder (e.g. `%TEMP%\_CleanupBackup\2026-08-05_14-30-00\`).
4. Writes a `manifest.csv` to the backup session folder recording original paths.
5. Logs every action to a timestamped log file (`Logs\cleanup_YYYY-MM-DD_HH-mm-ss.log`).
6. Prints a summary at the end.

### Rollback
- Reads `manifest.csv` from the most recent backup session.
- Moves each file back to its original location.
- Skips files that already exist at the original path (safe to re-run).

### Dry Run
- No files are moved or backed up.
- Logs and prints a list of files that **would** be processed.

---

## Default Target Folders

| Variable | Typical Path |
|---|---|
| `$env:TEMP` | `C:\Users\<username>\AppData\Local\Temp` |
| `$env:SystemRoot\Temp` | `C:\Windows\Temp` |

Override with `-TargetFolders` if you need to clean other locations.

---

## Log Files

- Stored in `<script folder>\Logs\` by default.
- One log file per run, named `cleanup_YYYY-MM-DD_HH-mm-ss.log`.
- Each line is prefixed with a timestamp and level: `INFO`, `WARN`, `ERROR`, or `DRY`.

---

## Idempotency

Running the script multiple times is safe:
- Files already moved in a previous run no longer exist in the source folder and will not be processed again.
- Rollback skips files that already exist at the original path.
- Backup session folders are uniquely timestamped and do not overwrite each other.

---

## Safety Notes

- **No permanent deletion**: files are moved to a backup folder, not deleted.
- **Locked files are skipped**: the script catches the lock, logs it, and continues.
- **Per-file error handling**: a failure on one file does not stop the rest of the run.
- Always use `-DryRun` first on an unfamiliar machine to review scope before a live run.
- Backup folders can accumulate over time; periodically review and remove old sessions under `BackupRoot` once you are satisfied those files are no longer needed.
