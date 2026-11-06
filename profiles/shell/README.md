# alpbahOS Terminal/Shell Profile — SHELL-01 (v2)

Status: **draft**. The files below were prepared as static files. The shell was tested in a chroot pty on 2026-11-05 (see the verification table). It has not been run in Konsole, and the Konsole profile has not been tested on a real desktop.

Scope: `profiles/shell/` only. The system shell `/bin/sh` is not changed. The interpreter used by build scripts is not affected by this profile (CLAUDE.md).

Sources: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §4, [docs/DECISIONS.md](../../docs/DECISIONS.md) D119 (terminal choice, technical choice delegated by the user) and D123 (apt hint).

## Approach

Ready-made components are configured. No new shell or completion engine is written:

- **Zsh** + the built-in `compinit` completion system
- **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)** — faint suggestions
- **[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)** — syntax colouring
- **Konsole** — colour scheme and profile file

Version and checksum verification of the source packages, and their addition to the LFS/BLFS chain, are done in the BLFS build chain (CLAUDE.md: "Do not build before the source is verified").

## Files

- [`zshrc.alpbah`](zshrc.alpbah) — interactive Zsh configuration. The target is to install it as `/etc/alpbahos/zshrc.alpbah` and have the user's `~/.zshrc` source it.
- [`konsole/alpbah-dark.colorscheme`](konsole/alpbah-dark.colorscheme) — generated from the same colour source as `profiles/desktop/tokens.json`.
- [`konsole/alpbahOS.profile`](konsole/alpbahOS.profile) — ties the font (JetBrains Mono) and cursor settings to the colour scheme.
- [`tests/test_apt_hint.py`](tests/test_apt_hint.py) — pytest checks for the foreign package-manager hint (see below).

## Suggestion accept/run split (MASTER_PLAN §4.1)

The **default** behaviour of `zsh-autosuggestions` already separates accepting from running: the right arrow or `End` accepts the suggestion into the line (it is written to the buffer) but does not run it. A separate `Enter` is needed to run the command. `zshrc.alpbah` does not override this behaviour. It only customises the suggestion colour (`--ab-text-muted`, a muted grey-blue) and the source strategy (`history` + `completion`). **This behaviour has not been verified in a real terminal.** Because it may differ between plugin versions, it must be tested at M08.

## Spelling correction (MASTER_PLAN §4.1)

`setopt CORRECT` is on and `CORRECT_ALL` is off. Only **command names** get correction suggestions. Arguments and file names are never rewritten silently (CLAUDE.md: "Spelling help never silently rewrites arguments or file names"). Zsh offers the correction with a `y/n/a/e` prompt, and the user can refuse it.

## Foreign package-manager hint (D123)

Typing a package-manager command from another distribution does **not** run it. The `command_not_found_handler` in `zshrc.alpbah` prints a Turkish hint with the matching `alp` command and returns exit status 127:

```text
$ apt install firefox
alpbahOS'ta 'apt' yok. Bunun yerine: alp install firefox
```

Mapping for the commands `apt`, `apt-get`, `dnf`, `yum`, `zypper` and `snap`:

| Typed subcommand | Hint |
|---|---|
| `install` | `alp install <args>` |
| `remove`, `purge`, `uninstall` | `alp remove <args>` |
| `update`, `upgrade`, `refresh` | `alp update` |
| `search` | `alp search <args>` |
| `show`, `info` | `alp info <args>` |
| anything else, or no subcommand | `alp help` |

A hint never runs a command by itself. Any other unknown command keeps zsh's normal behaviour, with a Turkish message: `zsh: komut bulunamadı: <cmd>` on stderr, exit status 127. `/bin/sh` is not affected.

Automated check: `python3 -B -m pytest profiles/shell/tests -q -p no:cacheprovider`. The test skips when zsh is not installed. It runs the real profile under a minimal PATH with a marker-writing fake `alp`, and asserts the hint text, exit code 127, and that the marker is absent (nothing was executed). Run on 2026-11-06 (this change): 15 passed.

## Ctrl+C / Ctrl+R

- `Ctrl+C`: Zsh's default SIGINT and job-interrupt behaviour is **not changed at all**. This is a deliberate choice. Mapping it to a Windows-like "copy" action is not accepted in the terminal (MASTER_PLAN §4.3 item 5, the `clipboard-ops` exception note in `shortcuts.json`).
- `Ctrl+R`: bound to history search (`history-incremental-search-backward`). A detailed or fuzzy view (for example fzf integration) is a separate open decision. This draft keeps to Zsh's built-in search.

## `alp` completion

Completion is written for the `alp` CLI (`alp.py`, the version in the rootfs). Subcommand names, and package names for `install/info/remove/upgrade/protect/unprotect`, are read from the local catalogue (`ALP_INDEX`, otherwise `/usr/share/alp/index.json`). No network or root access is needed. The package-manager logic of the store is not written yet.

## Acceptance criteria status

Current status (5 November 2026): [docs/verification/t3-zsh-chroot-2026-11-05.md](../../docs/verification/t3-zsh-chroot-2026-11-05.md). The table below matches that document. The tests were run in a chroot with a pty, not inside Konsole.

| MASTER_PLAN §4.3 item | Status |
|---|---|
| 1. On a clean user account, suggestions are visible and need no network | **Verified** in the chroot pty (not in Konsole) |
| 2. Accepting a suggestion does not run the command; Enter is needed | **Verified** in the chroot pty |
| 3. A wrong command correction is explained and can be refused | Prompt and refusal **verified** in the chroot pty |
| 4. Package-name completion causes no unnecessary root or network work while typing | **Verified** in the chroot pty: `alp inst<TAB>` → `install`, `alp install ht<TAB>` → `htop`; the local index is read and no install is triggered |
| 5. Ctrl+C interrupt behaviour is kept | **Verified** in the chroot pty |
| 6. The logo prints with the right colours in a real terminal | Reference `docs/assets/alpbahOS-neofetch-ansi.txt` exists; **real-terminal check not run** |
| D123. Foreign package-manager hint | **Automated test passes** (2026-11-06, pytest, fake PATH). Not yet checked in the chroot pty or Konsole |

## Integration note

The real verification can only be done after the BLFS terminal and session chain is installed. See [docs/handoffs/claude/001-desktop-bootstrap.md](../../docs/handoffs/claude/001-desktop-bootstrap.md).

## Changes in v2

- Document translated to English (D102).
- Terminal choice recorded as D119 (technical choice).
- Foreign package-manager hint added (D123) with its automated test.
- Verification status kept as in the 2026-11-05 record; no new real-terminal result is claimed.
