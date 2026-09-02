#!/bin/bash
# Setup script for Linux/macOS
# Creates/verifies symlinks for submodule addons and skills

CONFIG_FILE="symlink-config.txt"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config|-c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--config CONFIG_FILE]"
            echo "  --config   Configuration file (default: symlink-config.txt)"
            exit 1
            ;;
    esac
done

echo "Setting up submodule symlinks..."

# Get the script's directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/$CONFIG_FILE"

# Check if config file exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_PATH"
    echo "Expected format: target_path=source_path"
    exit 1
fi

# Read and parse configuration
declare -a LINK_CONFIGS
while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -n "$line" && ! "$line" =~ ^# ]]; then
        if [[ "$line" =~ ^(.+)=(.+)$ ]]; then
            target="${BASH_REMATCH[1]// /}"
            source="${BASH_REMATCH[2]// /}"
            LINK_CONFIGS+=("$target|$source")
        fi
    fi
done < "$CONFIG_PATH"

if [ ${#LINK_CONFIGS[@]} -eq 0 ]; then
    echo "No symlink configurations found in $CONFIG_FILE"
    exit 0
fi

echo "Found ${#LINK_CONFIGS[@]} symlink configuration(s)"
echo ""

# Track changes made
declare -a CHANGES_MADE

# Process each symlink configuration
for config in "${LINK_CONFIGS[@]}"; do
    IFS='|' read -r target_rel source_rel <<< "$config"
    target_path="$SCRIPT_DIR/$target_rel"
    source_path="$SCRIPT_DIR/$source_rel"

    action="NONE"

    # Check if source exists
    if [ ! -e "$source_path" ]; then
        echo "❌ $target_rel -> ERROR: Source not found ($source_rel)"
        echo "   Make sure submodules are initialized: git submodule update --init --recursive"
        continue
    fi

    # Determine if source is a file or directory
    if [ -f "$source_path" ]; then
        source_is_file=true
    else
        source_is_file=false
    fi

    # Check current state of target
    needs_creation=true
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        if [ -L "$target_path" ]; then
            if [ "$(realpath "$target_path" 2>/dev/null)" = "$(realpath "$source_path" 2>/dev/null)" ]; then
                needs_creation=false
                echo "✅ $target_rel -> $source_rel (already correct)"
            fi
        fi

        if [ "$needs_creation" = "true" ]; then
            echo "🔄 $target_rel -> $source_rel (recreating)"
            rm -rf "$target_path"
            action="RECREATED"
        fi
    else
        echo "➕ $target_rel -> $source_rel (creating)"
        action="CREATED"
    fi

    # Create the symlink if needed
    if [ "$needs_creation" = "true" ]; then
        target_parent=$(dirname "$target_path")
        if [ ! -d "$target_parent" ]; then
            mkdir -p "$target_parent"
        fi

        relative_path=$(realpath --relative-to="$(dirname "$target_path")" "$source_path")

        if ln -s "$relative_path" "$target_path"; then
            CHANGES_MADE+=("$action $target_rel -> $source_rel")
        else
            echo "   ERROR: Failed to create symlink"
        fi
    fi
done

echo ""
if [ ${#CHANGES_MADE[@]} -gt 0 ]; then
    echo "Changes made:"
    for change in "${CHANGES_MADE[@]}"; do
        echo "  • $change"
    done
else
    echo "No changes needed - all symlinks are correct!"
fi

# One-time Godot asset import: a fresh clone has no .godot/imported cache, and game instances
# launched before the first import hang on import-cache contention (worst when the validation
# suite fans out in parallel). The validation runners guard for this too — this just front-loads
# the wait to setup time. Skipped when Godot isn't installed yet.
GAME_PROJECT="$SCRIPT_DIR/src"
GODOT_BIN="${GODOT_EXE:-$(command -v godot 2>/dev/null)}"
if [ -f "$GAME_PROJECT/project.godot" ] && [ ! -d "$GAME_PROJECT/.godot/imported" ]; then
    if [ -n "$GODOT_BIN" ]; then
        echo ""
        echo "Importing Godot project assets (one-time)..."
        "$GODOT_BIN" --headless --import --path "$GAME_PROJECT" > /dev/null
    else
        echo ""
        echo "Godot not on PATH — skipping the one-time asset import (the validation runners will do it on first use)."
    fi
fi

echo ""
echo "Setup complete!"
