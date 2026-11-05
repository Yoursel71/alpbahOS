#!/usr/bin/env python3
"""Extract BLFS 12.4-systemd command blocks for the packages listed in ../order.txt.

Input : ../order.txt and the cached pages in ./raw/ (fetched with curl, log in ./fetch.log)
Output: ./packages/NN-name-version.sh, ./index.tsv, ./boxes.txt
Run   : python3 -I extract_blocks.py
        Parses HTML only. None of the extracted commands is executed.

Selection: <pre class="userinput"> and <pre class="root"> inside div.installation or
div.configuration of the package's section. <pre class="screen"> (output) is never copied.
Blocks outside those divs (Downloading, Setting Package Order, intro boxes, Starting X, ...)
are listed in boxes.txt section C and noted in index.tsv.
"""
import os
import re
import shutil
import textwrap
import collections
from lxml import html

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(HERE)
RAW = os.path.join(HERE, "raw")
PKG = os.path.join(HERE, "packages")
ORDER = os.path.join(BASE, "order.txt")
PREFIX = "https://www.linuxfromscratch.org/blfs/view/12.4-systemd/"

# ---- per-line classification (applied to every physical line of a block) ----
TEST_LINE = re.compile(
    r"(?:^|[\s;&|(])(?:make|gmake|ninja|meson|cargo)\s+(?:-\S+\s+(?:[^-\s]\S*\s+)?)*(?:check|test|tests)\b"
    r"|\bctest\b|\bpytest\b|\btox\b|\brun-tests\b")
INSTALL_LINE = re.compile(
    r"(?:^|[\s;&|(])(?:make|gmake|ninja|meson|pip3?|python3?|cargo|cpan|perl)\b[^\n]*?\s(?:install)\b"
    r"|(?:^|[\s;&|(])install\s+-"
    r"|(?:^|[\s;&|(])(?:cp|ln|chown|chmod|mkdir|ldconfig|glib-compile-schemas|gtk-update-icon-cache"
    r"|gtk-query-immodules-3\.0|gdk-pixbuf-query-loaders|fc-cache|update-desktop-database|mv)\b")
BUILD_LINE = re.compile(
    r"\./configure|\bconfigure\b|\bmake\b|\bninja\b|\bmeson\b|\bcmake\b|\bcargo\b|setup\.py|\bpip3?\s+wheel"
    r"|Makefile\.PL|\bbootstrap\.sh\b|\bb2\b|\bgcc\b|\bg\+\+\b|\bpython3?\s+-m\s+build")
OPTIONAL_DESC = re.compile(
    r"\b(optional|optionally|if desired|if you (want|wish|prefer|downloaded|need)|skip|can be skipped"
    r"|not required|not necessary)\b", re.I)
TEST_SENT = re.compile(
    r"\b(test suites?|to test|run the tests?|running the tests?|tests? (?:can|may|will) be run"
    r"|check the (?:proper|results)|test the|test results|make check|make test|ninja test|pytest)\b", re.I)
ROOT_SENT = re.compile(r"\bas (?:the )?root\b", re.I)
INLINE_EXTRA = {
    ("general/boost.html", "boost-1.89.0"): [
        ("pushd tools/build/test; python3 test_all.py; popd",
         "To run Boost.Build's regression tests, issue pushd tools/build/test; python3 test_all.py; popd.")],
}
REASON_OVERRIDE = {
    ("x/TTF-and-OTF-fonts.html", "noto-sans"):
        "no command block in the 'Noto fonts' subsection; the only root block on the page is a generic "
        "DejaVu font install example (install -v -d -m755 /usr/share/fonts/dejavu ... fc-cache), not copied",
}

TEST_DESC = re.compile(r"\b(test suites?|tests?|testing|tested|test the|check the proper|checking the proper)\b", re.I)
NO_TEST_DESC = re.compile(r"no test suite|not come with a test suite|does not (come|have)[^.]*test", re.I)

