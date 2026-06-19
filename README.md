# Codex Bundled Plugin Repair

> Repair Codex's bundled marketplace plugins (browser, computer-use, chrome, latex, sites) when they disappear or fail to load after a Microsoft Store update on Windows.

[![Codex Skill](https://img.shields.io/badge/Codex-Skill-blueviolet)](#)

## Problem

After a Codex update from the Microsoft Store, the bundled plugin cache at `%USERPROFILE%\.codex\.tmp\bundled-marketplaces\openai-bundled` **gets out of sync** with the installed app. The cache often has missing plugins or incomplete marketplace manifests. Chromes Native Messaging Host (`extension-host.exe`) also locks cached files, preventing the app from rebuilding the cache correctly.

**Result:** Built-in plugins (browser, computer-use, chrome, latex, sites) are disabled or fail to load.

## Solution

This Codex skill **creates a directory junction** (Windows symlink) from the stale cache location to the actual plugin source in the WindowsApps installation directory. This approach is:

- **Permanent** — the cache always reflects the source
- **Update-proof** — the script dynamically locates the current WindowsApps path
- **Safe** — the old cache is backed up with a timestamp before being replaced

## Quick Install

### Prerequisites

- Codex on **Windows** (Microsoft Store installation)
- Windows 10+

### Via skill-installer (recommended)

Tell Codex in any conversation:

> "Help me install the **bundled-plugin-repair** skill from GitHub"

Or use the CLI directly:

```bash
python scripts/install-skill-from-github.py `
  --repo alexzeng2014/codex-bundled-plugin-repair `
  --path skills/bundled-plugin-repair
```

### Manual

1. Download the `skills/bundled-plugin-repair/` directory
2. Copy it to `%USERPROFILE%\.codex\skills\bundled-plugin-repair`
3. Restart Codex

## Usage

When bundled plugins stop working, say:

> "The bundled plugins aren't working"
> "电脑操控/浏览器等内置插件用不了了，帮我修复"

The skill auto-triggers and will:

1. Kill `extension-host.exe` (releases file locks)
2. Find the current Codex WindowsApps path dynamically
3. Back up the stale cache to `openai-bundled.bak-<timestamp>`
4. Create a junction from the cache path to the real source
5. Tell you to restart Codex

After restart, all bundled plugins are restored.

### Run manually

```powershell
.\skills\bundled-plugin-repair\scripts\repair-bundled-plugins.ps1
```

## Repo Structure

```
codex-bundled-plugin-repair/
├── README.md
└── skills/
    └── bundled-plugin-repair/     # Codex skill
        ├── SKILL.md               # Trigger instructions
        ├── agents/
        │   └── openai.yaml        # Discovery metadata
        └── scripts/
            └── repair-bundled-plugins.ps1  # Repair script
```

## How It Works (Technical)

1. **Kill locks** — Terminates `extension-host.exe` to release file handles
2. **Detect path** — `Get-AppxPackage -Name "OpenAI.Codex"` locates the current WindowsApps install
3. **Backup** — Renames stale cache to `openai-bundled.bak-YYYYMMDD-HHmmss`
4. **Junction** — `mklink /J` creates a directory link from cache → source
5. **Verify** — Confirms the link and lists available plugins

## Notes

- **Windows-only:** This bug is specific to Codex on Windows (MS Store distribution)
- **After major updates:** The junction still points to the old WindowsApps path. Re-run the skill to update it
- **Recovery:** Backup directories are left in place — delete them once youre satisfied everything works
- **Root cause:** The issue is an upstream Codex bug involving temporary cache directories and Chrome extension-host file locking. This skill is a reliable workaround until the official fix ships

## Contributing

PRs and issues welcome! Found additional symptoms or improvements? Open an issue.

## License

MIT
