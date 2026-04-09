# ventoy-toolkit

Automated ISO management and live-boot Claude Code setup for a [Ventoy](https://www.ventoy.net/) multi-boot USB drive.

## What's included

- **`update-isos.sh`** — checks 10 bootable ISOs for updates, downloads newest versions, cleans old from `~/Downloads`, and syncs to a mounted Ventoy drive
- **`setup-claude.sh`** — first-boot script that installs Claude Code CLI with AWS Bedrock and bypass permissions on any persistent live session
- **`ventoy.json`** — Ventoy persistence plugin config mapping ISOs to their persistence images

## Managed ISOs

| Image | Type | Persistence | Update method |
|-------|------|-------------|---------------|
| Ubuntu (latest LTS) | Linux installer/live | casper-rw | Auto (releases.ubuntu.com) |
| RealmWatch OS | Custom Ubuntu live | casper-rw | Manual |
| Windows 11 | Windows installer | N/A | Manual (microsoft.com/software-download) |
| Kali Linux Live | Penetration testing | persistence | Auto via torrent (cdimage.kali.org) |
| Tails | Privacy OS | N/A (own encryption) | Auto (tails.net) |
| ChromeOS Flex | Chrome OS | N/A | Auto (Google recovery config) |
| Hiren's Boot CD PE | Windows PE rescue toolkit | N/A | Auto (hirensbootcd.org) |
| GParted Live | Partition manager | N/A | Auto (gparted.org) |
| Clonezilla | Disk cloning/imaging | N/A | Auto (clonezilla.org) |
| Memtest86+ | RAM diagnostics | N/A | Auto (GitHub releases) |
| netboot.xyz | Network boot utility | N/A | Auto (GitHub releases) |

## Quick start

### Update ISOs

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

### Live-boot Claude Code

1. Boot Ubuntu, RealmWatch OS, or Kali from the Ventoy menu (persistence auto-selects)
2. Run the setup script once:
   ```bash
   bash /media/*/Ventoy/setup-claude.sh
   ```
3. Enter your AWS Bedrock credentials when prompted
4. Run `claude` — it's configured with bypass permissions and Bedrock provider
5. Reboot anytime — your setup persists

## Persistence

Ventoy persistence lets live sessions save changes across reboots. Three 4GB persistence images are pre-configured:

| ISO | Persistence image | Label |
|-----|-------------------|-------|
| Ubuntu 24.04 LTS | `persistence/ubuntu.dat` | `casper-rw` |
| RealmWatch OS 2.0 | `persistence/realmwatch.dat` | `casper-rw` |
| Kali Linux 2026.1 | `persistence/kali.dat` | `persistence` |

Create persistence images with Ventoy's bundled script:
```bash
# 4GB image with casper-rw label (Ubuntu/derivatives)
sudo bash CreatePersistentImg.sh -s 4096 -l casper-rw -o /media/$USER/Ventoy/persistence/name.dat

# Kali (needs persistence label + config file)
sudo bash CreatePersistentImg.sh -s 4096 -l persistence -c persistence.conf -o /media/$USER/Ventoy/persistence/kali.dat
```

Copy `ventoy.json` to `/media/$USER/Ventoy/ventoy/ventoy.json` on the USB drive.

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

## Notes

- **Windows 11** cannot be auto-downloaded (Microsoft requires browser interaction). The script will remind you to update manually.
- **ChromeOS Flex** boots from Ventoy for live testing but the installer may not work. For actual installation, flash directly with `dd` or Etcher.
- **Kali Linux** live ISOs are only available via torrent from the official mirrors. The script uses `transmission-cli` as a fallback.
- **Tails** manages its own encrypted persistent storage and does not use Ventoy persistence.
- The Ventoy drive is expected at `/media/$USER/Ventoy`. Adjust `VENTOY_MOUNT` in the script if your mount point differs.
- Persistence images (`.dat` files) are not tracked in git — create them on the USB drive directly.

## License

MIT
