---
name: bundled-plugin-repair
description: >
  Repair Codex bundled marketplace plugins when they become unavailable
  after a Windows app update. This skill kills locked processes (extension-host),
  backs up the stale plugin cache, and creates a junction (symlink) pointing
  to the current WindowsApps installation source so that browser, computer-use,
  chrome, latex, sites and other bundled plugins are restored.
  Use when the user says bundled plugins (电脑操控/浏览器/插件) are missing,
  disabled, or not loading. After executing, tell the user to restart Codex.
---

# Bundled Plugin Repair

## When to use

  The user reports that bundled plugins (browser / in-app-browser / computer-use /
  chrome / latex / sites) are missing, disabled, or failing to load.
  Common symptom: Codex updated (auto-update from Microsoft Store) and certain
  built-in plugins no longer work.

## Procedure

  1. Run `scripts/repair-bundled-plugins.ps1` -- it handles everything:
     - Kills any running `extension-host.exe` (Chrome Native Messaging) that may
       lock files in the tmp cache.
     - Locates the current Codex WindowsApps installation path dynamically.
     - Backs up the stale `%USERPROFILE%\.codex\.tmp\bundled-marketplaces\openai-bundled`
       directory to `openai-bundled.bak-<timestamp>`.
     - Removes the stale directory entirely.
     - Creates a Windows junction (directory symlink) from the tmp cache path to
       the actual source in WindowsApps, so future updates are automatically
       reflected.
  2. Report to the user what was done, and ask them to **restart Codex**.
  3. After restart, verify the bundled plugins are available again.

## Important notes

  - The junction avoids the root cause: the tmp cache going out of sync with
    the installed app bundle after a Microsoft Store update.
  - After a major Codex version update, the WindowsApps InstallLocation path
    changes. The script finds the latest path dynamically, but if the skill
    is used again later and the script fails, re-run it -- it will re-create
    the junction with the updated InstallLocation.
  - This is a Windows-only issue. Do not use this skill on macOS or Linux.
  - The backup is named with a timestamp and left in the same parent directory,
    so if something goes wrong the user can manually restore it.