# Box blocks that are plain, unconditional instructions and stay active.
# Checked by hand: every in-scope box on the 123 pages is conditional, DESTDIR-only,
# a cleanup/cache step, a test precaution, or a helper for an option -> none qualifies.
PLAIN_BOXES = set()

STD_VARS = {"HOME", "PATH", "EUID", "PIPESTATUS", "UID", "PWD", "USER", "SHELL", "LANG",
            "CFLAGS", "CXXFLAGS", "LDFLAGS", "MAKEFLAGS", "PKG_CONFIG_PATH", "LD_LIBRARY_PATH"}


def tokens(el):
    return (el.get("class") or "").split()


def clean(s):
    return " ".join(s.replace("\xa0", " ").split())


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def base_name(nv):
    nv = nv.split(":")[0]
    return re.sub(r"-\d[\w.]*$", "", nv)


def raw_path(url):
    base = url.split("#", 1)[0]
    return os.path.join(RAW, base[len(PREFIX):].replace("/", "_"))


def load(path):
    with open(path, "rb") as fh:
        return html.document_fromstring(fh.read())


def heading_of(div):
    hs = div.xpath("./h1|./h2|./h3|./h4")
    return clean(hs[0].text_content()) if hs else ""


def ctx(pre):
    """(nearest installation div or None, inside configuration?, admon kind or None)."""
    install, config, box = None, False, None
    for a in pre.iterancestors():
        if a.tag != "div":
            continue
        t = tokens(a)
        if install is None and "installation" in t:
            install = a
        if "configuration" in t:
            config = True
        if box is None and len(t) > 1 and t[0] == "admon":
            box = t[1]
    return install, config, box


def desc_of(pre):
    """The 'Command' sentence(s) right before a block: the nearest <p> sibling, plus any
    admonition boxes sitting between that paragraph and the block (as "[Note] ...")."""
    boxes, sib = [], pre.getprevious()
    while sib is not None and sib.tag == "div" and tokens(sib)[:1] == ["admon"]:
        kind = tokens(sib)[1].capitalize() if len(tokens(sib)) > 1 else "Box"
        boxes.insert(0, "[%s] %s" % (kind, clean(" ".join(
            x.text_content() for x in sib.xpath("./p")))))
        sib = sib.getprevious()
    if sib is not None and sib.tag == "p":
        return " ".join([clean(sib.text_content())] + boxes).strip()
    if boxes:
        return " ".join(boxes).strip()
    return ""


def heading_before(pre):
    """Fallback when no sentence precedes a block: the nearest heading before it (section label)."""
    node = pre
    for _ in range(4):
        sib = node.getprevious()
        while sib is not None:
            if sib.tag in ("h2", "h3", "h4", "h5", "h6"):
                return "(section: %s)" % clean(sib.text_content())
            sib = sib.getprevious()
        node = node.getparent()
        if node is None:
            break
    return ""


def block_text(pre):
    return pre.text_content().replace("\xa0", " ").strip("\n")


def classify(text, desc, is_root, config):
    """Phase tags. Each physical line is TEST, INSTALL or BUILD; text-only lines add nothing."""
    if config:
        return ["CONFIG"]
    phases = set()
    for line in text.split("\n"):
        if not line.strip():
            continue
        if TEST_LINE.search(line):
            phases.add("TEST")
        elif INSTALL_LINE.search(line):
            phases.add("INSTALL")
        elif BUILD_LINE.search(line):
            phases.add("BUILD")
    if TEST_DESC.search(desc) and not NO_TEST_DESC.search(desc):
        phases.add("TEST")   # the sentence right before the block talks about the test suite
    if not phases:
        phases.add("INSTALL" if is_root else "BUILD")
    if is_root and "INSTALL" not in phases and "TEST" not in phases:
        phases.add("INSTALL")
    return [p for p in ("BUILD", "TEST", "INSTALL") if p in phases]


