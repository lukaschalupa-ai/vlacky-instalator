#!/usr/bin/env python3
"""Převod definic dekodérů JMRI (xml/decoders) do knihovny šablon CV pro aplikaci Vláčky.

Použití: python jmri2vlacky.py <cesta k JMRI/xml/decoders> <výstup.db|výstup.json>

Přípona .db vytvoří SQLite knihovnu, kterou aplikace čte (app/data/jmri_decoders.db).

Výsledek: JSON se seznamem rodin dekodérů. Každá rodina má modely a seznam
proměnných v sekci "variables" podle souboru (CV, maska, výchozí hodnota, rozsah, volby), u proměnných je
uvedeno, pro které modely platí (include/exclude podle JMRI).
Data pocházejí z projektu JMRI (GPL v2).
"""
import json
import os
import re
import sys
from lxml import etree

XI = "{http://www.w3.org/2001/XInclude}include"
URL_PREFIX = "http://jmri.org/xml/decoders/"
LANG = "{http://www.w3.org/XML/1998/namespace}lang"
PREF_LANGS = ("cs", None)  # nejdřív čeština, potom výchozí (angličtina)
VAL_TYPES = ("decVal", "hexVal", "enumVal", "shortAddressVal", "longAddressVal",
             "splitVal", "splitEnumVal", "splitHexVal", "splitHundredsVal",
             "speedTableVal", "compositeVal", "indexedVal", "splitTextVal",
             "splitDateTimeVal", "indexedPairVal")

_cache = {}


def load(path):
    if path not in _cache:
        parser = etree.XMLParser(remove_comments=True, remove_pis=True, resolve_entities=False)
        _cache[path] = etree.parse(path, parser).getroot()
    return _cache[path]


def resolve_href(href, base_dir, root_dir):
    if href.startswith(URL_PREFIX):
        return os.path.join(root_dir, href[len(URL_PREFIX):])
    if href.startswith("http"):
        return None
    return os.path.normpath(os.path.join(base_dir, href))


def expand(el, base_dir, root_dir, depth=0):
    """Rekurzivně nahradí xi:include obsahem souboru (bez síťového přístupu)."""
    for inc in list(el.iter(XI)):
        path = resolve_href(inc.get("href", ""), base_dir, root_dir)
        parent = inc.getparent()
        if parent is None:
            continue
        if not path or not os.path.exists(path) or depth > 10:
            parent.remove(inc)
            continue
        src = etree.fromstring(etree.tostring(load(path)))
        expand(src, os.path.dirname(path), root_dir, depth + 1)
        # soubor s kořenem <variables>/<enumVal>... vkládá své děti, jinak kořen samotný
        if src.tag in ("variables", "enumVal", "decoder-config"):
            items = [c for c in src if isinstance(c.tag, str) and c.tag not in
                     ("{http://docbook.org/ns/docbook}copyright",
                      "{http://docbook.org/ns/docbook}authorgroup",
                      "{http://docbook.org/ns/docbook}revhistory")]
        else:
            items = [src]
        idx = parent.index(inc)
        tail = inc.tail
        parent.remove(inc)
        for i, it in enumerate(items):
            parent.insert(idx + i, it)
        if tail and items:
            items[-1].tail = (items[-1].tail or "") + tail


def text_pref(el, tag):
    """Text potomka v preferovaném jazyce (cs, potom bez jazyka)."""
    by_lang = {}
    for c in el.findall(tag):
        lang = c.get(LANG)
        if lang not in by_lang:
            by_lang[lang] = " ".join("".join(c.itertext()).split())
    for lang in PREF_LANGS:
        if by_lang.get(lang):
            return by_lang[lang]
    return next((v for v in by_lang.values() if v), None)


def clean_tooltip(t):
    if not t:
        return None
    t = re.sub(r"<br\s*/?>", "\n", t, flags=re.I)
    t = re.sub(r"<[^>]+>", "", t)
    t = "\n".join(" ".join(l.split()) for l in t.splitlines()).strip()
    return t[:1000] or None


def split_list(v):
    return [s.strip() for s in v.split(",") if s.strip()] if v else []


def int_or_none(v):
    try:
        return int(str(v).strip(), 0) if v is not None else None
    except ValueError:
        try:
            return int(str(v).strip().lstrip("0") or "0")
        except ValueError:
            return None


