#!/usr/bin/env bash
# install.sh - Install/Update the amp command
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kenotron-ms/amplifier-setup/main/install.sh | bash
#
# This script is idempotent - safe to run multiple times to get latest version.
#
# What it does:
# 1. Downloads latest amp.sh and amp-workspace.sh from GitHub
# 2. Installs them to ~/.amp/
# 3. Adds source line to shell RC files (if not already present)
# 4. Sources for current session

set -e

# Check for update mode (skip shell RC modifications)
UPDATE_MODE=false
if [[ "${1:-}" == "--update" ]]; then
    UPDATE_MODE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "🚀 Installing amp command..."
echo ""

# Configuration
AMP_HOME="${AMP_HOME:-$HOME/.amp}"
AMP_SCRIPT="$AMP_HOME/amp.sh"
BASE_URL="https://raw.githubusercontent.com/kenotron-ms/amplifier-setup/main"

# List of all scripts to install/update
SCRIPTS=("amp.sh" "amp-workspace.sh" "install.sh" "uninstall.sh")

# Clean up old script versions if they exist
if [[ -f "$AMP_SCRIPT" ]]; then
    echo "🧹 Cleaning up old scripts..."
    rm -f "$AMP_SCRIPT" "$AMP_HOME/amp-workspace.sh"
    # Also remove ready flag to trigger proper bootstrap/update on next run
    rm -f "$AMP_HOME/.amp_ready"
    echo "✅ Old scripts removed"
    echo ""
fi

# Create installation directory
echo "📁 Creating installation directory..."
mkdir -p "$AMP_HOME"

# Check if we're running from a local clone (amp.sh in same directory as install.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_AMP_SCRIPT="$SCRIPT_DIR/amp.sh"
LOCAL_WORKSPACE_SCRIPT="$SCRIPT_DIR/amp-workspace.sh"

if [[ -f "$LOCAL_AMP_SCRIPT" ]]; then
    # Use local copy (development mode)
    echo "📦 Using local scripts from repository..."
    for script in "${SCRIPTS[@]}"; do
        local_script="$SCRIPT_DIR/$script"
        if [[ -f "$local_script" ]]; then
            cp -f "$local_script" "$AMP_HOME/$script"
            chmod +x "$AMP_HOME/$script"
        fi
    done
    echo "✅ Installed local scripts"
else
    # Always download latest from GitHub (idempotent updates)
    echo "📥 Downloading latest scripts from GitHub..."

    if command -v curl &> /dev/null; then
        for script in "${SCRIPTS[@]}"; do
            if ! curl -fsSL "$BASE_URL/$script" -o "$AMP_HOME/$script.tmp" 2>/dev/null; then
                # amp.sh is required, others are optional
                if [[ "$script" == "amp.sh" ]]; then
                    echo -e "${RED}❌ Failed to download $script${NC}" >&2
                    echo -e "${YELLOW}💡 Check your internet connection and try again${NC}" >&2
                    exit 1
                fi
                continue
            fi
            mv -f "$AMP_HOME/$script.tmp" "$AMP_HOME/$script"
            chmod +x "$AMP_HOME/$script"
        done

    elif command -v wget &> /dev/null; then
        for script in "${SCRIPTS[@]}"; do
            if ! wget -q "$BASE_URL/$script" -O "$AMP_HOME/$script.tmp" 2>/dev/null; then
                # amp.sh is required, others are optional
                if [[ "$script" == "amp.sh" ]]; then
                    echo -e "${RED}❌ Failed to download $script${NC}" >&2
                    echo -e "${YELLOW}💡 Check your internet connection and try again${NC}" >&2
                    exit 1
                fi
                rm -f "$AMP_HOME/$script.tmp"
                continue
            fi
            mv -f "$AMP_HOME/$script.tmp" "$AMP_HOME/$script"
            chmod +x "$AMP_HOME/$script"
        done

    else
        echo -e "${RED}❌ Neither curl nor wget found${NC}" >&2
        echo -e "${YELLOW}💡 Install curl or wget and try again${NC}" >&2
        exit 1
    fi

    echo "✅ Downloaded latest scripts"