def md5_lists(doc):
    """{tarball: commented?} from every 'cat > x.md5 << "EOF"' heredoc on the page."""
    out = {}
    for pre in doc.iter("pre"):
        t = pre.text_content()
        if '<< "EOF"' in t and ".md5" in t.split("\n")[0]:
            for line in t.split("\n")[1:]:
                s = line.strip()
                if not s:
                    continue
                parts = s.lstrip("#").split()
                if len(parts) == 2 and re.search(r"\.(tar\.\w+|tgz|tbz2|txz|zip)$", parts[1]):
                    out[parts[1]] = s.startswith("#")
    return out


def page_section_pres(doc, nb, frag):
    """Return (ok, reason, candidate pre list, multi_install_page, scope nodes) for one order row."""
    installs = doc.xpath('//div[contains(concat(" ",normalize-space(@class)," ")," installation ")]')
    if frag:
        anchors = doc.xpath("//*[@id=$f or @name=$f]", f=frag)
        if not anchors:
            return False, "anchor #%s not on page" % frag, [], False, []
        a = anchors[0]
        head = next((x for x in a.iterancestors() if x.tag in ("h2", "h3", "h4")), None)
        if head is None:
            head = a.getparent()
        if head.tag == "h2":
            nodes = [head.getparent()]
            ident = clean(head.text_content())
            for p in head.getparent().xpath(".//p"):
                t = clean(p.text_content())
                if t.lower().startswith("download"):
                    ident += " " + t
        else:  # h3/h4 subsection: its siblings up to the next heading of same or higher level
            nodes, lvl = [], int(head.tag[1])
            for sib in head.itersiblings():
                if sib.tag in ("h2", "h3", "h4") and int(sib.tag[1]) <= lvl:
                    break
                nodes.append(sib)
            ident = clean(head.text_content())
        if norm(nb) not in norm(ident):
            return False, "section #%s does not name %s" % (frag, nb), [], False, []
        pres = []
        for n in nodes:
            pres.extend([n] if n.tag == "pre" else n.xpath(".//pre"))
        return True, "", pres, False, nodes
    multi = len(installs) > 1
    if multi:
        prim = [d for d in installs if heading_of(d).lower().startswith("installation of")
                and norm(nb) in norm(heading_of(d))]
        if len(prim) != 1:
            return False, "section not found on listed page (no 'Installation of %s')" % nb, [], True, []
    return True, "", list(doc.iter("pre")), multi, None


INST_XP = '//div[contains(concat(" ",normalize-space(@class)," ")," installation ")]'
CONF_XP = '//div[contains(concat(" ",normalize-space(@class)," ")," configuration ")]'


def inline_tests(divs):
    """Test commands given in a sentence (not in a <pre>): [(command text, sentence)]."""
    out, seen = [], set()
    for d in divs:
        for p in ([d] if d.tag == "p" else d.iter("p")):
            if p in seen or any(a.tag == "pre" for a in p.iterancestors()):
                continue
            seen.add(p)
            t = clean(p.text_content())
            if not TEST_SENT.search(t) or NO_TEST_DESC.search(t):
                continue
            for c in p.iter("span", "kbd", "code", "strong"):
                if "command" not in (c.get("class") or "") and c.tag != "strong":
                    continue
                cmd = clean(c.text_content())
                if (TEST_LINE.search(cmd) or re.match(r"(make|ninja|meson|ctest|pytest)\b.*\b(check|test)\b", cmd)) \
                        and cmd not in [x[0] for x in out]:
                    out.append((cmd, t))
    return out


