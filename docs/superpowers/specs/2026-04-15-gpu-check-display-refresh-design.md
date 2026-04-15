# GPU Check Display Refresh Design

## Goal

Refresh `arch/bin/gpu-check` so its output feels much closer to `duf`: boxed layout, fixed-width busy progress bars, and terminal-aware colors that follow `duf`-like dark theme semantics.

## Scope

Update existing `arch/bin/gpu-check` output only. Keep AMD detection, sysfs reads, host support, and exit-code semantics unchanged.

Default behavior:
- Keep reading AMD GPU metadata from `/sys/class/drm/renderD*/device/uevent`
- Keep reading `gpu_busy_percent` and `mem_info_vram_used` from sysfs
- Keep exit codes `0`, `1`, and `2`
- Replace plain table with boxed Unicode report
- Add fixed-width busy bar for each GPU row
- Add auto-color on TTY, plain output otherwise

## Output Design

Presentation should clearly borrow from `duf`:
- Unicode box borders using `╭ ╮ ╰ ╯ ─ │ ├ ┤ ┬ ┴ ┼`
- Header row inside box
- One row per GPU with columns for device, role, busy bar, and VRAM
- Footer verdict line inside same box
- Compact enough for normal terminal widths

Example shape:

```text
╭──────────────────────────────────────────────────────────────────────╮
│ GPU Check                                                            │
├──────────────────────┬──────┬────────────────────┬──────────────────┤
│ DEVICE               │ ROLE │ BUSY               │ VRAM             │
├──────────────────────┼──────┼────────────────────┼──────────────────┤
│ Radeon RX 7700S      │ dGPU │ ██████████████ 74% │ 1.1 GiB          │
│ Radeon 890M          │ iGPU │ ▏              1%  │ 408 MiB          │
├──────────────────────┴──────┴────────────────────┴──────────────────┤
│ Verdict: dGPU active and dominant                                   │
╰──────────────────────────────────────────────────────────────────────╯
```

Exact spacing may vary, but output must keep same overall visual language.

## Color Design

Color should follow `duf`-style semantics as closely as practical in Bash:
- Enable colors only when stdout is a TTY
- Plain output when piped or redirected
- Busy bar color thresholds:
  - under `50%`: normal/green
  - `50%` through `89%`: warning/yellow
  - `90%` and above: danger/red
- Borders, headers, and labels should use restrained accent styling, not rainbow output
- Roles may have subtle accents, but busy bar remains primary visual signal

## Progress Bar Rules

- Use fixed-width Unicode progress bar
- Bar width should be stable across rows
- Percent must remain readable at a glance
- Bar should not change total layout width when usage changes
- In non-color mode, bar must still communicate load through fill amount alone

## Error Handling

- Keep current error behavior for missing sysfs root, missing AMD GPUs, and missing counters
- Error output may stay plain text; no need for boxed error screens
- `--help` remains short and plain

## Verification

- Add or update test coverage to assert boxed output markers and busy bar rendering
- Run test first and confirm failure before implementation
- Run script syntax check and `shellcheck`
- Run utility on live host and confirm:
  - boxed output renders correctly
  - busy bars reflect current busy percentages
  - colors appear on TTY only
  - exit code still matches verdict logic

## Out of Scope

- New command-line options for themes or styles
- ASCII style toggle
- Historical sampling
- Per-process GPU attribution
