# dotsys

This repo contains my personalized bootstrap installers for setting up macOS, Arch Linux, Void Linux, or WSL for my (web) development work.

As such, they work in tandem with [my dotfiles](https://github.com/davelens/dotfiles). If you're looking for tool configurations, you should look in there instead.

## Void Linux

The minimal bootable system installation lives in [dotvoid](https://github.com/davelens/dotvoid). 
After booting that system, run `void/init.sh` as the desktop user. It updates
the system, enables the required repositories, installs the package lists in
`void/packages/`, and configures Sway with elogind-backed desktop sessions and
turnstile-managed user runit services. Services that need graphical-session
identity are launched by Sway while runit supervises their process lifetime.

## Local LLM setup

Arch local LLM provisioning lives in `arch/init.d/llama-cpp.sh`.
It installs a system `llama.cpp` build plus the `gemma-4-26B-A4B-it` GGUF model,
then exposes an OpenAI-compatible API on `127.0.0.1:11434`.

> [!WARNING]
> All installers are actively used and tested on their respective environments in my care. That said, take the necessary precautions prior to fiddling around with these scripts.
