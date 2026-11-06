# Atatürk theme — asset plan (UI-03, D114)

Status (updated 2026-11-06):

- **D114 (accepted by the user):** the Atatürk theme is a **selectable theme** (Welcome app and System Settings). The **default** wallpaper and lock screen use the **alpbahOS brand**. The alpbahOS default wallpaper is not produced in this repo yet.
- **Source and wallpaper package (22 and 26 Sep 2026):** source image selected and added; wallpaper package built (see below). Not shown in a real Plasma session at that time.
- **QEMU check (5 Nov 2026):** `plasma-apply-wallpaperimage` on the 1920x1080 image reported success (functional check). No visual evidence was captured: the QEMU `screendump` did not write the GL display to a file. See [vm-session-2-2026-11-05.md](../../docs/verification/vm-session-2-2026-11-05.md).

## Source

- File: [`source/Ataturk1930s.jpg`](source/Ataturk1930s.jpg)
- Source: [Wikimedia Commons — Ataturk1930s.jpg](https://commons.wikimedia.org/wiki/File:Ataturk1930s.jpg) (original source mustafakemalim.com, dated 29 March 1932)
- Licence: **PD-Turkey** — copyright term under Turkish law has expired; public domain. See the licence tag on the Commons page.
- Resolution: 732×987 px
- SHA-256: `f1dad1a903de0d8930b44020fc77e4aea647ddd3cb21d110d447f1fe63694bbf`
- Download approval: given by the user in chat ("evet indir", 22 Sep 2026).

**Alternatives considered and not used:**

- ATAM's higher-resolution portraits (806×1024 and 845×1024) carry an "All rights reserved" notice, so they are copyrighted, not public domain. Not used.
- AI-generated portraits were considered and rejected. A fabricated depiction of a real founding figure is not acceptable, and in Turkey Atatürk's image is a sensitive area under Law No. 5816 (Atatürk'ü Koruma Kanunu).

## 1. Requirements (D09 and D114, MASTER_PLAN §7.1)

- The Atatürk theme is selectable. The default desktop and lock screen use the alpbahOS brand (D114).
- Use a source with a known licence; record the usage and licence information.
- Add no invented signature or quote to the image.
- In 16:9, 16:10 and ultrawide crops, the face, logo and text stay inside a safe area.
- The lock screen password field and username stay readable.
- Leave a low-detail area for desktop icons.

## 2. Source candidates (not downloaded, record only)

Found by web search. **None of these except the chosen source was downloaded or added to the repo.** Choosing a final source and downloading it requires the user's approval.