def mask_info(mask):
    """JMRI maska 'XXXVVVVV' (bit 7 vlevo) -> (bitová maska, posun). Číselná maska taky."""
    if not mask:
        return 255, 0
    if re.fullmatch(r"[XV]{1,8}", mask):
        m = mask.rjust(8, "X")
        bits = [7 - i for i, ch in enumerate(m) if ch == "V"]
        value = sum(1 << b for b in bits)
        return value, (min(bits) if bits else 0)
    n = int_or_none(mask)
    if n:
        shift = (n & -n).bit_length() - 1
        return n, shift
    return 255, 0


SKIP_ITEMS = re.compile(r"swiss", re.I)   # „švýcarské přiřazení“ funkcí (ZIMO) aplikace nepotřebuje


def parse_variable(v):
    if SKIP_ITEMS.search(v.get("item") or ""):
        return None
    val = next((c for c in v if isinstance(c.tag, str) and c.tag in VAL_TYPES), None)
    if val is None:
        return None
    vtype = val.tag
    cv_attr = (v.get("CV") or "").strip()
    out = {
        "item": v.get("item"),
        "label": text_pref(v, "label") or v.get("label") or v.get("item"),
        "type": vtype,
    }
    if vtype in ("compositeVal",):
        return None  # složené proměnné nemají vlastní CV
    if vtype == "speedTableVal":
        out["cv"] = list(range(67, 95))
        out["type"] = "speedTable"
    elif "," in cv_attr or vtype.startswith("split"):
        cvs = [int_or_none(c) for c in split_list(cv_attr)]
        hi = int_or_none(v.get("highCV") or val.get("highCV"))
        if hi and hi not in cvs:
            cvs.append(hi)
        if not cvs or None in cvs:
            return None
        out["cv"] = cvs
    elif re.fullmatch(r"\d+", cv_attr):
        out["cv"] = int(cv_attr)
    else:
        # indexované CV (např. 16.2.257) zatím aplikace neumí
        out["cv_raw"] = cv_attr
        out["indexed"] = True
    bitmask, shift = mask_info(v.get("mask"))
    if bitmask != 255:
        out["mask"] = bitmask
        out["shift"] = shift
    d = int_or_none(v.get("default"))
    if d is not None:
        out["default"] = d
    mn, mx = int_or_none(val.get("min")), int_or_none(val.get("max"))
    if mn is not None:
        out["min"] = mn
    if mx is not None:
        out["max"] = mx
    if vtype in ("enumVal", "splitEnumVal"):
        choices, n = [], 0
        for ch in val.iter("enumChoice"):
            if ch.get("value") is not None:
                n = int_or_none(ch.get("value")) or 0
            label = text_pref(ch, "choice") or ch.get("choice")
            choices.append({"value": n, "label": label})
            n += 1
        if choices:
            out["choices"] = choices
    if v.get("readOnly") == "yes":
        out["readOnly"] = True
    if v.get("writeOnly") == "yes":
        out["writeOnly"] = True
    tip = clean_tooltip(text_pref(v, "tooltip") or v.get("tooltip"))
    if tip:
        out["tooltip"] = tip
    comment = text_pref(v, "comment") or v.get("comment")
    if comment:
        out["comment"] = " ".join(comment.split())[:300]
    inc, exc = split_list(v.get("include")), split_list(v.get("exclude"))
    if inc:
        out["include"] = inc
    if exc:
        out["exclude"] = exc
    return out


def convert_file(path, root_dir):
    root = etree.fromstring(etree.tostring(load(path)))
    if root.tag != "decoder-config":
        return None
    dec = root.find("decoder")
    if dec is None:
        return None
    expand(dec, os.path.dirname(path), root_dir)
    variables = []
    vs = dec.find("variables")
    if vs is not None:
        for v in vs.iter("variable"):
            pv = parse_variable(v)
            if pv:
                variables.append(pv)
    # stejné popisky v jedné rodině (např. 16× "Intenzita osvětlení") doplní JMRI název položky
    counts = {}
    for pv in variables:
        counts[pv["label"]] = counts.get(pv["label"], 0) + 1
    for pv in variables:
        if counts[pv["label"]] > 1 and pv.get("item") and pv["item"] != pv["label"]:
            pv["label"] = f'{pv["label"]} ({pv["item"]})'
    prog = dec.find("programming")
    families = []
    for fam in dec.findall("family"):
        models = []
        for m in fam.findall("model"):
            vcv = m.find("versionCV")
            if vcv is None:
                vcv = fam.find("versionCV")
            lo = m.get("lowVersionID") or (vcv.get("lowVersionID") if vcv is not None else None) or fam.get("lowVersionID")
            hi = m.get("highVersionID") or (vcv.get("highVersionID") if vcv is not None else None) or fam.get("highVersionID")
            models.append({k: v for k, v in {
                "model": m.get("model"),
                "productID": m.get("productID"),
                "lowVersionID": int_or_none(lo),
                "highVersionID": int_or_none(hi),
                "connector": m.get("connector"),
                "numOuts": int_or_none(m.get("numOuts")),
                "numFns": int_or_none(m.get("numFns")),
                "formFactor": m.get("formFactor"),
                "comment": m.get("comment"),
                "include": split_list(m.get("extFnsIncludes") or "") or None,
            }.items() if v})
        families.append({
            "file": os.path.relpath(path, root_dir).replace(os.sep, "/"),
            "mfg": fam.get("mfg"),
            "family": fam.get("name"),
            "comment": fam.get("comment"),
            "lowVersionID": int_or_none(fam.get("lowVersionID")),
            "highVersionID": int_or_none(fam.get("highVersionID")),
            "programming": dict(prog.attrib) if prog is not None else None,
            "models": models,
        })
    return families, variables


