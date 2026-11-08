#!/bin/bash
# REBUILD-R4 driver (run as root). Builds the BLFS packages of scripts/rebuild/r4/packages.tsv in plan
# order inside scratch-lfs-bench/r4-root, a btrfs copy of r3-root. One package at a time:
#   1. source: copied from blfs-plan/blfs-src into r4-root/sources/blfs-src. Its md5 must equal the md5 on
#      the BLFS page (packages.tsv). No upstream sha256 is in the repo, so the sha256 is recorded as TOFU.
#   2. script: the BLFS generator of the test image (blfs-plan/gen_blfs_chroot.py) writes the build script.
#   3. build: chroot run of that script. The BLFS commands run `make install` straight into the root,
#      so there is no DESTDIR (fallback method, see docs/verification/rebuild-r4-2026-11-07.md).
#   4. record: read-only snapshots before and after the build, `r3_ledger.py diff`, manifest of the
#      added or changed files (r4_lib.py manifest).
#   5. alp: `alp adopt-base` on r4-root with that manifest, the package name and the sha256 above.
#   6. ISA audit: audit-isa.sh on the new ELF files of the package (default exit code).
#   7. one line in scratch-lfs-bench/r4-status.txt.
# The batch stops at the first FAILED package and writes r4-ledger/FAILED; a finished batch writes
# r4-ledger/DONE. Packages without a local source are SKIP lines.
# Usage: sudo R4_FIRST=001 R4_LAST=030 nohup setsid bash run-r4.sh > <logdir>/driver.out 2>&1 &
set -u
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
DATE=2026-11-07
R4=$SB/r4-root
R3=$SB/r3-root
PLAN=$WT/scripts/rebuild/r4/packages.tsv
LIB=$WT/scripts/rebuild/r4/r4_lib.py
ALP=$WT/docs/handoffs/claude/alp-prototype/alp.py
R3L=$WT/scripts/rebuild/r3/r3_ledger.py
AUDIT=$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh
BLFS=$SB/blfs-plan
LEDGER=$SB/r4-ledger
SNAPS=$SB/r4-snapshots
STATUS=$SB/r4-status.txt
FIRST=${R4_FIRST:-001}
LAST=${R4_LAST:-030}
JOBS=${R4_JOBS:-8}
SRC13=$SB/blfs-src-13.1
DELTAS=$WT/scripts/rebuild/r4/deltas

mkdir -p "$LEDGER/logs" "$LEDGER/diff" "$LEDGER/manifests" "$LEDGER/adopt" "$LEDGER/audit" "$SNAPS" "$SRC13"
rm -f "$LEDGER/DONE" "$LEDGER/FAILED"
say() { echo "$(date '+%F %T') $*" >> "$STATUS"; }

# etc/resolv.conf is a link into /run/systemd/resolve, so that directory is bound too: without it the
# network steps (make-ca -g fetches certdata.txt) cannot resolve names inside the chroot.
kernfs_up() {
  for m in dev dev/pts proc sys run/systemd/resolve; do mkdir -p "$R4/$m"; done
  mount --bind /dev "$R4/dev" && mount --bind /dev/pts "$R4/dev/pts" \
    && mount -t proc proc "$R4/proc" && mount --bind /sys "$R4/sys" \
    && mount --bind /run/systemd/resolve "$R4/run/systemd/resolve"
}

kernfs_down() {
  for m in run/systemd/resolve sys proc dev/pts dev; do
    mountpoint -q "$R4/$m" && umount "$R4/$m"
  done
}

preflight() {
  if [ ! -d "$R4/etc" ]; then
    btrfs subvolume snapshot "$R3" "$R4" > /dev/null || { say "FATAL cannot snapshot r3-root"; exit 1; }
    say "r4-root created as a writable btrfs snapshot of r3-root (TEMP-01 not applied: perl files still in use)"
  fi
  if findmnt -rn -o TARGET | grep -qE "^$R4(/|\$)"; then
    say "FATAL something is mounted under r4-root"; exit 1
  fi
  mkdir -p "$R4/sources/blfs-src"
}