def build_all():
    with open(ORDER, encoding="utf-8") as fh:
        rows = [l.split() for l in fh if l.strip()]
    assert len(rows) == 335, len(rows)
    by_base = collections.defaultdict(list)
    for r in rows:
        by_base[r[3].split("#", 1)[0]].append(r)

    docs, page_info = {}, {}
    for base in by_base:
        doc = load(raw_path(base))
        docs[base] = doc
        excluded, n_screen = [], 0
        for pre in doc.iter("pre"):
            if pre.get("class") == "screen":
                n_screen += 1
            elif pre.get("class") in ("userinput", "root"):
                install, config, _ = ctx(pre)
                if install is None and not config:
                    excluded.append(pre)
        page_info[base] = dict(
            excluded=excluded, n_screen=n_screen,
            kernel=bool(doc.xpath('//div[contains(concat(" ",normalize-space(@class)," ")," kernel ")]')),
            md5=md5_lists(doc))

    results = []
    for nn, nv, req, url in rows:
        base = url.split("#", 1)[0]
        frag = url.split("#", 1)[1] if "#" in url else ""
        doc = docs[base]
        nb = base_name(nv)
        notes = []
        ok, reason, cand, multi, scope_nodes = page_section_pres(doc, nb, frag)
        if not ok and (base[len(PREFIX):], nb) in REASON_OVERRIDE:
            reason = REASON_OVERRIDE[(base[len(PREFIX):], nb)]
        blocks = []
        if ok:
            for p in cand:
                if p.get("class") not in ("userinput", "root"):
                    continue
                install, config, box = ctx(p)
                if install is None and not config:
                    continue
                alt, h = False, ""
                if multi and install is not None:
                    h = heading_of(install)
                    if h.lower().startswith("installation of"):
                        if norm(nb) not in norm(h):
                            continue  # another package's section on a multi-section page
                    else:
                        alt = True   # e.g. "The 'which' Script": alternative to the build
                text = block_text(p)
                desc = desc_of(p)          # sentence used for classification
                is_root = p.get("class") == "root" or bool(ROOT_SENT.search(desc))
                shown = desc
                if box and not desc:
                    shown = "(box text) " + clean(install.text_content() if install is not None else "")[:240]
                if not shown:
                    shown = heading_before(p)  # display only; never used to classify
                tags = classify(text, desc, is_root, config)
                if is_root:
                    tags.append("ROOT")
                if box:
                    tags.append("BOX")
                if alt or OPTIONAL_DESC.search(desc):
                    tags.append("OPTIONAL")
                if alt:
                    notes.append("OPTIONAL alternative section '%s' copied (not the package build)" % h)
                blocks.append(dict(tags=tags, desc=shown, text=text, box=box, pre=p,
                                   skipped=bool(box) and p not in PLAIN_BOXES))
            if not blocks:
                ok, reason = False, "no userinput/root block in the section"
            # sassc page: one section holds libsass (first part) and sassc (after the
            # page's own sentence "Build the command line wrapper"); each row gets its part.
            if ok and base.endswith("general/sassc.html"):
                mark = next(i for i, b in enumerate(blocks) if b["desc"].startswith("Build the command line wrapper"))
                if nb == "libsass":
                    blocks = blocks[:mark]
                    notes.append("section shared with sassc-3.6.2: only the libsass part copied")
                elif nb == "sassc":
                    blocks = blocks[mark:]
                    notes.append("section shared with libsass-3.6.6: only the sassc part copied (needs the libsass-3.6.6 tree from the libsass step)")
            # freetype2 page has one procedure; pass1/pass2 rows both get it (see index notes)
            if ok and base.endswith("general/freetype2.html"):
                notes.append("one procedure on the page for both passes (circular harfbuzz): same blocks copied for pass1 and pass2")
        inline = []
        if ok:
            if frag:
                divs = list(scope_nodes or [])
            else:
                installs = doc.xpath(INST_XP)
                if multi:
                    installs = [d for d in installs if not heading_of(d).lower().startswith("installation of")
                                or norm(nb) in norm(heading_of(d))]
                divs = installs + doc.xpath(CONF_XP)
            inline = inline_tests(divs)
            # plain-text test command inside a sentence (not in a command element), checked by hand
            inline += INLINE_EXTRA.get((base[len(PREFIX):], nv), [])
        results.append(dict(nn=nn, nv=nv, req=req, url=url, base=base, frag=frag, nb=nb, inline=inline,
                            ok=ok, reason=reason, blocks=blocks, notes=notes,
                            rows_on_page=by_base[base], shared=(not frag) and len(by_base[base]) > 1,
                            info=page_info[base], doc=doc, order_rows_all=rows))
    return results, by_base, page_info


