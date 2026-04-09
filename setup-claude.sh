#!/usr/bin/env bash
# setup-claude.sh — First-boot setup for Claude Code on a Ventoy live USB.
# Run once after booting into a persistent Ubuntu/Kali session.
# Usage: bash /media/*/Ventoy/setup-claude.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${CYAN}[*]${NC} $*"; }
ok()  { echo -e "${GREEN}[+]${NC} $*"; }
err() { echo -e "${RED}[-]${NC} $*"; }

# --- Node.js ---
if command -v node >/dev/null 2>&1; then
    ok "Node.js already installed: $(node --version)"
else
    log "Installing Node.js via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    ok "Node.js installed: $(node --version)"
fi

# --- Claude Code CLI ---
if command -v claude >/dev/null 2>&1; then
    ok "Claude Code already installed: $(claude --version 2>/dev/null || echo 'installed')"
else
    log "Installing Claude Code..."
    sudo npm install -g @anthropic-ai/claude-code
    ok "Claude Code installed"
fi

# --- AWS Bedrock configuration ---
log "Configuring AWS Bedrock provider..."

mkdir -p ~/.claude

# Claude Code settings — bypass permissions by default
cat > ~/.claude/settings.json << 'SETTINGS'
{
    "permissions": {
        "allow": [
            "Bash(*)",
            "Read(*)",
            "Write(*)",
            "Edit(*)",
            "Glob(*)",
            "Grep(*)",
            "WebSearch(*)",
            "WebFetch(*)",
            "Agent(*)"
        ],
        "deny": []
    }
}
SETTINGS
ok "Claude Code permissions set to bypass"

# AWS credentials
mkdir -p ~/.aws
if [[ -f ~/.aws/credentials ]] && grep -q aws_access_key_id ~/.aws/credentials 2>/dev/null; then
    ok "AWS credentials already configured"
else
    echo ""
    echo "Enter your AWS Bedrock credentials (or press Ctrl+C to skip):"
    read -rp "  AWS Access Key ID: " aws_key
    read -rp "  AWS Secret Access Key: " aws_secret
    read -rp "  AWS Region [us-east-1]: " aws_region
    aws_region=${aws_region:-us-east-1}

    cat > ~/.aws/credentials << CREDS
[default]
aws_access_key_id = ${aws_key}
aws_secret_access_key = ${aws_secret}
CREDS

    cat > ~/.aws/config << CONF
[default]
region = ${aws_region}
output = json
CONF
    chmod 600 ~/.aws/credentials
    ok "AWS credentials saved"
fi

# Set Claude Code to use Bedrock
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL="us.anthropic.claude-opus-4-20250514"

# Persist env vars for future sessions
PROFILE="$HOME/.bashrc"
if ! grep -q CLAUDE_CODE_USE_BEDROCK "$PROFILE" 2>/dev/null; then
    cat >> "$PROFILE" << 'ENV'

# Claude Code via AWS Bedrock
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL="us.anthropic.claude-opus-4-20250514"
ENV
    ok "Bedrock env vars added to .bashrc"
fi

echo ""
ok "Setup complete! Run 'claude' to start."
echo ""
