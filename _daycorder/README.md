# Daychorder Telemetry Surface v0

Minimal 1920x1080 telemetry membrane for OBS Browser Source.

## Test locally

From the parent directory:

```bash
cd daychorder-telemetry
python3 -m http.server 8765
```

Open:

http://127.0.0.1:8765/

## OBS

Add a Browser Source:

- URL: `http://127.0.0.1:8765/`
- Width: `1920`
- Height: `1080`
- FPS: `1` is enough for this v0 telemetry-only surface; raise later if the surface gains animation.
- Shutdown source when not visible: optional for v0.

Put the Browser Source above the capture source in the OBS scene.

## Configuration

- `config/style.json`: canvas, border, colors, typography.
- `config/telemetry.json`: variable registry and update rate.
- `config/header.json`: header variable placement.
- `config/footer.json`: footer variable placement.
- `config/lhc.json`, `config/rhc.json`: reserved stubs.
- `config/index.json`: surface-level identity/region enablement.

Modify HTML/CSS/JS only when changing behavior or rendering logic.
