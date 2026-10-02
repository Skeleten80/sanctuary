# Media folder

Drop the church's audio files here (m4a, wav, or mp3) and reference them by
resource name in the `AudioTrack` seed data in
`Sources/SanctuaryCore/Store/BoothStore.swift`:

```swift
AudioTrack(name: "Preshow Loop", fileName: "preshow-loop", fileExtension: "m4a",
           volume: 0.7, shouldLoop: true)
```

Notes:
- `fileName` is the resource name WITHOUT the extension.
- Files are bundled via the `.process("Media")` resource rule in Package.swift
  and resolved with `Bundle.module` at load time.
- Tracks with no matching file load gracefully: the engine logs a message and
  the track's play button stays disabled until a file is added.
- Keep this folder's audio at 44.1 kHz / 48 kHz stereo to avoid
  sample-rate conversion surprises through the mixer's USB input.
