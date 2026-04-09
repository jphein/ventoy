#!/usr/bin/env bash
# update-isos.sh — Check for updates, download newest, clean old from ~/Downloads,
#                   and optionally sync to a mounted Ventoy drive.
set -euo pipefail

DOWNLOAD_DIR="$HOME/Downloads"
VENTOY_MOUNT="/media/$USER/Ventoy"
LOG_FILE="/tmp/ventoy-update.log"
DRY_RUN=false
SYNC_VENTOY=false

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --dry-run     Show what would be done without downloading"
    echo "  -s, --sync        Also sync updated ISOs to mounted Ventoy drive"
    echo "  -d, --dir DIR     Download directory (default: ~/Downloads)"
    echo "  -h, --help        Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)  DRY_RUN=true; shift ;;
        -s|--sync)     SYNC_VENTOY=true; shift ;;
        -d|--dir)      DOWNLOAD_DIR="$2"; shift 2 ;;
        -h|--help)     usage ;;
        *)             echo "Unknown option: $1"; usage ;;
    esac
done

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()    { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()     { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()    { echo -e "${RED}[ ERR]${NC} $*"; }
header() { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

# Track what changed for the summary
declare -a UPDATED=()
declare -a SKIPPED=()
declare -a FAILED=()

# Download a file, removing old versions that match a glob pattern.
# Usage: download_iso "Name" "url" "new_filename" "old_glob_pattern"
download_iso() {
    local name="$1" url="$2" new_file="$3" old_glob="$4"
    local dest="$DOWNLOAD_DIR/$new_file"

    if [[ -f "$dest" ]]; then
        ok "$name: already have $new_file"
        SKIPPED+=("$name")
        return 0
    fi

    # Remove old versions
    local old_files=()
    while IFS= read -r -d '' f; do
        old_files+=("$f")
    done < <(find "$DOWNLOAD_DIR" -maxdepth 1 -name "$old_glob" ! -name "$new_file" -print0 2>/dev/null)

    if [[ ${#old_files[@]} -gt 0 ]]; then
        for f in "${old_files[@]}"; do
            log "$name: removing old $(basename "$f")"
            $DRY_RUN || rm -f "$f"
        done
    fi

    if $DRY_RUN; then
        log "$name: would download $new_file"
        UPDATED+=("$name (dry-run)")
        return 0
    fi

    log "$name: downloading $new_file ..."
    if curl -fSL --progress-bar "$url" -o "$dest.tmp" && mv "$dest.tmp" "$dest"; then
        ok "$name: downloaded $new_file ($(du -h "$dest" | cut -f1))"
        UPDATED+=("$name")
    else
        rm -f "$dest.tmp"
        err "$name: download failed"
        FAILED+=("$name")
        return 1
    fi
}

# --- Ubuntu LTS ---
check_ubuntu() {
    header "Ubuntu (latest LTS)"
    # Scrape the current LTS version from releases.ubuntu.com
    local version
    version=$(curl -sfL "https://releases.ubuntu.com/" \
        | grep -oP '\d+\.\d+(\.\d+)? LTS' | head -1 | awk '{print $1}')
    if [[ -z "$version" ]]; then
        err "Ubuntu: could not determine latest LTS version"
        FAILED+=("Ubuntu"); return 1
    fi
    local file="ubuntu-${version}-desktop-amd64.iso"
    local url="https://releases.ubuntu.com/${version}/${file}"
    # Verify the URL exists
    if ! curl -sfI "$url" >/dev/null 2>&1; then
        # Try without point release in path
        url="https://releases.ubuntu.com/${version%.*}/${file}"
        if ! curl -sfI "$url" >/dev/null 2>&1; then
            err "Ubuntu: could not find download for $file"
            FAILED+=("Ubuntu"); return 1
        fi
    fi
    log "Ubuntu: latest LTS is $version"
    download_iso "Ubuntu" "$url" "$file" "ubuntu-*-desktop-amd64.iso"
}

# --- Windows 11 ---
check_windows() {
    header "Windows 11"
    # Windows ISOs require browser-based download from Microsoft — can't automate.
    # Just report what we have.
    local existing
    existing=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "Win11_*.iso" -printf '%f\n' 2>/dev/null | head -1)
    if [[ -n "$existing" ]]; then
        warn "Windows 11: have $existing (manual update only — download from microsoft.com/software-download)"
    else
        warn "Windows 11: no ISO found (download manually from microsoft.com/software-download)"
    fi
    SKIPPED+=("Windows 11 (manual)")
}

# --- netboot.xyz ---
check_netbootxyz() {
    header "netboot.xyz"
    local tag
    tag=$(curl -sfL -o /dev/null -w '%{url_effective}' "https://github.com/netbootxyz/netboot.xyz/releases/latest" \
        | grep -oP 'v?\K[\d.]+$' || true)
    if [[ -z "$tag" ]]; then
        err "netboot.xyz: could not determine latest version"
        FAILED+=("netboot.xyz"); return 1
    fi
    log "netboot.xyz: latest is $tag"
    local file="netboot.xyz-${tag}.iso"
    local url="https://github.com/netbootxyz/netboot.xyz/releases/download/${tag}/netboot.xyz.iso"
    download_iso "netboot.xyz" "$url" "$file" "netboot.xyz*.iso"
}

# --- Memtest86+ ---
check_memtest() {
    header "Memtest86+"
    local tag
    tag=$(curl -sfL -o /dev/null -w '%{url_effective}' "https://github.com/memtest86plus/memtest86plus/releases/latest" \
        | grep -oP 'v\K[\d.]+$' || true)
    if [[ -z "$tag" ]]; then
        err "Memtest86+: could not determine latest version"
        FAILED+=("Memtest86+"); return 1
    fi
    log "Memtest86+: latest is v$tag"
    local file="memtest86plus-${tag}.iso"
    if [[ -f "$DOWNLOAD_DIR/$file" ]]; then
        ok "Memtest86+: already have $file"
        SKIPPED+=("Memtest86+"); return 0
    fi
    # Download zip, extract ISO
    local zip_url="https://memtest.org/download/v${tag}/mt86plus_${tag}_x86_64.grub.iso.zip"
    if $DRY_RUN; then
        log "Memtest86+: would download v$tag"
        UPDATED+=("Memtest86+ (dry-run)"); return 0
    fi
    local tmpzip="/tmp/memtest86plus-${tag}.zip"
    if curl -fSL --progress-bar "$zip_url" -o "$tmpzip"; then
        unzip -o "$tmpzip" -d /tmp/ >/dev/null
        mv /tmp/grub-memtest.iso "$DOWNLOAD_DIR/$file"
        rm -f "$tmpzip"
        # Clean old
        find "$DOWNLOAD_DIR" -maxdepth 1 -name "memtest86plus-*.iso" ! -name "$file" -delete
        ok "Memtest86+: downloaded $file"
        UPDATED+=("Memtest86+")
    else
        err "Memtest86+: download failed"
        FAILED+=("Memtest86+")
    fi
}

# --- Tails ---
check_tails() {
    header "Tails"
    local version
    version=$(curl -sfL "https://tails.net/install/download/index.en.html" \
        | grep -oP 'tails-amd64-\K[\d.]+' | head -1)
    if [[ -z "$version" ]]; then
        err "Tails: could not determine latest version"
        FAILED+=("Tails"); return 1
    fi
    log "Tails: latest is $version"
    local file="tails-${version}.img"
    local url="https://download.tails.net/tails/stable/tails-amd64-${version}/tails-amd64-${version}.img"
    download_iso "Tails" "$url" "$file" "tails-*.img"
}

# --- Kali Linux ---
check_kali() {
    header "Kali Linux"
    # Kali only offers torrents for live ISOs — download the torrent file,
    # then use transmission-cli if available.
    local version
    version=$(curl -sfL "http://cdimage.kali.org/current/" \
        | grep -oP 'kali-linux-\K[0-9]+\.[0-9]+' | head -1)
    if [[ -z "$version" ]]; then
        err "Kali: could not determine latest version"
        FAILED+=("Kali"); return 1
    fi
    log "Kali: latest is $version"
    local file="kali-linux-${version}-live-amd64.iso"
    if [[ -f "$DOWNLOAD_DIR/$file" ]]; then
        ok "Kali: already have $file"
        SKIPPED+=("Kali"); return 0
    fi
    if $DRY_RUN; then
        log "Kali: would download $file via torrent"
        UPDATED+=("Kali (dry-run)"); return 0
    fi
    # Try direct download first
    local direct_url="http://cdimage.kali.org/kali-${version}/${file}"
    if curl -sfI "$direct_url" >/dev/null 2>&1; then
        # Clean old
        find "$DOWNLOAD_DIR" -maxdepth 1 -name "kali-linux-*-live-amd64.iso" ! -name "$file" -delete
        download_iso "Kali" "$direct_url" "$file" "kali-linux-*-live-amd64.iso"
        return
    fi
    # Fall back to torrent
    if ! command -v transmission-cli >/dev/null 2>&1; then
        warn "Kali: only available via torrent and transmission-cli not installed"
        warn "  Install with: sudo apt install transmission-cli"
        FAILED+=("Kali (needs torrent)"); return 1
    fi
    local torrent_url="http://cdimage.kali.org/current/${file}.torrent"
    local torrent_file="/tmp/kali-current.torrent"
    curl -sfL "$torrent_url" -o "$torrent_file"
    # Clean old versions
    find "$DOWNLOAD_DIR" -maxdepth 1 -name "kali-linux-*-live-amd64.iso" -delete
    find "$DOWNLOAD_DIR" -maxdepth 1 -name "kali-linux-*-live-amd64.iso.part" -delete
    log "Kali: starting torrent download (this may take a while)..."
    if transmission-cli --download-dir "$DOWNLOAD_DIR" "$torrent_file"; then
        ok "Kali: downloaded $file"
        UPDATED+=("Kali")
    else
        err "Kali: torrent download failed or was interrupted"
        FAILED+=("Kali")
    fi
}

# --- GParted ---
check_gparted() {
    header "GParted Live"
    local filename
    filename=$(curl -sfL "https://gparted.org/download.php" \
        | grep -oP 'gparted-live-[\d.]+-\d+-amd64\.iso' | head -1)
    if [[ -z "$filename" ]]; then
        err "GParted: could not determine latest version"
        FAILED+=("GParted"); return 1
    fi
    local version
    version=$(echo "$filename" | grep -oP '[\d.]+-\d+')
    log "GParted: latest is $version"
    local url="https://downloads.sourceforge.net/gparted/${filename}"
    download_iso "GParted" "$url" "$filename" "gparted-live-*.iso"
}

# --- Hiren's Boot CD PE ---
check_hirens() {
    header "Hiren's Boot CD PE"
    # Hiren's doesn't version their download URL cleanly.
    # The filename is always HBCD_PE_x64.iso. Check the page for version info.
    local version
    version=$(curl -sfL "https://www.hirensbootcd.org/download/" \
        | grep -oP '(?:Version|PE x64)[^\d]*([\d.]+)' | grep -oP '[\d.]+' | head -1 || echo "unknown")
    log "Hiren's: latest is v$version"
    local file="hirens-bootcd-pe-${version}.iso"
    local url="https://www.hirensbootcd.org/files/HBCD_PE_x64.iso"
    download_iso "Hiren's" "$url" "$file" "hirens-bootcd-pe*.iso"
}

# --- Clonezilla ---
check_clonezilla() {
    header "Clonezilla"
    local version
    version=$(curl -sfL "https://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/" \
        | grep -oP 'clonezilla_live_stable/\K[\d.]+-\d+' | sort -Vr | head -1)
    if [[ -z "$version" ]]; then
        err "Clonezilla: could not determine latest version"
        FAILED+=("Clonezilla"); return 1
    fi
    log "Clonezilla: latest is $version"
    local file="clonezilla-live-${version}-amd64.iso"
    local url="https://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/${version}/${file}/download"
    download_iso "Clonezilla" "$url" "$file" "clonezilla-live-*.iso"
}

# --- ChromeOS Flex ---
check_chromeos() {
    header "ChromeOS Flex"
    # ChromeOS Flex recovery image — scrape version from known URL pattern.
    # The recovery config JSON has the latest URL.
    # ChromeOS Flex uses a recovery config with all Chromebook models.
    # "reven" is the board name for ChromeOS Flex.
    local recovery_url
    recovery_url=$(curl -sfL "https://dl.google.com/dl/edgedl/chromeos/recovery/recovery.conf" \
        | awk '/^name=.*reven/{found=1} found && /^url=/{print; exit}' \
        | sed 's/^url=//' | tr -d '\r' || true)
    if [[ -z "$recovery_url" ]]; then
        # Fallback: try the chromeos recovery JSON endpoint
        recovery_url=$(curl -sfL "https://dl.google.com/dl/edgedl/chromeos/recovery/recovery2.json" \
            | grep -oP '"url"\s*:\s*"\K[^"]*reven[^"]*' | head -1 || true)
    fi
    if [[ -z "$recovery_url" ]]; then
        warn "ChromeOS Flex: could not auto-detect latest version"
        warn "  Check manually: https://chromeos.exerra.xyz/"
        SKIPPED+=("ChromeOS Flex (manual check needed)"); return 0
    fi
    local bin_filename
    bin_filename=$(basename "$recovery_url")
    local version
    version=$(echo "$bin_filename" | grep -oP 'chromeos_\K[\d.]+' || echo "unknown")
    log "ChromeOS Flex: latest is $version"
    local file="chromeos-flex-${version}.img"
    if [[ -f "$DOWNLOAD_DIR/$file" ]]; then
        ok "ChromeOS Flex: already have $file"
        SKIPPED+=("ChromeOS Flex"); return 0
    fi
    if $DRY_RUN; then
        log "ChromeOS Flex: would download $file"
        UPDATED+=("ChromeOS Flex (dry-run)"); return 0
    fi
    # Download zip, extract, rename .bin to .img for Ventoy
    local tmpzip="/tmp/chromeos-flex.zip"
    log "ChromeOS Flex: downloading (~1.2GB compressed)..."
    if curl -fSL --progress-bar "$recovery_url" -o "$tmpzip"; then
        log "ChromeOS Flex: extracting..."
        local bin_file
        bin_file=$(unzip -l "$tmpzip" | grep -oP '\S+\.bin$' | head -1)
        unzip -o "$tmpzip" -d /tmp/ >/dev/null
        mv "/tmp/$bin_file" "$DOWNLOAD_DIR/$file"
        rm -f "$tmpzip"
        # Clean old
        find "$DOWNLOAD_DIR" -maxdepth 1 -name "chromeos-flex-*.img" ! -name "$file" -delete
        ok "ChromeOS Flex: downloaded $file ($(du -h "$DOWNLOAD_DIR/$file" | cut -f1))"
        UPDATED+=("ChromeOS Flex")
    else
        rm -f "$tmpzip"
        err "ChromeOS Flex: download failed"
        FAILED+=("ChromeOS Flex")
    fi
}

# --- Sync to Ventoy ---
sync_ventoy() {
    header "Syncing to Ventoy"
    if [[ ! -d "$VENTOY_MOUNT" ]]; then
        warn "Ventoy drive not mounted at $VENTOY_MOUNT — skipping sync"
        return 1
    fi

    local free_kb
    free_kb=$(df --output=avail "$VENTOY_MOUNT" | tail -1 | tr -d ' ')

    log "Ventoy free space: $((free_kb / 1024 / 1024))G"

    # Map of download filename glob → ventoy filename pattern
    # For each ISO in downloads, copy to ventoy if newer or missing
    local count=0
    for src in "$DOWNLOAD_DIR"/*.iso "$DOWNLOAD_DIR"/*.img; do
        [[ -f "$src" ]] || continue
        local base
        base=$(basename "$src")
        # Skip non-bootable ISOs we don't manage
        case "$base" in
            ubuntu-*|Win11_*|netboot.xyz*|memtest86plus-*|tails-*|kali-linux-*|gparted-live-*|hirens-bootcd-*|clonezilla-live-*|chromeos-flex-*) ;;
            *) continue ;;
        esac

        local dest="$VENTOY_MOUNT/$base"

        # Check if ventoy has an older version (different filename with same prefix)
        local prefix
        prefix=$(echo "$base" | sed -E 's/[-_][0-9].*//')
        # Remove old versions on Ventoy with the same prefix
        while IFS= read -r -d '' old; do
            if [[ "$(basename "$old")" != "$base" ]]; then
                log "Ventoy: removing old $(basename "$old")"
                $DRY_RUN || rm -f "$old"
            fi
        done < <(find "$VENTOY_MOUNT" -maxdepth 1 \( -name "${prefix}*.iso" -o -name "${prefix}*.img" \) -print0 2>/dev/null)

        if [[ -f "$dest" ]] && [[ $(stat -c%s "$src") -eq $(stat -c%s "$dest") ]]; then
            ok "Ventoy: $base (up to date)"
            continue
        fi

        local size_kb
        size_kb=$(($(stat -c%s "$src") / 1024))
        if [[ $size_kb -gt $free_kb ]]; then
            err "Ventoy: not enough space for $base (need $((size_kb/1024))M, have $((free_kb/1024))M)"
            continue
        fi

        if $DRY_RUN; then
            log "Ventoy: would copy $base"
        else
            log "Ventoy: copying $base..."
            cp "$src" "$dest"
            sync
            ok "Ventoy: copied $base"
            free_kb=$((free_kb - size_kb))
        fi
        ((count++))
    done

    if [[ $count -eq 0 ]]; then
        ok "Ventoy: everything up to date"
    fi
}

# --- Main ---
main() {
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Ventoy ISO Update Checker          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    $DRY_RUN && warn "DRY RUN — no files will be downloaded or deleted"
    echo ""

    mkdir -p "$DOWNLOAD_DIR"

    check_ubuntu
    check_windows
    check_netbootxyz
    check_memtest
    check_tails
    check_kali
    check_gparted
    check_hirens
    check_clonezilla
    check_chromeos

    if $SYNC_VENTOY; then
        sync_ventoy
    fi

    # Summary
    header "Summary"
    [[ ${#UPDATED[@]} -gt 0 ]] && ok "Updated: ${UPDATED[*]}"
    [[ ${#SKIPPED[@]} -gt 0 ]] && log "Up to date: ${SKIPPED[*]}"
    [[ ${#FAILED[@]} -gt 0 ]]  && err "Failed: ${FAILED[*]}"
    echo ""
    if ! $SYNC_VENTOY; then
        log "Run with --sync to copy updated ISOs to Ventoy drive"
    fi
}

main "$@"