def write_packages(results):
    if os.path.isdir(PKG):
        shutil.rmtree(PKG)
    os.makedirs(PKG)
    index, boxes_perfile = [], []
    for R in results:
        nn, nv, url, base, info = R["nn"], R["nv"], R["url"], R["base"], R["info"]
        notes = list(R["notes"])
        fn = "%s-%s.sh" % (nn, re.sub(r"[^A-Za-z0-9._+-]", "_", nv))
        L = ["# BLFS 12.4-systemd build commands, copied verbatim from the page.",
             "# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.",
             "# package: %s   (order.txt row %s, %s)" % (nv, nn, R["req"]),
             "# page: %s" % url]
        if R["frag"]:
            L.append("# section: anchor #%s" % R["frag"])
        split = base.endswith("general/sassc.html")
        if R["shared"] and R["ok"] and not split:
            L.append("# SHARED-SECTION: this page section is shared by %d order rows (%s); same blocks in each file."
                     % (len(R["rows_on_page"]), ", ".join(x[1] for x in R["rows_on_page"])))
            notes.append("SHARED-SECTION by %d rows: same blocks in each file" % len(R["rows_on_page"]))
        if not R["ok"]:
            L += ["# reason: %s" % R["reason"], "# NO-COMMANDS"]
            notes.insert(0, "NO-COMMANDS: %s" % R["reason"])
        for cmd, sent in R["inline"]:
            L.append("# INLINE-TEST (test command given in a sentence on the page, not an active block): %s" % cmd)
            notes.append("inline test (sentence, not a block): %s" % cmd)
        L.append("")
        n_skipped, has_test = 0, bool(R["inline"])
        for b in (R["blocks"] if R["ok"] else []):
            if "TEST" in b["tags"]:
                has_test = True
            L.append("# --- [%s] ---" % ",".join(b["tags"]))
            if b["desc"]:
                L += ["# " + w for w in textwrap.wrap(b["desc"], 96)]
            else:
                L.append("# (no description sentence immediately before this block on the page)")
            if b["skipped"]:
                n_skipped += 1
                boxes_perfile.append((nn, nv, base, b["box"], b["text"].split("\n")[0]))
                L += [("# SKIPPED-BOX: " + x).rstrip() for x in b["text"].split("\n")]
            else:
                L += b["text"].split("\n")
            L.append("")
        text_all = "\n".join(b["text"] for b in R["blocks"]) if R["ok"] else ""
        if info["kernel"]:
            notes.append("page has a kernel-config section (div.kernel, screen output only, not copied)")
        if info["excluded"]:
            notes.append("NOT copied, outside Installation/Configuration (%d): %s"
                         % (len(info["excluded"]),
                            " | ".join(clean(p.text_content())[:45] for p in info["excluded"])))
        for var in sorted(set(re.findall(r"\$\{?([A-Z][A-Z0-9_]*)", text_all)) - STD_VARS):
            notes.append("uses $%s (no assignment in the copied blocks; set it before running)" % var)
        for ph in sorted(set(re.findall(r"<[A-Za-z][^<>\n]{0,40}>", text_all))):
            notes.append("placeholder %s" % ph)
        if re.search(r"\.md5\b", text_all):
            notes.append("loop reads an .md5 list written by a block that is NOT copied")
        if info["md5"] and R["ok"]:
            tar = [t for t in info["md5"] if t.startswith(nv.split(":")[0] + ".")]
            if not tar:
                notes.append("NOT in the page's md5 list (no %s.tar.* line)" % nv)
            elif info["md5"][tar[0]]:
                notes.append("COMMENTED OUT in the page's md5 list (%s): check before use" % tar[0])
            commented = sorted(t for t, c in info["md5"].items() if c)
            if commented and R["shared"]:
                notes.append("page md5 list comments out (loop skips): %s" % ", ".join(
                    "%s (%s)" % (t, "order row " + ",".join(x[0] for x in R["order_rows_all"]
                                 if t.startswith(x[1].split(":")[0] + "."))
                        if any(t.startswith(x[1].split(":")[0] + ".") for x in R["order_rows_all"])
                        else "not in order.txt") for t in commented))
        if R["ok"] and re.search(r"(^|[\s;&|(])(passwd|visudo|crontab -e|nano|vim?|less|more)(\s|$)", text_all, re.M):
            notes.append("interactive command(s) present")
        if R["ok"] and re.search(r"\b(systemctl|useradd|groupadd|usermod|grub-\w+|mkfs|sysctl|mount|umount)\b", text_all):
            notes.append("system/service-changing command(s) present")
        if n_skipped:
            notes.append("%d box(es) SKIPPED-BOX (commented out)" % n_skipped)
        if R["ok"] and "as_root" in text_all and any("as_root()" in b["text"] for b in R["blocks"] if b["skipped"]):
            notes.append("calls as_root, whose helper is in a SKIPPED-BOX: define it (or run as root) before use")
        with open(os.path.join(PKG, fn), "w", encoding="utf-8") as fh:
            fh.write("\n".join(L).rstrip("\n") + "\n")
        index.append(dict(nn=nn, nv=nv, file="packages/" + fn,
                          n=len(R["blocks"]) if R["ok"] else 0,
                          has_test="yes" if has_test else "no",
                          notes="; ".join(dict.fromkeys(notes)).replace("\t", " ")))
    return index, boxes_perfile


