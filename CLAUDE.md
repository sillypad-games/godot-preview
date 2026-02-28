# godot-preview

Visual iteration tool for Godot 4 — lets Claude Code (and other AI agents) **see** rendered scenes without needing display access, screen recording permissions, or user screenshots.

## How It Works

1. Launches Godot with `--write-movie` to render frames to an AVI file
2. Extracts PNG frame(s) with ffmpeg
3. You read the PNG with Claude's `Read` tool to see the rendered result
4. Make changes, re-capture, repeat

## Quick Start

```bash
# Capture a scene at phone resolution (1080x1920 portrait)
./godot_preview.sh capture ./my_godot_project res://scenes/lobby.tscn

# Read the result (in Claude Code)
# Use the Read tool on /tmp/godot-preview/lobby.png

# Capture at custom resolution
./godot_preview.sh capture ./my_godot_project res://scenes/arena.tscn -r 1280x720

# Capture multiple frames (different camera angles over time)
./godot_preview.sh capture ./my_godot_project res://scenes/lobby.tscn -f 1,5,10

# List all scenes in a project
./godot_preview.sh list ./my_godot_project
```

## Visual Iteration Loop (for AI agents)

This is the workflow that makes this tool powerful:

```
1. Read .tscn and .gd files to understand the scene
2. Run: ./godot_preview.sh capture <project> <scene>
3. Read the output PNG — you can now SEE the rendered 3D scene
4. Identify issues (wrong camera angle, dark lighting, missing assets, etc.)
5. Edit the source files to fix issues
6. Go to step 2 and verify your fix
```

### Example: Fixing a dark lobby scene

```bash
# First capture — scene is too dark, sky is black
./godot_preview.sh capture ./godot_project res://scenes/lobby.tscn
# Read /tmp/godot-preview/lobby.png → see dark scene

# Fix: brighten sky in lighting.tscn, increase ambient light
# ... edit files ...

# Second capture — verify fix
./godot_preview.sh capture ./godot_project res://scenes/lobby.tscn
# Read /tmp/godot-preview/lobby.png → scene is brighter!
```

## Requirements

- **Godot 4.x** (tested with 4.4.1) — Metal/Vulkan rendering works, no display needed
- **ffmpeg** — for frame extraction (`brew install ffmpeg`)
- macOS, Linux, or any platform where Godot can render offscreen

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GODOT_BIN` | `/Applications/Godot.app/Contents/MacOS/Godot` | Path to Godot binary |

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `-r, --resolution` | `1080x1920` | Viewport resolution (WxH) |
| `-f, --frame` | `5` | Frame number(s) to extract (comma-separated) |
| `-s, --seconds` | `10` | How long to let Godot render |
| `--fps` | `1` | Render FPS (1 = one frame/second) |
| `-o, --output` | `/tmp/godot-preview/<scene>.png` | Output path |
| `-v, --verbose` | off | Show Godot log output |

## Tips

- **Frame 0** is often blank or loading — use frame 3-5 for a settled scene
- **Higher `--fps`** captures more frames per second (useful for animated scenes)
- **Longer `--seconds`** needed if the scene has an orbit camera or animations
- **Portrait resolution** (`1080x1920`) matches mobile games; use `1280x720` for landscape
- The tool **auto-detects script errors** in Godot's output and warns you
- Output PNGs land in `/tmp/godot-preview/` by default — easy to find and read

## Limitations

- Cannot interact with the scene (no clicking, no input events)
- Camera position is whatever the scene's default camera shows
- Scenes that need server connections will show disconnected state
- Write-movie mode runs at the specified fixed FPS, not real-time
