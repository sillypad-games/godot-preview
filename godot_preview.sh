#!/usr/bin/env bash
# godot-preview: Capture screenshots from Godot 4 scenes without a display.
#
# Uses Godot's --write-movie flag to render frames to an AVI, then extracts
# a single PNG frame with ffmpeg. Works in headless CI, SSH sessions, and
# Claude Code agents — anywhere you can't open a window or use screencapture.
#
# Requirements:
#   - Godot 4.x (tested with 4.4.1)
#   - ffmpeg
#
# Usage:
#   godot-preview capture <project_path> <scene_path> [options]
#   godot-preview compare <project_path> <scene_path> [options]
#
# Examples:
#   # Capture a single scene at phone resolution
#   godot-preview capture ./my_game res://scenes/lobby.tscn
#
#   # Capture at custom resolution, grab frame 8 (after camera settles)
#   godot-preview capture ./my_game res://scenes/arena.tscn -r 1280x720 -f 8
#
#   # Capture multiple angles (frames 1,5,10)
#   godot-preview capture ./my_game res://scenes/lobby.tscn -f 1,5,10
#
#   # Output to specific file
#   godot-preview capture ./my_game res://scenes/lobby.tscn -o /tmp/preview.png

set -euo pipefail

# --- Defaults ---
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
RESOLUTION="1080x1920"
FRAME="5"
FPS="1"
RENDER_SECONDS="10"
OUTPUT_DIR="/tmp/godot-preview"
OUTPUT_FILE=""
VERBOSE=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat <<'USAGE'
godot-preview — Capture screenshots from Godot 4 scenes for AI-assisted iteration.

COMMANDS:
  capture   Render a scene and extract PNG frame(s)
  list      Show available scenes in a project
  help      Show this help

CAPTURE OPTIONS:
  -r, --resolution WxH    Viewport resolution (default: 1080x1920)
  -f, --frame N[,N,...]   Frame number(s) to extract (default: 5)
  -s, --seconds N         Seconds to render (default: 10)
  --fps N                 Render FPS (default: 1, use higher for animations)
  -o, --output PATH       Output PNG path (default: /tmp/godot-preview/scene_name.png)
  -g, --godot PATH        Path to Godot binary
  -v, --verbose           Show Godot output
  -h, --help              Show this help

ENVIRONMENT:
  GODOT_BIN               Path to Godot binary (default: /Applications/Godot.app/Contents/MacOS/Godot)

DESIGNED FOR AI AGENTS:
  This tool enables a visual iteration loop for Claude Code and similar
  AI coding agents working with Godot projects. The typical workflow:

    1. Agent modifies .tscn/.gd files
    2. Agent runs: godot-preview capture ./project res://scenes/my_scene.tscn
    3. Agent reads the output PNG to SEE the rendered result
    4. Agent makes corrections based on what it sees
    5. Repeat until visuals are correct

  This replaces the need for screen recording permissions, display access,
  or manual screenshots from the user.
USAGE
}

log() { echo -e "${CYAN}[godot-preview]${NC} $*"; }
warn() { echo -e "${YELLOW}[godot-preview]${NC} $*"; }
err() { echo -e "${RED}[godot-preview]${NC} $*" >&2; }
ok() { echo -e "${GREEN}[godot-preview]${NC} $*"; }

check_deps() {
    if ! command -v ffmpeg &>/dev/null; then
        err "ffmpeg not found. Install with: brew install ffmpeg"
        exit 1
    fi
    if [[ ! -x "$GODOT_BIN" ]] && ! command -v "$GODOT_BIN" &>/dev/null; then
        err "Godot not found at: $GODOT_BIN"
        err "Set GODOT_BIN or use --godot <path>"
        exit 1
    fi
}

# Extract scene name for default output filename
scene_basename() {
    local scene="$1"
    # res://scenes/jungle_lobby/lobby.tscn -> lobby
    basename "$scene" .tscn
}

