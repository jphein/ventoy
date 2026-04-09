# ventoy-toolkit

Automated ISO management for a [Ventoy](https://www.ventoy.net/) multi-boot USB drive.

`update-isos.sh` checks for the latest versions of common bootable ISOs, downloads updates to `~/Downloads`, cleans up old versions, and optionally syncs everything to a mounted Ventoy drive.

## Managed ISOs

| Image | Type | Update method |
|-------|------|---------------|
| Ubuntu (latest LTS) | Linux installer/live | Auto (releases.ubuntu.com) |
| Windows 11 | Windows installer | Manual (microsoft.com/software-download) |
| Kali Linux Live | Penetration testing | Auto via torrent (cdimage.kali.org) |
| Tails | Privacy OS | Auto (tails.net) |
| ChromeOS Flex | Chrome OS | Auto (Google recovery config) |
| Hiren's Boot CD PE | Windows PE rescue toolkit | Auto (hirensbootcd.org) |
| GParted Live | Partition manager | Auto (gparted.org) |
| Clonezilla | Disk cloning/imaging | Auto (clonezilla.org) |
| Memtest86+ | RAM diagnostics | Auto (GitHub releases) |
| netboot.xyz | Network boot utility | Auto (GitHub releases) |

## Usage

```bash
# Check for updates (dry run — no downloads)
./update-isos.sh --dry-run

# Download updates to ~/Downloads
./update-isos.sh

# Download updates and sync to Ventoy drive
./update-isos.sh --sync

# Custom download directory
./update-isos.sh --dir /path/to/isos --sync
```

## Options

| Flag | Description |
|------|-------------|
| `-n`, `--dry-run` | Show what would be done without downloading |
| `-s`, `--sync` | Copy updated ISOs to mounted Ventoy drive |
| `-d`, `--dir DIR` | Set download directory (default: `~/Downloads`) |
| `-h`, `--help` | Show help |

## Requirements

- `curl` — for downloading ISOs
- `unzip` — for extracting Memtest86+ and ChromeOS Flex
- `transmission-cli` — for Kali Linux (torrent only). Install with `sudo apt install transmission-cli`

## How it works

1. For each ISO, the script scrapes the project's official site or GitHub API for the latest version
2. Compares against what's already in `~/Downloads`
3. Downloads new versions and removes old ones
4. With `--sync`, copies everything to `/media/$USER/Ventoy`, removing outdated ISOs from the drive

## Notes

- **Windows 11** cannot be auto-downloaded (Microsoft requires browser interaction). The script will remind you to update manually.
- **ChromeOS Flex** boots from Ventoy for live testing but the installer may not work. For actual installation, flash directly with `dd` or Etcher.
- **Kali Linux** live ISOs are only available via torrent from the official mirrors. The script uses `transmission-cli` as a fallback.
- The Ventoy drive is expected at `/media/$USER/Ventoy`. Adjust `VENTOY_MOUNT` in the script if your mount point differs.

## License

MIT