def write_sqlite(dst, out):
    import sqlite3
    import zlib
    if os.path.exists(dst):
        os.remove(dst)
    c = sqlite3.connect(dst)
    c.executescript("""
        CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT);
        CREATE TABLE vars (file TEXT PRIMARY KEY, data BLOB NOT NULL);
        CREATE TABLE family (id INTEGER PRIMARY KEY, file TEXT NOT NULL, mfg TEXT, family TEXT,
                             comment TEXT, programming TEXT, models TEXT NOT NULL, search TEXT NOT NULL);
    """)
    c.execute("INSERT INTO meta VALUES ('source', ?)", (out["source"],))
    c.execute("CREATE TABLE mfg (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
    c.executemany("INSERT OR IGNORE INTO mfg VALUES (?, ?)", out.get("mfg_ids", []))
    for f, vs in out["variables"].items():
        c.execute("INSERT INTO vars VALUES (?, ?)",
                  (f, zlib.compress(json.dumps(vs, ensure_ascii=False, separators=(",", ":")).encode(), 9)))
    for i, fam in enumerate(out["families"], 1):
        names = " ".join(m.get("model") or "" for m in fam["models"])
        search = " ".join(filter(None, [fam["mfg"], fam["family"], names])).lower()
        c.execute("INSERT INTO family VALUES (?,?,?,?,?,?,?,?)",
                  (i, fam["file"], fam["mfg"], fam["family"], fam["comment"],
                   json.dumps(fam["programming"]), json.dumps(fam["models"], ensure_ascii=False), search))
    c.commit()
    c.execute("VACUUM")
    c.close()


def main():
    src, dst = sys.argv[1], sys.argv[2]
    src = os.path.abspath(src)
    lib, varsets, errors = [], {}, []
    for dirpath, _, files in os.walk(src):
        for f in sorted(files):
            if not f.endswith(".xml"):
                continue
            p = os.path.join(dirpath, f)
            try:
                fams, variables = convert_file(p, src) or ([], [])
                if fams:
                    varsets[fams[0]["file"]] = variables
                    lib.extend(fams)
            except Exception as e:  # noqa: BLE001
                errors.append(f"{p}: {e}")
    mfg_ids = []
    idx = os.path.join(os.path.dirname(src), "decoderIndex.xml")
    if os.path.exists(idx):
        for mf in etree.parse(idx).iter("manufacturer"):
            n = int_or_none(mf.get("mfgID"))
            if n is not None and mf.get("mfg") and n != 999:
                mfg_ids.append((n, mf.get("mfg")))
    lib.sort(key=lambda x: ((x["mfg"] or "").lower(), (x["family"] or "").lower()))
    out = {
        "source": "JMRI xml/decoders (https://github.com/JMRI/JMRI), GPL v2",
        "families": lib,
        "mfg_ids": mfg_ids,
        "variables": varsets,  # proměnné podle souboru (sdílené rodinami ze stejného souboru)
    }
    if dst.endswith(".db"):
        write_sqlite(dst, out)
    else:
        with open(dst, "w", encoding="utf-8") as fh:
            json.dump(out, fh, ensure_ascii=False, separators=(",", ":"))
    nm = sum(len(f["models"]) for f in lib)
    print(f"rodin: {len(lib)}, modelů: {nm}, chyb: {len(errors)}")
    for e in errors[:20]:
        print("  ", e)


if __name__ == "__main__":
    main()
