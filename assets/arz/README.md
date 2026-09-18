# Arz assets

## Inspection note

`Kiddotasks/Images/Boy_riding_rocket_in_space.mp4` is the **splash intro**, not the header Arz avatar.

| Asset | Role | Spec |
|---|---|---|
| `Boy_riding_rocket_in_space.mp4` | Full-screen splash | 720×1280 portrait, H.264+AAC, ~8s |
| `arz.mp4` | **Final** header Arz avatar (web + iOS) | 1280×720 landscape, H.264+AAC, ~10s, ~1.8MB |
| `Boy_animated_avatar_cycling_emotions.mp4` | Previous emotion loop (fallback) | 1280×720, H.264+AAC, ~10s, ~1.5MB |
| `kiddo_head_*.png` | Header Arz fallback stills | 512×512 @3x (≈171pt logical) |
| `/arz/head_*.png` (web) | Header Arz fallback stills | Same 512px sources |
| `/arz/arz.mp4` (web) | Final avatar loop | Copy of `Kiddotasks/Images/arz.mp4` |

There is no higher-resolution master for the splash clip in-repo. Do not upscale it and call it HD. Replace `master/` with a true 1080p/1440p export when available; UI already loads by filename.

## Layout

```
assets/arz/
  master/     # source of truth (not bundled)
  ios/        # @2x/@3x delivery
  web/        # public/arz copies
  poster/     # sharp stills for first paint
```

## Delivery rules

- Header avatar is compact: 48–72pt/px by size class — never a large video box.
- Prefer 512px stills for the head (far above 3× display needs at ≤72pt).
- Optional loop video can be added later as `public/arz/arz_loop.mp4` + poster; keep H.264/HEVC, preserve fps, `object-fit: contain`.
- Reduced motion → static poster / still frame only.
