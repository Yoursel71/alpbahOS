#!/usr/bin/env python3
"""office_fixtures.py -- OFFICE-01 için bilinen içerikli DOCX/XLSX üretir ve gidiş-dönüşü denetler (stdlib-only).

Üretilen belgeler yalnız bu projenin yazdığı içeriği taşır (telifli örnek belge yok):
Türkçe karakterler (ğ ü ş ı ö ç Ğ Ü Ş İ Ö Ç), bir tablo, bir formül.

    python office_fixtures.py make --out DIR          # alpbah-test.docx, alpbah-test.xlsx
    python office_fixtures.py check FILE [FILE...]    # içerik beklenenle aynı mı

Hedef sistemde gidiş-dönüş: `make` → LibreOffice ile aç/kaydet (ya da
`soffice --headless --convert-to docx:"MS Word 2007 XML" --outdir out alpbah-test.docx`)
→ `check out/alpbah-test.docx`. check yalnız metin/hücre değerlerini karşılaştırır;
biçim ve sayfa düzeni gözle ve PDF çıktısıyla değerlendirilir (test planı).
"""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

TURKISH = "Atatürk ilkeleri: ğüşıöç ĞÜŞİÖÇ — İstanbul, Iğdır, Çanakkale."
PARAGRAPHS = [
    "alpbahOS OFFICE-01 test belgesi",
    TURKISH,
    "Satır sonu, sekme\tve özel karakterler: € ₺ “tırnak” ‘tek’ … %50",
]
TABLE = [["Ürün", "Adet"], ["Çay", "12"], ["Şeker", "30"]]
# A1:B3 değerleri + B4 = toplam formülü (yapay veriler)
SHEET = [["Ürün", "Adet"], ["Çay", 12], ["Şeker", 30]]
SUM_CELL, SUM_FORMULA, SUM_VALUE = "B4", "SUM(B2:B3)", 12 + 30

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
S = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG = "http://schemas.openxmlformats.org/package/2006/relationships"
CT = "http://schemas.openxmlformats.org/package/2006/content-types"


def _esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _run(text: str) -> str:
    parts = text.split("\t")
    out = []
    for i, part in enumerate(parts):
        if i:
            out.append("<w:tab/>")
        if part:
            out.append(f'<w:t xml:space="preserve">{_esc(part)}</w:t>')
    return "<w:r>" + "".join(out) + "</w:r>"


def make_docx(path: Path) -> None:
    body = "".join(f"<w:p>{_run(p)}</w:p>" for p in PARAGRAPHS)
    rows = "".join("<w:tr>" + "".join(f"<w:tc><w:p>{_run(c)}</w:p></w:tc>" for c in row) + "</w:tr>" for row in TABLE)
    document = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                f'<w:document xmlns:w="{W}"><w:body>{body}<w:tbl>{rows}</w:tbl><w:sectPr/></w:body></w:document>')
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml",
                   f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="{CT}">'
                   '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                   '<Default Extension="xml" ContentType="application/xml"/>'
                   '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
                   '</Types>')
        z.writestr("_rels/.rels",
                   f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="{PKG}">'
                   '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
                   '</Relationships>')
        z.writestr("word/document.xml", document)


def make_xlsx(path: Path) -> None:
    rows = []
    for r, row in enumerate(SHEET, start=1):
        cells = []
        for c, value in enumerate(row):
            ref = f"{'AB'[c]}{r}"
            if isinstance(value, int):
                cells.append(f'<c r="{ref}"><v>{value}</v></c>')
            else:
                cells.append(f'<c r="{ref}" t="inlineStr"><is><t>{_esc(value)}</t></is></c>')
        rows.append(f'<row r="{r}">{"".join(cells)}</row>')
    rows.append(f'<row r="4"><c r="{SUM_CELL}"><f>{SUM_FORMULA}</f><v>{SUM_VALUE}</v></c></row>')
    sheet = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
             f'<worksheet xmlns="{S}"><sheetData>{"".join(rows)}</sheetData></worksheet>')
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml",
                   f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="{CT}">'
                   '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                   '<Default Extension="xml" ContentType="application/xml"/>'
                   '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
                   '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
                   '</Types>')
        z.writestr("_rels/.rels",
                   f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="{PKG}">'
                   '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
                   '</Relationships>')
        z.writestr("xl/workbook.xml",
                   f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="{S}" xmlns:r="{R}">'
                   '<sheets><sheet name="Sayım" sheetId="1" r:id="rId1"/></sheets></workbook>')
        z.writestr("xl/_rels/workbook.xml.rels",
                   f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="{PKG}">'
                   '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
                   '</Relationships>')
        z.writestr("xl/worksheets/sheet1.xml", sheet)