| Candidate | Source | Licence / status | Resolution | Note |
|---|---|---|---|---|
| [Mustafa Kemal Ataturk – golden portrait](https://commons.wikimedia.org/wiki/File:Mustafa_Kemal_Ataturk_-_golden_portrait.png) | Wikimedia Commons | Public Domain Mark 1.0 | 210×275 px | **Very low resolution.** Cannot be used directly for 1080p or 4K. |
| [Ataturk1930s.jpg (1932)](https://commons.wikimedia.org/wiki/File:Ataturk1930s.jpg) | Wikimedia Commons, source mustafakemalim.com | PD-Turkey | 732×987 px | Low to medium resolution. Usable as a portrait element, not full screen. **Chosen source.** |
| [Mustafa Kemal Atatürk 1921](https://commons.wikimedia.org/wiki/File:Mustafa_Kemal_Atat%C3%BCrk_1921.jpg) | Wikimedia Commons | **CC BY-SA 4.0** (not public domain: attribution and share-alike apply) | Not verified | Different licence terms; attribution is required if used. |
| [Mustafa Kemal Ataturk.png (Jean Weinberg, 1927)](https://commons.wikimedia.org/wiki/File:Mustafa_Kemal_Ataturk.png) | Wikimedia Commons | Not verified (page not read) | Not verified | Resolution and licence not checked. |
| ATAM portrait gallery | [atam.gov.tr/galeri/ataturk-portreleri](https://atam.gov.tr/galeri/ataturk-portreleri/) | Not verified; official institution, probably higher resolution | Not verified | Most promising candidate. Each image needs its own usage check. |
| TCCB photo archive | [tccb.gov.tr/ata_ozel/fotograf](https://www.tccb.gov.tr/ata_ozel/fotograf/) | Not verified | Not verified | Official source; check usage terms per page. |
| TTK photo collection | [ttk.gov.tr/ataturk-fotograflari-koleksiyonu](https://ttk.gov.tr/ataturk-fotograflari-koleksiyonu/) | Not verified | Not verified | Official source; check usage terms per page. |

### 2.1 Technical warning

The public-domain candidates that are easy to find on Wikimedia Commons (**210×275** and **732×987**) are too small for a modern 1920×1080 or 4K wallpaper. Enlarging them makes them blurry. Two realistic options:

1. **A higher-resolution scan from an official archive** (ATAM, TCCB or TTK), with the usage terms checked for each image.
2. **A stylised or vector version**: redraw the low-resolution source as line art or a silhouette in the style of the alpbahOS logo ("terminal + mountain silhouette"). This removes the resolution problem, but the illustration is a separate work item.

The choice is left to the user. This document only records the options and constraints.

## 3. Crop and safe-area plan (16:9, 16:10, ultrawide)

| Ratio | Example target | Rule |
|---|---|---|
| 16:9 | 1920×1080 | The portrait can shift horizontally from centre to avoid the logo area. Keep the bottom 15% low-detail for the taskbar (D115). |
| 16:10 | 1920×1200 | Add 120 px of safe margin at top and bottom compared with 16:9. The face position does not change. |
| Ultrawide (21:9) | 3440×1440 | Centre the portrait horizontally. Extend low-detail or gradient areas to the left and right. The face never touches an edge. |

General rule: the face and logo keep a clear margin (at least 0.25× the symbol height, from the logo protection rule in [alpbahOS-design-mockups.md](../../docs/alpbahOS-design-mockups.md) §2.3) and never run off the frame or touch an edge in any crop.

**Note on the layout change (D115):** the generator (`tools/build_wallpaper.py`) still reserves a 36 px band at the top, which came from the top panel in the dropped mockup, and a bottom 15% band for the old dock. Both values are from the old layout. Changing them is outside this folder's current work; the next wallpaper build should use the Windows-style bottom taskbar values.

## 4. Lock screen readability

> Status: the lock screen takes its wallpaper from the look-and-feel package; no separate lock-screen configuration exists. The translucent readability panel below needs a custom lock-screen QML. KScreenLocker is not built yet (D133 brings it back; SCREENLOCK-01). So the panel was not written or tested.

- A semi-transparent panel in `--ab-bg-950` sits behind the password field and username, so readability does not depend on the portrait contrast. Suggested value `rgba(11,16,20,0.55)` (not measured).
- Text colour `--ab-text-strong` (`#f4f8fb`). WCAG AA contrast target: planned, not measured.
- Error message colour `--ab-danger` (`#ff6575`), consistent with mockup §10.

## 5. Desktop icon area

Following the mockup §5.1 rule, leave a low-detail, low-contrast area in the top-left corner for icons such as Home, Trash and Documents. The portrait's face must not overlap that corner.

## 6. Logo use

If the alpbahOS logo is added to a wallpaper (mockup §5.1: "the logo can be used large but low-contrast on the wallpaper"), the logo rules apply unchanged: clear-space rule (§2.3) and prohibited uses (§2.4). Do not overlap the logo with the Atatürk portrait, and do not add a shadow to the logo.

## 7. Open items

1. ~~No final source chosen~~ — `Ataturk1930s.jpg` was chosen on 22 Sep 2026 with the user's approval. On 26 Sep 2026 a wallpaper was built from it (section below).
2. The full usage terms of the ATAM, TCCB and TTK pages were not read.
3. Whether the boot screen uses the theme is not decided. MASTER_PLAN §7.1 lists it as not yet requested. This document does not cover the boot screen.
4. The stylised or vector alternative exists as an idea only; nothing was produced.
5. The default alpbahOS brand wallpaper and lock screen (D114) are not designed or produced yet.
6. The top-band value (36 px) and bottom band (15%) in the wallpaper generator are from the old layout (see section 3).

## Wallpaper package (26 Sep 2026)

- Package: [`wallpaper/alpbahOS-Ataturk/`](wallpaper/alpbahOS-Ataturk/ATTRIBUTION.md). Generator: [`tools/build_wallpaper.py`](tools/build_wallpaper.py).
- The resolution limit was handled without enlarging the portrait. At 1080p the portrait is scaled to about 99%; at 1440p it is at 100%. It is placed on a dark navy background with a geometric mountain silhouette. The gap is filled with the background, not with an enlarged photo.
- The photo is not cropped. No text, signature or quote is added.
- Sizes produced: 1366x768, 1920x1080, 1920x1200, 2560x1440, 3440x1440, plus a 400x250 preview.
- The generator checks in every size that the face box stays clear of the top band (36 px), the bottom band (15%) and the top-left icon area (25% of the width). The build stops if the check fails.
- **Open:** at 4K (3840x2160) and above, the portrait fills only a small part of the screen. A stylised or vector version (section 2.1, option 2), or a higher-resolution source with a clear licence, can still be considered.
- Not checked: the wallpaper was not shown in a real Plasma session in 2026; scaling at 100%, 125%, 150% and 200% was not checked. The 5 Nov 2026 QEMU run was functional only (section status above).
