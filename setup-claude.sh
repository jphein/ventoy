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

# --- Claude Code settings ---
mkdir -p ~/.claude

# Bypass permissions by default
cat > ~/.claude/settings.json << 'SETTINGS'
{
    "model": "claude-opus-4-6",
    "reasoning_effort": "max",
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
ok "Claude Code: Opus 4.6, max effort, bypass permissions"

# --- Provider selection ---
echo ""
echo "Select Claude Code provider:"
echo ""
echo "  1) Claude Pro/Teams/Max    — browser login (easiest)"
echo "  2) Anthropic API (direct)  — needs ANTHROPIC_API_KEY"
echo "  3) AWS Bedrock             — needs AWS credentials"
echo "  4) Google Vertex AI        — needs GCP credentials"
echo "  5) Azure AI Foundry        — needs Azure endpoint + key"
echo "  6) Skip provider setup"
echo ""
read -rp "Choice [1-6]: " provider_choice

PROFILE="$HOME/.bashrc"

# Clean any previous provider config from .bashrc
sed -i '/^# Claude Code provider/,/^$/d' "$PROFILE" 2>/dev/null
sed -i '/CLAUDE_CODE_USE_BEDROCK\|CLAUDE_CODE_USE_VERTEX\|CLAUDE_CODE_USE_FOUNDRY\|ANTHROPIC_API_KEY\|ANTHROPIC_BASE_URL\|ANTHROPIC_AUTH_TOKEN\|ANTHROPIC_FOUNDRY/d' "$PROFILE" 2>/dev/null

case "${provider_choice:-1}" in
    1)
        log "Configuring Claude Pro/Teams/Max (OAuth)..."
        # Teams/Pro just needs no API key set — uses browser OAuth
        unset ANTHROPIC_API_KEY 2>/dev/null
        cat >> "$PROFILE" << 'ENVEOF'

# Claude Code provider — Pro/Teams/Max (OAuth)
unset ANTHROPIC_API_KEY
ENVEOF
        ok "OAuth provider configured"
        log "Run 'claude login' to authenticate via browser"
        if command -v claude >/dev/null 2>&1; then
            read -rp "  Open browser login now? [Y/n]: " do_login
            if [[ "${do_login:-y}" =~ ^[Yy]$ ]]; then
                claude login
            fi
        fi
        ;;
    2)
        log "Configuring Anthropic API (direct)..."
        if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
            ok "ANTHROPIC_API_KEY already set"
        else
            read -rp "  Anthropic API Key: " api_key
            cat >> "$PROFILE" << ENVEOF

# Claude Code provider — Anthropic API (direct)
export ANTHROPIC_API_KEY="${api_key}"
ENVEOF
            export ANTHROPIC_API_KEY="$api_key"
            ok "Anthropic API key saved"
        fi
        ;;
    3)
        log "Configuring AWS Bedrock..."
        mkdir -p ~/.aws
        if [[ -f ~/.aws/credentials ]] && grep -q aws_access_key_id ~/.aws/credentials 2>/dev/null; then
            ok "AWS credentials already configured"
        else
            echo ""
            read -rp "  AWS Access Key ID: " aws_key
            read -rsp "  AWS Secret Access Key: " aws_secret; echo
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
        cat >> "$PROFILE" << 'ENVEOF'

# Claude Code provider — AWS Bedrock
export CLAUDE_CODE_USE_BEDROCK=1
ENVEOF
        export CLAUDE_CODE_USE_BEDROCK=1
        ok "Bedrock provider configured"
        ;;
    4)
        log "Configuring Google Vertex AI..."
        read -rp "  GCP Project ID: " gcp_project
        read -rp "  GCP Region [us-east5]: " gcp_region
        gcp_region=${gcp_region:-us-east5}

        cat >> "$PROFILE" << ENVEOF

# Claude Code provider — Google Vertex AI
export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION="${gcp_region}"
export ANTHROPIC_VERTEX_PROJECT_ID="${gcp_project}"
ENVEOF
        export CLAUDE_CODE_USE_VERTEX=1
        export CLOUD_ML_REGION="$gcp_region"
        export ANTHROPIC_VERTEX_PROJECT_ID="$gcp_project"

        # Check for gcloud auth
        if command -v gcloud >/dev/null 2>&1; then
            log "Run 'gcloud auth application-default login' to authenticate"
        else
            log "Installing gcloud CLI..."
            curl https://sdk.cloud.google.com | bash -s -- --disable-prompts
            ok "Run 'gcloud auth application-default login' to authenticate"
        fi
        ok "Vertex AI provider configured"
        ;;
    5)
        log "Configuring Azure AI Foundry..."
        read -rp "  Foundry Base URL (e.g. https://your-resource.services.ai.azure.com): " foundry_url
        read -rp "  Foundry API Key: " foundry_key

        cat >> "$PROFILE" << ENVEOF

# Claude Code provider — Azure AI Foundry
export CLAUDE_CODE_USE_FOUNDRY=1
export ANTHROPIC_FOUNDRY_BASE_URL="${foundry_url}"
export ANTHROPIC_FOUNDRY_API_KEY="${foundry_key}"
ENVEOF
        export CLAUDE_CODE_USE_FOUNDRY=1
        export ANTHROPIC_FOUNDRY_BASE_URL="$foundry_url"
        export ANTHROPIC_FOUNDRY_API_KEY="$foundry_key"
        ok "Azure AI Foundry provider configured"
        ;;
    6)
        log "Skipping provider setup — configure manually later"
        ;;
    *)
        err "Invalid choice, skipping provider setup"
        ;;
esac

echo ""
ok "Setup complete! Run 'claude' to start."
echo ""
