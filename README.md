# pocket-tools

Four small, single-file shell tools that solve problems a Wayland laptop user actually has. No dependencies beyond
coreutils and what the tool is about; read each one in a minute before you trust it.

| tool | problem it solves |
|---|---|
| [`oom-trim`](bin/oom-trim) | the kernel OOM killer fires so late that the compositor has already stalled for half a minute. This watches `MemAvailable` and terminates your own biggest *recoverable* hog (browser, blender, electron) first, then the biggest unprotected process. Never touches the compositor, shells, session or audio. |
| [`chromium-sw`](bin/chromium-sw) | headless Chromium, forced onto the GPU by a test tool's `--enable-gpu` / `--use-angle=vulkan`, can hang the graphics ring and take the whole session down on a reset. This wrapper drops every GPU-forcing flag and appends SwiftShader software rendering. |
| [`offload`](bin/offload) | the laptop disk is small, other machines are not. `offload put` copies a path to the roomiest of your hosts, verifies it by checksum, and only then deletes the local copy; `get` brings it back; an index remembers where everything is. |
| [`askpass-zenity`](bin/askpass-zenity) | a graphical password prompt for `sudo -A` when there is no terminal. |

## Install

```sh
install -m755 bin/* ~/.local/bin/           # or symlink; make sure ~/.local/bin is on PATH
install -m644 systemd/user/oom-trim.service ~/.config/systemd/user/
systemctl --user enable --now oom-trim       # optional: run the guard in the background
```

## oom-trim

```sh
OOMTRIM_DRY_RUN=1 oom-trim        # log-only: see what it would have killed
tail -f ~/.local/state/oom-trim.log
```

Settings (environment or `~/.config/oom-trim.conf`, `KEY=VALUE` lines):

| variable | default | |
|---|---|---|
| `OOMTRIM_LOW_PCT` | `10` | act when `MemAvailable` falls below this % of `MemTotal` |
| `OOMTRIM_MIN_RSS_MB` | `200` | ignore processes smaller than this |
| `OOMTRIM_INTERVAL` | `3` | seconds between checks |
| `OOMTRIM_PRIORITY` | `brave chrome chromium firefox blender electron` | process-name prefixes, tried in order |
| `OOMTRIM_PROTECT_EXTRA` | | extra names that must never be signalled |
| `OOMTRIM_DRY_RUN` | `0` | log only |

It sends `SIGTERM`, waits two seconds, then `SIGKILL`s a survivor. It only ever signals processes owned by the user it
runs as, and the protect list covers common compositors, shells, terminals and the audio/session stack. Unsaved work
in the process it picks is lost: put the things you can't afford to lose on the protect list.

## chromium-sw

```sh
chromium-sw --headless --user-data-dir="$(mktemp -d)" --screenshot=out.png https://example.com
CHROMIUM_SW_DRY=1 chromium-sw --enable-gpu --use-angle=vulkan about:blank   # shows the sanitised command line
```

Point test runners at it (`CHROME=chromium-sw`, `PUPPETEER_EXECUTABLE_PATH=$(command -v chromium-sw)`, ...).
Always give headless runs a throwaway `--user-data-dir`, or Chromium may open and lock your real profile.

## offload

```sh
export OFFLOAD_HOSTS="nas1 nas2"        # ssh aliases with key login (or one per line in ~/.config/offload/hosts)
offload df                              # free space per host
offload put ~/Videos/render-2025 ~/Downloads/big.iso
offload ls
offload get ~/Videos/render-2025        # the remote copy stays
```

Only paths under `$HOME` are accepted. The local copy is removed only if a `rsync -c` checksum pass shows the remote copy
is identical. Needs `ssh`, `rsync`, `flock`, `numfmt`.

## Tests

```sh
tests/oom-trim-test.sh        # fake meminfo + a fake process; dry-run only
scripts/check-no-secrets.sh
```

Licence: MIT.