def docx_text(path: Path) -> tuple[list[str], list[list[str]]]:
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("word/document.xml"))
    ns = {"w": W}

    def para_text(p) -> str:
        out = []
        for node in p.iter():
            if node.tag == f"{{{W}}}t":
                out.append(node.text or "")
            elif node.tag == f"{{{W}}}tab":
                out.append("\t")
        return "".join(out)

    body = root.find("w:body", ns)
    paragraphs = [para_text(p) for p in body.findall("w:p", ns)]
    tables = [[para_text(tc) for tc in tr.findall("w:tc", ns)] for tr in body.iter(f"{{{W}}}tr")]
    return [p for p in paragraphs if p], tables


def xlsx_cells(path: Path) -> dict[str, tuple[str | None, str | None]]:
    """{hücre: (değer, formül)} -- paylaşılan dizgiler çözülür."""
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        shared = []
        if "xl/sharedStrings.xml" in names:
            for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall(f"{{{S}}}si"):
                shared.append("".join(t.text or "" for t in si.iter(f"{{{S}}}t")))
        sheet_name = next(n for n in sorted(names) if re.match(r"xl/worksheets/sheet\d+\.xml$", n))
        root = ET.fromstring(z.read(sheet_name))
    cells = {}
    for c in root.iter(f"{{{S}}}c"):
        ref, kind = c.get("r"), c.get("t")
        f = c.find(f"{{{S}}}f")
        v = c.find(f"{{{S}}}v")
        value = v.text if v is not None else None
        if kind == "s" and value is not None:
            value = shared[int(value)]
        elif kind == "inlineStr":
            value = "".join(t.text or "" for t in c.iter(f"{{{S}}}t"))
        cells[ref] = (value, f.text if f is not None else None)
    return cells


def check(path: Path) -> list[str]:
    problems = []
    if path.suffix == ".docx":
        paragraphs, table = docx_text(path)
        for expected in PARAGRAPHS:
            if expected not in paragraphs:
                problems.append(f"paragraf eksik/bozuk: {expected!r}")
        if table != TABLE:
            problems.append(f"tablo farklı: {table!r}")
    elif path.suffix == ".xlsx":
        cells = xlsx_cells(path)
        for r, row in enumerate(SHEET, start=1):
            for c, expected in enumerate(row):
                ref = f"{'AB'[c]}{r}"
                value = cells.get(ref, (None, None))[0]
                if value is None or (str(expected) != value and not _same_number(expected, value)):
                    problems.append(f"{ref}: {value!r} != {expected!r}")
        value, formula = cells.get(SUM_CELL, (None, None))
        if (formula or "").lstrip("=").upper().replace(" ", "") != SUM_FORMULA:
            problems.append(f"{SUM_CELL} formülü: {formula!r}")
        if not _same_number(SUM_VALUE, value):
            problems.append(f"{SUM_CELL} değeri: {value!r} != {SUM_VALUE}")
    else:
        problems.append("desteklenmeyen uzantı (docx/xlsx)")
    return problems


def _same_number(expected, value) -> bool:
    try:
        return float(value) == float(expected)
    except (TypeError, ValueError):
        return False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    mk = sub.add_parser("make")
    mk.add_argument("--out", type=Path, required=True)
    ck = sub.add_parser("check")
    ck.add_argument("files", type=Path, nargs="+")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    if args.cmd == "make":
        args.out.mkdir(parents=True, exist_ok=True)
        make_docx(args.out / "alpbah-test.docx")
        make_xlsx(args.out / "alpbah-test.xlsx")
        print(f"yazıldı: {args.out / 'alpbah-test.docx'}, {args.out / 'alpbah-test.xlsx'}")
        return 0
    failed = False
    for path in args.files:
        try:
            problems = check(path)
        except (OSError, KeyError, StopIteration, zipfile.BadZipFile, ET.ParseError) as exc:
            problems = [f"okunamadı: {exc}"]
        print(f"{path}: {'GEÇTİ' if not problems else 'KALDI'}")
        for problem in problems:
            print(f"  - {problem}")
        failed |= bool(problems)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
