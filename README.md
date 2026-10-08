<div align="center">

# Angra iOS Streaming

Open-source mobile game/screen broadcaster for iOS — stream your iPhone/iPad to YouTube, Twitch, Kick, Facebook or any custom RTMP, using a ReplayKit broadcast extension. No watermark, free, open source.

[![Download latest IPA](https://img.shields.io/badge/Download-Latest%20IPA-brightgreen?style=for-the-badge&logo=apple)](../../releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

**[⬇ Download the latest version](../../releases/latest)** · **[All versions & changelogs](../../releases)**

</div>

## Download

The green **Download** button always points at the newest release and refreshes automatically — publish a new version and it serves that build. The [Releases page](../../releases) lists every version with its description and changelog. The `.ipa` is **unsigned** — your sideloader (iLoader / Sideloadly / AltStore) re-signs it with your own Apple ID at install.

Direct latest IPA: `https://github.com/HARSHBHINDER/Angra-iOS-Streaming/releases/latest/download/Angra-iOS-Streaming.ipa`

## Install (sideload)

1. Download `Angra-iOS-Streaming.ipa` from the latest release.
2. Open it in **iLoader / Sideloadly / AltStore** on your computer, connect your iPhone.
3. Sign in with your Apple ID so the tool signs the app, then install.

Free Apple IDs re-sign every 7 days; a paid developer account lasts a year.

## Features

| | |
|---|---|
| **Destinations** | Multiple channels: YouTube, Twitch, Kick, Facebook, custom RTMP/RTMPS. |
| **Per-channel encoding** | Resolution, 30/60 fps, orientation, H.264/HEVC, keyframe, video bitrate (CBR, 100-kbps steps), audio bitrate, sample rate, stereo, stream delay. |
| **Capture** | ReplayKit screen broadcast with mic + app audio; audio-source selection. |
| **Recording** | Record while streaming. |

The OS red recording indicator stays on whenever broadcasting — by Apple design. Facecam and the floating bubble are Android-only (iOS has no cross-app overlay and the broadcast extension can't run the camera under its memory limit).

## Build

Needs macOS + Xcode 26 + `brew install xcodegen`.

```bash
xcodegen generate
xcodebuild build -project "Angra iOS Streaming.xcodeproj" -scheme LivePipe \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Real-device builds need the `group.dev.livepipe` app group on both targets (app + broadcast extension).

## Releasing on GitHub

Every push to `main` publishes release `v<MARKETING_VERSION>` (from `project.yml`) with the unsigned `.ipa`, if that version isn't released yet. To ship a new version: bump `MARKETING_VERSION`, commit, **Push origin** in GitHub Desktop. No tags needed.

No secrets needed: the `.ipa` is unsigned on purpose and signed at sideload time.

## License

MIT — free for anyone. See [LICENSE](LICENSE).
