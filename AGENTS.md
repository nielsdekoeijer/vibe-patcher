# Agent notes

Build the apps with `zig build`, then start the GUI with:

```sh
./zig-out/bin/patcher
```

Control the running app through UDP IPC with `./zig-out/bin/patcher-ctl`. Run
`./zig-out/bin/patcher-ctl help` for the complete command list. Common commands:

```sh
./zig-out/bin/patcher-ctl mouse-move 300 200 0 0
./zig-out/bin/patcher-ctl mouse-press 300 200 right down
./zig-out/bin/patcher-ctl mouse-move 350 225 50 25
./zig-out/bin/patcher-ctl mouse-press 350 225 right up
./zig-out/bin/patcher-ctl quit
```

Every command prints its response as ZON. Capture the current window with:

```sh
./zig-out/bin/patcher-ctl screenshot /tmp/vibe-patcher-screenshot.bmp
```

The response contains the path `/tmp/vibe-patcher-screenshot.bmp`. If an image
viewer does not support BMP, make a PNG preview with Firefox and inspect that:

```sh
mkdir -p /tmp/vibe-patcher-firefox-profile
firefox --headless --profile /tmp/vibe-patcher-firefox-profile \
  --screenshot /tmp/vibe-patcher-screenshot.png \
  file:///tmp/vibe-patcher-screenshot.bmp
```

Run `zig build test` after changing the IPC protocol or event forwarding.
