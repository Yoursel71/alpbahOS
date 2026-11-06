# OFFICE-01 — LibreOffice compatibility test plan

Status (updated 2026-11-06): **planned; no office test has been run on alpbahOS.** LibreOffice is not built yet (see [../README.md](../README.md)). The tests below run after the LibreOffice build (BLFS step).

Decisions:

- **D131:** Microsoft Office is not a target. LibreOffice handles Word, Excel and PowerPoint files. No Word compatibility is promised without tests on alpbahOS.
- **D127:** LibreOffice is one of the preinstalled applications.
- **D120:** Turkish UI and Turkish Q keyboard.

## 1. Test documents

[`office_fixtures.py`](office_fixtures.py) (stdlib only) writes `alpbah-test.docx` and `alpbah-test.xlsx`. They contain only content written for this project (no third-party sample documents):

- Turkish characters (ğüşıöç ĞÜŞİÖÇ, the İ/ı distinction).
- A tab, `€ ₺`, smart quotes.
- A 3×2 table.
- The formula `B4 = SUM(B2:B3)` (expected value 42).

Commands (run from the repo root):

```text
python3 -B profiles/apps/office/office_fixtures.py make --out <DIR>
python3 -B profiles/apps/office/office_fixtures.py check <DIR>/alpbah-test.docx <DIR>/alpbah-test.xlsx
```

`check` compares the text and cell values in a saved file with the expected content. It supports shared strings and inline strings. It does not check layout or formatting; those are checked by eye and from PDF output.

Headless round trip (after LibreOffice is built):

```text
soffice --headless --convert-to docx:"MS Word 2007 XML" --outdir <OUT> <DIR>/alpbah-test.docx
soffice --headless --convert-to xlsx --outdir <OUT> <DIR>/alpbah-test.xlsx
python3 -B profiles/apps/office/office_fixtures.py check <OUT>/alpbah-test.docx <OUT>/alpbah-test.xlsx
```

Reference point, not an alpbahOS result: on 26 Sep 2026 the fixtures were opened by Microsoft Word 16.0 and Excel 16.0 on a Windows machine, and `B4` computed 42. This only shows the files are valid OOXML. The Office output files were not added to the repo.

## 2. LibreOffice scenarios

| # | Scenario | Steps | Pass criterion | Result |
|---|---|---|---|---|
| L1 | DOCX open and save | Open `alpbah-test.docx` in Writer, save as DOCX | `check` passes; Turkish characters and the table survive | not run |
| L2 | XLSX open and save | Open `alpbah-test.xlsx` in Calc, save as XLSX | `check` passes; formula kept, value 42 | not run |
| L3 | Headless conversion | The `soffice --headless` commands above, for DOCX and XLSX | `check` passes on both converted files | not run |
| L4 | PDF and printing | Export Writer to PDF; print to a CUPS printer or a PDF printer | Turkish glyphs render (no boxes); text is selectable | not run |
| L5 | Font substitution | Open a document that uses Calibri, Cambria, Arial and Times New Roman | Carlito, Caladea and Liberation are used as metric-compatible substitutes; any line shift is recorded | not run |
| L6 | Turkish spell check | Type Turkish text in Writer | tr_TR dictionary (hunspell) is active; a wrong word is flagged | not run |
| L7 | Turkish Q keyboard | Type ğüşıöçİ in Writer | All characters enter correctly | not run |
| L8 | PPTX | Create a deck in Impress, save as PPTX, reopen | Text and slide count survive (the fixtures do not write PPTX; Impress creates the file) | not run |
| L9 | Default association | Double-click `.docx`, `.xlsx`, `.pptx` in Dolphin | The LibreOffice application listed in [`generated/mimeapps.list`](../generated/mimeapps.list) opens | not run |

Required packages (BLFS): LibreOffice; Carlito and Caladea (metric-compatible with Calibri and Cambria); Liberation fonts; hunspell with a Turkish dictionary; CUPS for printing.

## 3. Recording results

Each run is recorded as `docs/verification/office01-<date>.md` with the environment (host, chroot, QEMU VM or target), the LibreOffice version, the command, the result and the log path. Replace "not run" with the result. Do not write "Word works" or "LibreOffice is DOCX-compatible" until these scenarios have passed on a recorded run.
