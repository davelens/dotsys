# dotsys

This repo contains my personalized bootstrap installers for setting up macOS, Arch Linux, Void Linux, or WSL for my (web) development work.

As such, they work in tandem with [my dotfiles](https://github.com/davelens/dotfiles). If you're looking for tool configurations, you should look in there instead.

## Staged provisioning

Run the platform's `init.sh` as the intended user, never through sudo. For example,
from a **stable** checkout (not an implementation/test worktree):

```bash
bash arch/init.sh --dotfiles-root /absolute/dotfiles --select sway --save
```

The platform entrypoints delegate to `shared/install.sh`: bootstrap packages and
sources → dotfiles prerequisites/configuration → declared mise runtimes, GnuPG,
external tools, complete helper registration and service preparation → readiness
→ selected activation. Failure stops dependent stages without rollback. Native
macOS bootstrap does not require an existing Bash 5 or dotfiles shell.

Use `--select ''` for core only; choices are transient unless `--save` is supplied.
Saved choices are resolved by dotfiles. `--wezterm-destination PATH` is forwarded
unchanged; no supplied/saved destination means no Windows-host copy. See
`bash shared/install.sh --help` for explicit HOME/user/XDG and checkout paths,
configuration adoption/replacement, and separate `--helper-adopt`/`--helper-replace`.
Default sources are the public davelens dotfiles/dotvim/dotshell repositories;
existing destinations must match their origins. Acquisition never pulls/resets an
existing checkout. Tool entrypoints use the shared ownership engine, not legacy
installers that download fonts/npm packages or activate services.

### Legacy setup delegates

- `bash shared/install.sh setup --dotsys arch` (also `void`, `macos`, `wsl`): full
  portability handoff. `setup --arch` / `setup --void` default to Sway only when
  neither an explicit choice nor an existing `dots/env` file is present.
- `bash shared/install.sh setup --dotvim` / `--dotshell`: acquire/register only
  the requested tools on a prepared machine, without package installs, dotfiles
  installation or service activation. They may be combined. Supply
  `--dotfiles-root`, `--dotvim-root`, `--dotshell-root` as needed; `--platform`
  supplies provider context. Missing Bash 5, Git, Python, Neovim/Quickshell or the
  dotfiles ownership engine requires explicit preparation first.
- `bash shared/install.sh setup --dotfiles`: configuration installation only.
- `shared/brew/init.sh [--skip-bundles] [--no-confirm]` preserves the Brew delegate
  options. `shared/cargo/init.sh` and authenticated `shared/gh/init.sh` are explicit
  operations; their old `arch/packages/` paths delegate here.

`--full-machine` additionally composes the previous broad platform workflow after
readiness and before final selected activation: Arch hardware/network extras,
Void repository/package lists, or macOS/WSL personal Brew bundles and Cargo tools.
These are not hidden prerequisites of the limited handoff. GitHub extensions
require separate prior authentication and are never bootstrapped automatically.

Helper-only registration and configuration deselection preserve previously
registered software entrypoints. Service scripts expose `--packages`, `--prepare`
and `--activate`; preparation writes unmonitored definitions only. Their legacy
no-argument operation remains an explicit combined provisioning/activation route,
not a readiness-gated installer. Changed staged definitions need explicit manual
reconciliation; service deployment does not promise configuration-engine backups.

### Rejected candidate runtimes

```bash
bash /absolute/dotsys/shared/mise/init.sh --config /absolute/retained-candidate/config/mise/config.toml
```

This installs only the declared runtimes (simple string `x.y.z` pins or `latest`).
It disables config discovery/env/hooks, does not trust/link the candidate, change
saved selections, advance sources, or activate services. Runtime downloads and
mise installation/cache state are expected changes. Retry the checked update
separately; preparation itself does not accept the candidate.

## Void Linux

The minimal bootable system installation lives in [dotvoid](https://github.com/davelens/dotvoid).
After booting that system, use `bash void/init.sh --select sway --save`; add
`--full-machine` for the previous broad machine workflow. The selected desktop
uses elogind-backed sessions and turnstile-managed user runit services. No user
or system runit registration occurs during preparation. VT1 takeover is the last
activation step, after readiness and any explicitly requested machine extras.

## ntfy

Run `arch/init.d/ntfy.sh` to start the Dockerized ntfy server and publish it through Tailscale Serve. The container setup lives in `shared/ntfy/`; only the service-manager adapter is Arch-specific so a Void/runit adapter can reuse it later.

## Local LLM setup

Arch local LLM provisioning lives in `arch/init.d/llama-cpp.sh`.
It installs a system `llama.cpp` build plus the `gemma-4-26B-A4B-it` GGUF model,
then exposes an OpenAI-compatible API on `127.0.0.1:11434`.

> [!WARNING]
> The staged portability handoff has controlled fixture coverage only. Real macOS,
> Arch, Void and Windows-host WSL acceptance remains pending; obtain explicit
> deployment approval and use stable installation roots before real provisioning.
