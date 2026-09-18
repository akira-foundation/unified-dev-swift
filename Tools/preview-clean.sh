#!/bin/zsh
# Removes this worktree's preview app and everything it made: the bundle, its database, the
# scratch repositories and workspaces its scenario created, its preferences and caches, a bridge
# registration pasted for it, and this worktree's fast build cache.
#
#   ./Tools/preview-clean.sh
#
# `make preview-clean`. docs/PREVIEW-APPS.md says what each step removes and why nothing else is touched.

set -euo pipefail
cd "$(dirname "$0")/.."
source "$PWD/Tools/guard.sh"

ROOT="$PWD/.build/preview"
FAST_ROOT="/tmp/unifieddev-dev-fast-$(printf '%s' "$PWD" | shasum | cut -c1-12)"

if [[ -f "$ROOT/identity.env" ]]; then
  ud_read_preview_identity "$ROOT/identity.env"
  ud_refuse_unless_preview "$PWD"
  APP="${UD_PREVIEW[app_path]}"
  ID="${UD_PREVIEW[bundle_id]}"
  DB="${UD_PREVIEW[database]}"
  SERVER="${UD_PREVIEW[bridge_server]}"
  ud_refuse_real_app "$APP"
  ud_refuse_real_db "$DB"
  ud_refuse_if_own_host "$APP" "$DB"

  for pid in $(ud_app_pids "$APP"); do
    echo "==> quitting ${UD_PREVIEW[app_name]} (pid $pid)"
    kill "$pid" 2>/dev/null || true
  done
  for _ in {1..20}; do
    [[ -z "$(ud_app_pids "$APP")" ]] && break
    sleep 0.5
  done
  if [[ -n "$(ud_app_pids "$APP")" ]]; then
    print -ru2 -- "==> ${UD_PREVIEW[app_name]} is still running. Quit it and run this again; nothing was removed."
    exit 1
  fi

  SOCKET="$(ud_socket_name "$DB")"
  tmux -L "$SOCKET" kill-server 2>/dev/null || true
  rm -f "${TMPDIR:-/tmp}/bridge-${SOCKET#unifieddev-}.sock"

  if /usr/bin/python3 -c '
import json, os, sys
try:
    servers = json.load(open(os.path.expanduser("~/.claude.json"))).get("mcpServers") or {}
except (OSError, ValueError):
    sys.exit(1)
sys.exit(0 if sys.argv[1] in servers else 1)
' "$SERVER"; then
    echo "==> removing the $SERVER entry from ~/.claude.json"
    claude mcp remove --scope user "$SERVER" >/dev/null
  fi
  for cli in codex grok; do
    if command -v "$cli" >/dev/null && "$cli" mcp get "$SERVER" >/dev/null 2>&1; then
      echo "==> removing the $SERVER entry from $cli"
      "$cli" mcp remove "$SERVER" >/dev/null
    fi
  done

  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -u "$APP" >/dev/null 2>&1 || true
  /usr/bin/defaults delete "$ID" >/dev/null 2>&1 || true
  for item in "Preferences/$ID.plist" "Saved Application State/$ID.savedState" "Caches/$ID" \
    "HTTPStorages/$ID" "HTTPStorages/$ID.binarycookies" "WebKit/$ID" "Application Support/Unified Dev ($ID)"; do
    if [[ -e "$HOME/Library/$item" ]]; then
      echo "==> removing ~/Library/$item"
      rm -rf "$HOME/Library/$item"
    fi
  done
else
  echo "==> no preview was built here, so only the directory and the build cache are looked at"
fi

if [[ -d "$ROOT" ]]; then
  echo "==> removing $ROOT"
  rm -rf "$ROOT"
fi

if [[ -d "$FAST_ROOT" ]]; then
  if [[ -d "$FAST_ROOT/lock" ]]; then
    print -ru2 -- "==> a fast build is running in $FAST_ROOT, so its cache was left alone."
    exit 1
  fi
  echo "==> removing $FAST_ROOT"
  rm -rf "$FAST_ROOT"
fi

echo "==> nothing of this worktree's preview is left"
