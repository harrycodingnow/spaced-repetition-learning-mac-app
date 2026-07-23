# Spaced Repetition Learning for macOS

A native SwiftUI companion for the `srl` CLI. Hover over the MacBook notch to open a compact study dashboard; move away and it morphs back into the notch.

## Features

- Transparent notch-sized hover target with an animated Dynamic Island interface.
- Log a completed question and rate it from 1–5.
- Separate queues for reviews due today and new NeetCode 150 questions.
- Weekly activity, future review calendar, and ordered NeetCode 150 route.
- Shared `~/.srl` data with the Python CLI.

A rating of `n` schedules the next review in `n` days. Two consecutive ratings of 5 mark a question as mastered.

## Build the macOS app

Requires macOS 13+ and Swift 6+.

```bash
git clone https://github.com/harrycodingnow/spaced-repetition-learning-mac-app.git
cd spaced-repetition-learning-mac-app
./macos/SRLMenuBar/scripts/build-app.sh
open "macos/SRLMenuBar/dist/SRL Menu Bar.app"
```

The local build is ad-hoc signed and reads the existing `~/.srl` directory.

## CLI quick start

Requires Python 3.10+.

```bash
uv pip install -e .
srl nextup add -f starter_data/neetcode_150.csv
srl list
srl add 3
```

## Test

```bash
swift test --package-path macos/SRLMenuBar
pytest
```

More macOS development details are in [macos/SRLMenuBar/README.md](macos/SRLMenuBar/README.md).

## Credits

Forked from [HayesBarber/spaced-repetition-learning](https://github.com/HayesBarber/spaced-repetition-learning). Released under the [MIT License](LICENSE).
