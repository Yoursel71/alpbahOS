# Shortcut help for users — UI-02

Status (updated 2026-11-06): **design plan.** No help UI component (card, grouping, overlay) is built. The shortcut profile itself is installed and was checked in the QEMU test image on 5 Nov 2026: **19 pass, 1 out of scope** (`clipboard-ops`, an application-layer shortcut). The profile source is [`shortcuts.json`](shortcuts.json); the conflict analysis is in [conflicts.md](conflicts.md).

Purpose: connect the decision that alpbahOS uses Windows-familiar shortcuts (D118) to a concrete help and discovery surface. Sources: [docs/DECISIONS.md](../../docs/DECISIONS.md) D118 (replaces the v1 D08) and [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6.

## 1. First-session quick reference card

On first login, a dismissable notice or card lists the five most-used shortcuts: `Win+D`, `Win+E`, `Win+L`, `Alt+Tab`, `Win+I`. It appears once and is not shown again at each login. A permanent "show again" option is in Settings.

## 2. Permanent access

In System Settings → Shortcuts, a separate "For Windows users" filter or group label marks each row from `shortcuts.json`. No new settings page is written; the built-in Plasma Shortcuts module is used and only grouping and labels are added.

## 3. Reset

Each shortcut row must be reversible with the built-in "Reset to default" feature of System Settings → Shortcuts (MASTER_PLAN §6: "can be edited in settings and can return to the default"). No new reset mechanism is invented.

> M08 finding (Plasma 6.4.4 source): the built-in "Defaults" button returns an action to the **KDE** default declared by the application that registers it. The alpbahOS profile lives in the `/etc/xdg/kglobalshortcutsrc` layer. Returning to the alpbahOS profile requires deleting the related entry in the user's `~/.config/kglobalshortcutsrc`. This difference is an open decision in [conflicts.md](conflicts.md) §4.

## 4. Idea left out of scope

An overlay that shows shortcuts while the Meta key is held (present in some desktop environments) is only considered if the chosen Plasma version has it **ready-made**. No custom component is written for it (CLAUDE.md: customise ready-made components; do not invent a new compositor or shell part).

## Not verified / not tested

Every item in this document is a design-level plan. The notice, card and grouping mechanisms were not implemented or tested in any Plasma session.