def write_index_and_boxes(index, boxes_perfile, by_base, page_info):
    with open(os.path.join(HERE, "index.tsv"), "w", encoding="utf-8") as fh:
        fh.write("NN\tname-version\tfile\tnumber_of_blocks\thas_test\tnotes\n")
        for r in index:
            fh.write("%s\t%s\t%s\t%d\t%s\t%s\n" % (r["nn"], r["nv"], r["file"], r["n"], r["has_test"], r["notes"]))

    uniq = collections.OrderedDict()
    for nn, nv, base, kind, first in boxes_perfile:
        uniq.setdefault((base, first), dict(kind=kind, files=[]))["files"].append(nn)
    with open(os.path.join(HERE, "boxes.txt"), "w", encoding="utf-8") as fh:
        fh.write("# Boxes (Note/Warning/Important/Caution/Tip) whose commands were COMMENTED OUT (SKIPPED-BOX).\n")
        fh.write("# Unique boxes (page + first command line): %d.  Per-file copies (one per package file): %d.\n"
                 % (len(uniq), len(boxes_perfile)))
        fh.write("# Every in-scope box was read; none is an unconditional instruction, so none is kept active.\n\n")
        fh.write("## A. unique boxes\n")
        fh.write("page\tbox\tfirst command line\tcopied into (NN)\n")
        for (base, first), v in uniq.items():
            fh.write("%s\t%s\t%s\t%s\n" % (base.split("systemd/")[1], v["kind"], first[:140], ",".join(v["files"])))
        fh.write("\n## B. per-file SKIPPED-BOX list\n")
        fh.write("NN\tname-version\tpage\tbox\tfirst command line\n")
        for nn, nv, base, kind, first in boxes_perfile:
            fh.write("%s\t%s\t%s\t%s\t%s\n" % (nn, nv, base.split("systemd/")[1], kind, first[:140]))
        fh.write("\n## C. blocks NOT copied (outside Installation/Configuration), per page\n")
        fh.write("page\tfirst line\tbox\tpackage rows on page\n")
        for base in sorted(page_info):
            for p in page_info[base]["excluded"]:
                fh.write("%s\t%s\t%s\t%d\n" % (base.split("systemd/")[1],
                                             clean(block_text(p).split("\n")[0])[:120],
                                             ctx(p)[2] or "-", len(by_base[base])))


if __name__ == "__main__":
    results, by_base, page_info = build_all()
    index, boxes_perfile = write_packages(results)
    write_index_and_boxes(index, boxes_perfile, by_base, page_info)
    print("packages:", len(index), " with commands:", sum(1 for R in results if R["ok"]),
          " without:", sum(1 for R in results if not R["ok"]),
          " skipped box copies:", len(boxes_perfile))
