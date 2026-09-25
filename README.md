# godot-preview

Capture screenshots from Godot 4 scenes without a display. Built for AI-assisted visual iteration with [Claude Code](https://claude.ai/code).

## The Problem

When an AI agent modifies Godot scenes (.tscn) and scripts (.gd), it can't see the result. The human has to run the game, take screenshots, and describe what's wrong. This creates a slow feedback loop.

## The Solution

`godot-preview` uses Godot's `--write-movie` mode to render frames offscreen, then extracts PNGs with ffmpeg. The AI agent can read these PNGs directly and iterate on visual issues autonomously.

```bash
# AI agent captures a scene
./godot_preview.sh capture ./my_game res://scenes/lobby.tscn

# AI agent reads the PNG to see the rendered result
# → "I can see the terrain edges are visible and the sky is black"
# → fixes camera position and sky color
# → re-captures to verify
```

## Install

```bash
git clone https://github.com/sillypad-games/godot-preview.git
cd godot-preview
chmod +x godot_preview.sh

# Requirements
brew install ffmpeg  # or apt-get install ffmpeg
# Godot 4.x must be installed
```

## Usage

```bash
# Capture scene at mobile resolution
./godot_preview.sh capture ./project res://scenes/level.tscn

# Custom resolution + specific frame
./godot_preview.sh capture ./project res://scenes/level.tscn -r 1280x720 -f 8

# Multiple frames for different camera angles
./godot_preview.sh capture ./project res://scenes/level.tscn -f 1,5,10

# List all scenes
./godot_preview.sh list ./project
```

See [CLAUDE.md](CLAUDE.md) for the full AI agent workflow guide.

## How It Works

1. Launches Godot with `--write-movie` flag (renders to AVI at fixed FPS)
2. Lets the scene render for N seconds (default: 10)
3. Kills Godot and extracts frame(s) as PNG with ffmpeg
4. Cleans up the AVI, leaving only the PNG(s)

No display, no screen recording permissions, no GPU window required. Godot's Metal/Vulkan renderer works in this mode on macOS.

## License

MIT