fi

# Add to shell RC files (skip in update mode)
if ! $UPDATE_MODE; then
    echo ""
    echo "🔧 Configuring shell..."

    # Clean up old references first (from previous versions)
    for RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$RC_FILE" ]]; then
            # Remove old .amplifier references
            if grep -q "\.amplifier" "$RC_FILE" 2>/dev/null; then
                echo "  🧹 Removing old .amplifier references from $(basename "$RC_FILE")..."
                sed -i.bak '/\.amplifier/d' "$RC_FILE"
                rm -f "${RC_FILE}.bak"
            fi
            # Remove old amp comment lines
            sed -i.bak '/# Amplifier (amp command)/d' "$RC_FILE" 2>/dev/null || true
            rm -f "${RC_FILE}.bak"
        fi
    done

    SOURCE_LINE="source $AMP_SCRIPT"
    COMMENT_LINE="# Amplifier (amp command)"

    for RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do
        # Only modify if the file exists or is the primary shell
        SHOULD_UPDATE=false

        if [[ -f "$RC_FILE" ]]; then
            SHOULD_UPDATE=true
        elif [[ "$RC_FILE" == "$HOME/.bashrc" ]] && [[ "$SHELL" == */bash ]]; then
            SHOULD_UPDATE=true
            touch "$RC_FILE"
        elif [[ "$RC_FILE" == "$HOME/.zshrc" ]] && [[ "$SHELL" == */zsh ]]; then
            SHOULD_UPDATE=true
            touch "$RC_FILE"
        fi

        if $SHOULD_UPDATE; then
            # Check if already configured
            if grep -q "source.*amp.sh" "$RC_FILE" 2>/dev/null; then
                echo "  ✓ $(basename "$RC_FILE") already configured"
            else
                # Add source line
                {
                    echo ""
                    echo "$COMMENT_LINE"
                    echo "$SOURCE_LINE"
                } >> "$RC_FILE"
                echo "  ✅ Added to $(basename "$RC_FILE")"
            fi
        fi
    done
else
    echo ""
    echo "🔧 Scripts updated..."
fi

# Show success message
echo ""
if $UPDATE_MODE; then
    echo -e "${GREEN}✅ Scripts updated!${NC}"
else
    # Reload shell config to load amp command
    echo "🔄 Reloading shell configuration..."

    # Determine which RC file to reload based on current shell
    if [[ "$SHELL" == */zsh ]]; then
        RELOAD_CMD="source ~/.zshrc"
        SHELL_NAME="zsh"
        # shellcheck disable=SC1090
        source ~/.zshrc 2>/dev/null || source "$AMP_SCRIPT"
    elif [[ "$SHELL" == */bash ]]; then
        RELOAD_CMD="source ~/.bashrc"
        SHELL_NAME="bash"
        # shellcheck disable=SC1090
        source ~/.bashrc 2>/dev/null || source "$AMP_SCRIPT"
    else
        RELOAD_CMD="source $AMP_SCRIPT"
        SHELL_NAME="$(basename "$SHELL")"
        # shellcheck disable=SC1090
        source "$AMP_SCRIPT"
    fi

    echo "✅ Shell configuration reloaded for $SHELL_NAME"

    echo ""
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo ""

    # Provide exact reload command based on detected shell
    echo -e "${YELLOW}⚡ IMPORTANT: Reload your shell to use amp${NC}"
    echo ""
    echo "Copy and paste this command:"
    echo ""
    echo -e "${GREEN}  $RELOAD_CMD${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🚀 Then cd to any project folder and type:"
    echo ""
    echo -e "${GREEN}  amp${NC}"
    echo ""
    echo "📖 Documentation: https://github.com/kenotron-ms/amplifier-setup#readme"
    echo ""
fi