cmd_capture() {
    local project_path=""
    local scene_path=""

    # Parse positional args
    if [[ $# -lt 2 ]]; then
        err "Usage: godot-preview capture <project_path> <scene_path> [options]"
        exit 1
    fi
    project_path="$1"; shift
    scene_path="$1"; shift

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--resolution) RESOLUTION="$2"; shift 2 ;;
            -f|--frame) FRAME="$2"; shift 2 ;;
            -s|--seconds) RENDER_SECONDS="$2"; shift 2 ;;
            --fps) FPS="$2"; shift 2 ;;
            -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
            -g|--godot) GODOT_BIN="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            *) err "Unknown option: $1"; exit 1 ;;
        esac
    done

    check_deps

    # Resolve project path
    project_path="$(cd "$project_path" && pwd)"
    if [[ ! -f "$project_path/project.godot" ]]; then
        err "No project.godot found in: $project_path"
        exit 1
    fi

    # Setup output
    mkdir -p "$OUTPUT_DIR"
    local scene_name
    scene_name="$(scene_basename "$scene_path")"
    local avi_path="$OUTPUT_DIR/${scene_name}_capture.avi"
    local log_path="$OUTPUT_DIR/${scene_name}_godot.log"

    # Default output file
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="$OUTPUT_DIR/${scene_name}.png"
    fi

    # Clean previous capture
    rm -f "$avi_path"

    log "Rendering ${scene_path} at ${RESOLUTION} for ${RENDER_SECONDS}s..."

    # Launch Godot with write-movie
    "$GODOT_BIN" \
        --path "$project_path" \
        --resolution "$RESOLUTION" \
        --windowed \
        --write-movie "$avi_path" \
        --fixed-fps "$FPS" \
        "$scene_path" \
        &>"$log_path" &
    local godot_pid=$!

    # Wait for render duration then kill
    sleep "$RENDER_SECONDS"
    kill "$godot_pid" 2>/dev/null || true
    wait "$godot_pid" 2>/dev/null || true
    sleep 1

    # Check if AVI was created
    if [[ ! -f "$avi_path" ]]; then
        err "Godot failed to produce output. Check log: $log_path"
        if $VERBOSE; then
            cat "$log_path"
        fi
        exit 1
    fi

    # Check for script errors in log
    local error_count
    error_count="$(grep -c "SCRIPT ERROR" "$log_path" 2>/dev/null || true)"
    error_count="${error_count:-0}"
    if [[ "$error_count" -gt 0 ]] 2>/dev/null; then
        warn "$error_count script error(s) detected — check $log_path"
    fi

    # Extract frame(s)
    IFS=',' read -ra FRAMES <<< "$FRAME"
    local extracted=0

    for frame_num in "${FRAMES[@]}"; do
        local out_path
        if [[ ${#FRAMES[@]} -gt 1 ]]; then
            out_path="${OUTPUT_FILE%.png}_f${frame_num}.png"
        else
            out_path="$OUTPUT_FILE"
        fi

        if ffmpeg -i "$avi_path" \
            -vf "select=eq(n\\,${frame_num})" \
            -vframes 1 -update 1 \
            "$out_path" -y \
            &>/dev/null; then
            ok "Frame ${frame_num} → ${out_path}"
            ((extracted++))
        else
            warn "Failed to extract frame ${frame_num}"
        fi
    done

    # Clean up AVI
    rm -f "$avi_path"

    if [[ $extracted -eq 0 ]]; then
        err "No frames extracted. The scene may not have rendered enough frames."
        err "Try increasing --seconds or lowering --frame number."
        exit 1
    fi

    # Print path for easy consumption by AI agents
    if [[ ${#FRAMES[@]} -eq 1 ]]; then
        echo "$OUTPUT_FILE"
    fi
}

cmd_list() {
    local project_path="${1:-.}"
    if [[ ! -f "$project_path/project.godot" ]]; then
        err "No project.godot in: $project_path"
        exit 1
    fi
    log "Scenes in $(basename "$project_path"):"
    find "$project_path" -name "*.tscn" -not -path "*/.godot/*" | sort | while read -r f; do
        local rel="${f#"$project_path"/}"
        echo "  res://$rel"
    done
}

# --- Main ---
case "${1:-help}" in
    capture) shift; cmd_capture "$@" ;;
    list) shift; cmd_list "$@" ;;
    help|-h|--help) usage ;;
    *) err "Unknown command: $1"; usage; exit 1 ;;
esac
