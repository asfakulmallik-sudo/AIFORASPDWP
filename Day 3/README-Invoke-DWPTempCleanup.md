# Invoke-DWPTempCleanup.ps1 -- README

## Overview

`Invoke-DWPTempCleanup.ps1` is a safe, idempotent PowerShell 5.1 script for
DWP Engineers that clears temporary files from Windows endpoints. Every file
is moved to a backup staging folder before removal, enabling a full rollback
if anything goes wrong. All actions are written to a time-stamped log file.

---

## Pre-Run Checklist

| # | Requirement | Action |
|---|-------------|--------|
| 1 | **Run as Administrator** | Right-click PowerShell > "Run as administrator". Required to access `C:\Windows\Temp`. |
| 2 | **Backup drive space** | Ensure the drive that holds `BackupRoot` (default `C:\`) has free space at least equal to the total size of the temp folders. |
| 3 | **DryRun first** | Always run with `-DryRun` before going live to review the file list. |
| 4 | **Execution policy** | Run `Get-ExecutionPolicy`. If `Restricted`, ask your admin to allow scripts for the session. |
| 5 | **Non-production test** | Test on a non-critical endpoint before broad deployment. |

---

## What the Script Cleans

| Target | Default Path |
|--------|-------------|
| User Temp | `%TEMP%` (usually `C:\Users\<user>\AppData\Local\Temp`) |
| System Temp | `C:\Windows\Temp` |
| LocalAppData Temp | `%LOCALAPPDATA%\Temp` (deduplicated with User Temp if identical) |

**Only files with a Last Write Time strictly before today's midnight are targeted.**
Files modified today are never touched.

---

## What the Script Does NOT Touch

- Files created or modified today
- Files locked / in use by another process
- The root target folders themselves (only their contents)
- Any path outside the defined target list
- Registry, services, or any other system configuration

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-DryRun` | Switch | off | Lists files to be removed. No changes made. |
| `-Rollback` | Switch | off | Restores files from the most recent backup session. |
| `-BackupRoot` | String | `C:\DWPTempCleanupBackup` | Root folder for backup staging. Each run creates a timestamped sub-folder inside this. |
| `-LogRoot` | String | `C:\Logs\DWPTempCleanup` | Folder where log files are written. |

---

## Usage Examples

### 1. Preview (always do this first)
```powershell
.\Invoke-DWPTempCleanup.ps1 -DryRun
```
Lists every file that would be removed, its size, and its last modified date.
**No files are moved or deleted.**

### 2. Live cleanup
```powershell
.\Invoke-DWPTempCleanup.ps1
```
Moves eligible temp files to the backup staging folder and removes empty
sub-directories. Writes a full log and summary.

### 3. Rollback (undo the most recent run)
```powershell
.\Invoke-DWPTempCleanup.ps1 -Rollback
```
Reads the manifest from the most recent backup session and moves every file
back to its original location. Safe to re-run (already-restored files are
skipped).

### 4. Custom backup and log paths
```powershell
.\Invoke-DWPTempCleanup.ps1 -BackupRoot D:\Backups -LogRoot D:\Logs
```

---

## Step-by-Step Script Walkthrough

### Step 1 -- Enumerate eligible files
The script scans each target folder recursively using `Get-ChildItem -Recurse
-File -Force`. It filters for files whose `LastWriteTime` is before today's
midnight (`(Get-Date).Date`). Results are accumulated into an in-memory list
and the total file count and size are logged.

### Step 2 -- Create backup staging folder
A timestamped sub-folder is created inside `BackupRoot`
(e.g. `C:\DWPTempCleanupBackup\20260812_143022\`). If the folder already
exists (from an interrupted run), the script logs a warning and continues
without recreating it -- this is the idempotency guarantee.

### Step 3 -- Move files to backup staging
For each eligible file the script:
1. Checks the file still exists (skips with a log entry if already gone).
2. Tests whether the file is locked by attempting an exclusive open. If locked,
   it logs `SKIP (file locked)` and moves on -- the file is never forcibly
   closed or modified.
3. Generates a UUID-based filename (e.g. `a3f8...bak`) for the backup copy to
   avoid path-length or naming collisions.
4. Calls `Move-Item` to atomically move the file. On failure, logs the error
   and continues to the next file.
5. Records the original path, backup path, filename, size, and last-write-time
   in an in-memory manifest list.

### Step 4 -- Write rollback manifest
The manifest list is serialised to `manifest.json` inside the backup session
folder. This file is the only thing needed to perform a rollback. If writing
the manifest fails, the error is logged but the script continues (the backup
files still exist, they just cannot be automatically restored via `-Rollback`).

### Step 5 -- Remove empty sub-folders
After files are moved, the script walks each target folder and removes any
directories that are now empty. Directories are processed deepest-first
(longest path first) to avoid trying to remove a parent before its children.
The root target folder itself is never removed.

---

## Rollback Process

When `-Rollback` is specified:
1. The script locates the `manifest.json` from the most recent timestamped
   backup session folder.
2. For each manifest entry it checks whether the original path already exists
   (idempotency -- skip if so).
3. If the backup file exists, `Move-Item` restores it to the original path,
   recreating parent directories if necessary.
4. A rollback summary is written to the log.

After a successful rollback the backup session folder will be empty (or
contain only the manifest). You may delete it manually.

---

## Log Files

Logs are written to `C:\Logs\DWPTempCleanup\` by default.
Each run produces one file named `DWPTempCleanup_<yyyyMMdd_HHmmss>.log`.

Every log line has the format:
```
[yyyy-MM-dd HH:mm:ss] [LEVEL   ] Message
```

| Level | Meaning |
|-------|---------|
| INFO | General progress information |
| ACTION | A file or folder was moved, removed, or created |
| SKIP | A file was intentionally skipped (locked, already gone, etc.) |
| WARN | Non-fatal advisory (e.g. backup folder already exists) |
| ERROR | An operation failed; script continued to next item |
| SUMMARY | End-of-run totals |

---

## Idempotency

The script is safe to run multiple times against the same machine:

- Files already removed in a previous run are no longer present, so `Test-Path`
  returns false and they are silently skipped.
- The backup session folder is identified by a timestamp, so each run creates
  its own isolated session. Re-running does not corrupt a previous session.
- Rollback is also idempotent: files already restored are detected via
  `Test-Path` and skipped.

---

## Backup Folder Management

Each run creates a sub-folder such as:
```
C:\DWPTempCleanupBackup\
    20260812_143022\
        a3f8c1....bak
        d92f00....bak
        manifest.json
    20260813_090015\
        ...
```

Once you are confident a cleanup was successful and no rollback is needed,
delete the relevant timestamped sub-folder manually to recover the disk space.

---

## Safety Guarantees Summary

| Guarantee | How it is implemented |
|-----------|----------------------|
| Read-only DryRun | `-DryRun` flag -- zero file system writes |
| Only old files | `LastWriteTime -lt (Get-Date).Date` filter |
| Locked files skipped | Exclusive stream open test before every move |
| Errors do not stop the run | `try/catch` around every file operation |
| Full rollback | Files moved (not deleted) to backup; `manifest.json` records originals |
| Idempotent | `Test-Path` checks before every move and every restore |
| Full audit trail | Every action logged with timestamp to a dedicated log file |
