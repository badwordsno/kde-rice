# Readability regression baselines

These MIT-licensed excerpts were copied from this repository's own Workspaces
and Resource Usage `contents/ui/main.qml` files before the 2026-09-13
readability changes. They contain no live user settings or third-party code.

`tests/test-panel-readability.py` loads these fixed baseline excerpts and extracts
the corresponding current source blocks. Both run in a temporary HOME with
the same BlackMinimal palette and synthetic input. This reproduces the original
selected-text contrast, masked hover/pressed feedback, CPU-only width estimate,
and ordinary-space padding alongside the corrected behavior.

The test exercises QML fragments, not a live Plasmoid, full panel layout, or
actual keyboard events. A full-session visual check remains separate.