# One package. Returns 0 for OK or SKIP, 1 for FAIL (the batch stops).
build_one() {
  local nn=$1 row nv tb md5 localsrc url old_nv old_tb name ver src got sha start pre post rc elfs n arc summary man
  # Resume: a package with an OK line in the status file is already built and recorded in r4-root.
  if grep -q " OK $nn " "$STATUS" 2>/dev/null; then return 0; fi
  # Deferred: scripts/rebuild/r4/deltas/NNN.defer names the reason (a dependency that comes later in the list).
  if [ -f "$DELTAS/$nn.defer" ]; then say "DEFER $nn: $(head -1 "$DELTAS/$nn.defer")"; return 0; fi
  row=$(python3 "$LIB" row --plan "$PLAN" --nn "$nn") || { say "FAIL $nn no plan row"; return 1; }
  IFS=$'\t' read -r nv tb md5 localsrc _ url old_nv old_tb <<< "$row"
  for v in tb md5 localsrc url old_nv old_tb; do [ "${!v}" = - ] && printf -v "$v" ''; done
  if [ "$localsrc" != yes ] || [ -z "$tb" ]; then
    say "SKIP $nn $nv no local source (packages.tsv local_source=$localsrc)"; return 0
  fi
  read -r name ver <<< "$(python3 "$LIB" split "$nv")"
  # A second build of the same package (freetype pass 2, 050) gets its own alp name: alp keeps one record
  # per name. scripts/rebuild/r4/deltas/NNN.name holds the name.
  if [ -f "$DELTAS/$nn.name" ]; then name=$(cat "$DELTAS/$nn.name"); fi
  src="$SRC13/$tb"
  start=$(date +%s)

  # Source: the BLFS 13.1 URL, cached in SRC13. The book's md5 is the check (no upstream sha256 here).
  if [ ! -s "$src" ]; then
    curl -fL --retry 5 --retry-all-errors -sS -o "$src.part" "$url" && mv "$src.part" "$src" \
      || { rm -f "$src.part"; say "FAIL $nn $nv download $url"; return 1; }
  fi
  got=$(python3 "$LIB" md5 "$src" "$md5") || { say "FAIL $nn $nv source md5 $got, book $md5"; return 1; }
  sha=$(sha256sum "$src" | cut -d' ' -f1)
  cp --reflink=auto "$src" "$R4/sources/blfs-src/$tb"

  # Generator: the 12.4 build commands (same generator as the test image). Then the 12.4 version
  # strings are replaced by the 13.1 ones (tarball name first, then the directory name). The
  # per-package deltas beyond the version strings are not made here: a failing build shows them.
  if ! runuser -u yrslf -- python3 "$BLFS/gen_blfs_chroot.py" "$nn" > /dev/null 2>&1; then
    # Rows appended after 344 have no generator entry. A whole-script replacement (NNN.replace.sh) needs none:
    # a placeholder stands in, and the replacement is copied over it below.
    [ -f "$DELTAS/$nn.replace.sh" ] || { say "FAIL $nn $nv generator"; return 1; }
    printf 'true\n' > "$BLFS/gen_blfs/$nn.sh"
  fi
  # The export runs after the login profile, which leaves LANG/LC_CTYPE at tr_TR.UTF-8 (the base
  # locale.conf) even when LC_ALL=C is passed to chroot. The script sets C itself.
  { echo 'export LANG=C LC_ALL=C'; cat "$BLFS/gen_blfs/$nn.sh"; } > "$LEDGER/gen-$nn.12.sh"
  # Extra version strings of the 13.1 page (scripts/rebuild/r4/deltas/NNN.subst): "OLD<TAB>NEW" lines.
  extra=()
  if [ -f "$DELTAS/$nn.subst" ]; then
    while IFS=$'\t' read -r o n; do [ -n "$o" ] && extra+=(--pair "$o" "$n"); done < "$DELTAS/$nn.subst"
  fi
  python3 "$LIB" subst --in "$LEDGER/gen-$nn.12.sh" --out "$LEDGER/gen-$nn.13.sh" \
    --pair "$old_tb" "$tb" --pair "$old_nv" "$nv" "${extra[@]}" || return 1
  # Per-package deltas from the 13.1 page (scripts/rebuild/r4/deltas/NNN.pre.sh): inserted before the
  # first configure/meson/cmake line. A delta with no insertion point fails the package.
  if [ -f "$DELTAS/$nn.pre.sh" ]; then
    python3 "$LIB" insert --in "$LEDGER/gen-$nn.13.sh" --out "$LEDGER/gen-$nn.13d.sh" \
      --before '^(\./configure|meson |cmake |\./Configure)' --file "$DELTAS/$nn.pre.sh" \
      || { say "FAIL $nn $nv delta insert"; return 1; }
    cp "$LEDGER/gen-$nn.13d.sh" "$LEDGER/gen-$nn.13.sh"
    say "DELTA $nn applied: $DELTAS/$nn.pre.sh"
  fi
  # Whole-script replacement (scripts/rebuild/r4/deltas/NNN.replace.sh): for a package whose 13.1 page
  # needs another build flow than the generator's (123: monorepo LLVM, no extra tarballs). Applied last.
  if [ -f "$DELTAS/$nn.replace.sh" ]; then
    cp "$DELTAS/$nn.replace.sh" "$LEDGER/gen-$nn.13.sh"
    say "REPLACE $nn applied: $DELTAS/$nn.replace.sh"
  fi
  # Extra files the 13.1 page needs next to the build tree (scripts/rebuild/r4/deltas/NNN.files): one line
  # "URL MD5|- FILENAME". The file goes to /sources/blfs-build (the parent of the source tree, where
  # the book's "patch -i ../NAME" looks). "-" means the book page gives no md5 (then a note is written).
  if [ -f "$DELTAS/$nn.files" ]; then
    mkdir -p "$R4/sources/blfs-build"
    while read -r furl fmd5 fdest; do
      [ -z "$furl" ] && continue
      fsrc=$SRC13/$fdest
      if [ ! -s "$fsrc" ]; then
        curl -fL -sS -o "$fsrc.part" "$furl" && mv "$fsrc.part" "$fsrc" \
          || { rm -f "$fsrc.part"; say "FAIL $nn $nv download $furl"; return 1; }
      fi
      if [ "$fmd5" != - ]; then
        got=$(python3 "$LIB" md5 "$fsrc" "$fmd5") || { say "FAIL $nn $nv $fdest md5 $got, book $fmd5"; return 1; }
      else
        say "NOTE $nn $fdest: no md5 on the book page; sha256 $(sha256sum "$fsrc" | cut -d' ' -f1) (TOFU)"
      fi
      cp "$fsrc" "$R4/sources/blfs-build/$fdest" || return 1
    done < "$DELTAS/$nn.files"
  fi
  cp "$LEDGER/gen-$nn.13.sh" "$R4/sources/.blfs-$nn.sh" || return 1

  # A build tree left by an earlier failed try keeps its generated files (meson does not regenerate
  # them): start from an empty tree.
  rm -rf "$R4/sources/blfs-build/$nv"
  # An earlier try that got past its install (then failed at adopt-base) left files behind. Remove the
  # files it added, so the book's commands (e.g. ln -s) can run again. Changed files are overwritten.
  if [ -s "$LEDGER/diff/$nn.tsv" ]; then
    awk -F'\t' '$1=="A" && ($3=="file" || $3=="symlink") {print $2}' "$LEDGER/diff/$nn.tsv" \
      | while read -r p; do rm -f -- "$R4/$p"; done
    say "RETRY $nn: removed the files added by the earlier try"
  fi
  pre=$SNAPS/pre-$nn-$DATE
  post=$SNAPS/post-$nn-$DATE
  btrfs subvolume snapshot -r "$R4" "$pre" > /dev/null || { say "FAIL $nn $nv snapshot pre"; return 1; }

  kernfs_up || { kernfs_down; say "FAIL $nn $nv kernfs mount"; btrfs subvolume delete "$pre" > /dev/null; return 1; }
  # LC_ALL=C: the base locale (/etc/locale.conf) is tr_TR.UTF-8, where sed's [a-z] range misses 'i'
  # (p11-kit 003 generated "vo_d"). The target keeps its locale; only the build runs in C.
  chroot "$R4" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j"$JOBS" \
    LANG=C LC_ALL=C \
    /bin/bash --login +h "/sources/.blfs-$nn.sh" > "$LEDGER/logs/$nn.log" 2>&1
  rc=$?
  kernfs_down

  btrfs subvolume snapshot -r "$R4" "$post" > /dev/null || { say "FAIL $nn $nv snapshot post"; return 1; }
  if [ $rc -ne 0 ]; then
    say "FAIL $nn $nv build rc=$rc $(( $(date +%s) - start ))s log=$LEDGER/logs/$nn.log"
    # Keep the diff of a failed try: its added files are removed before the next try (RETRY above).
    "$R3L" diff "$pre" "$post" > "$LEDGER/diff/$nn.tsv"
    btrfs subvolume delete "$pre" "$post" > /dev/null
    return 1
  fi

  "$R3L" diff "$pre" "$post" > "$LEDGER/diff/$nn.tsv"
  man=$LEDGER/manifests/$nn-$name.json
  n=$(python3 "$LIB" manifest --root "$post" --diff "$LEDGER/diff/$nn.tsv" --name "$name" --version "$ver" \
        --url "$url" --sha256 "$sha" --out "$man") \
    || { say "FAIL $nn $nv manifest"; btrfs subvolume delete "$pre" "$post" > /dev/null; return 1; }

  # Last writer owns (the R3 rule): paths this package rewrote are moved from the record that had them.
  mkdir -p "$LEDGER/transfers"
  tn=$(python3 "$LIB" transfer --root "$R4" --alp "$ALP" --manifest "$man" --name "$name" --version "$ver" \
        --log "$LEDGER/transfers/moves.tsv") || { say "FAIL $nn $nv ownership transfer"; btrfs subvolume delete "$pre" "$post" > /dev/null; return 1; }
  [ "$tn" != 0 ] && say "TRANSFER $nn $name took $tn path(s) from earlier records (see r4-ledger/transfers/moves.tsv)"
  python3 "$ALP" --root "$R4" adopt-base --manifest "$man" --name "$name" --version "$ver" \
    --source-sha256 "$sha" > "$LEDGER/adopt/$nn.log" 2>&1
  if [ $? -ne 0 ]; then
    say "FAIL $nn $nv alp adopt-base refused (log $LEDGER/adopt/$nn.log)"
    btrfs subvolume delete "$pre" "$post" > /dev/null; return 1
  fi

  elfs=$LEDGER/audit/$nn.elfs
  python3 "$LIB" elfs --root "$post" --diff "$LEDGER/diff/$nn.tsv" > "$elfs"
  if [ -s "$elfs" ]; then
    # The audit's own exit code (0 = no unallowed hits). The earlier pipeline into tee/grep took the
    # exit code of a subshell, so a failing audit was recorded as audit_rc=0 (libgcrypt 039, Mesa 128).
    xargs -d '\n' -a "$elfs" bash "$AUDIT" > "$LEDGER/audit/$nn.txt" 2>&1
    arc=$?
    summary=$(grep '^audit:' "$LEDGER/audit/$nn.txt" | tail -1)
  else
    summary="audit: no ELF files"; arc=0
  fi
  btrfs subvolume delete "$pre" "$post" > /dev/null
  # The ISA gate: a package with unallowed nonvariant hits is a FAIL (the batch stops). It stays installed
  # and recorded; a rerun from its number rebuilds it (the RETRY step removes its files first).
  if [ "$arc" -ne 0 ]; then
    say "FAIL $nn $nv audit rc=$arc $summary (log $LEDGER/audit/$nn.txt)"
    return 1
  fi
  say "OK $nn $nv $(( $(date +%s) - start ))s files=$n sha256=$sha(TOFU) md5=BLFS-page-ok alp=adopted audit_rc=$arc $summary"
  return 0
}

preflight
say "=== R4 batch $FIRST-$LAST start (jobs=$JOBS)"
for nn in $(awk -F'\t' -v a="$FIRST" -v b="$LAST" 'NR>1 && $1>=a && $1<=b {print $1}' "$PLAN"); do
  if ! build_one "$nn"; then
    say "=== R4 batch STOPPED at $nn"
    touch "$LEDGER/FAILED"
    exit 1
  fi
done
say "=== R4 batch $FIRST-$LAST DONE"
touch "$LEDGER/DONE"
