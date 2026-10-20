"""Wyciaga Thumbnail.png z plikow .pk2 (Creo Elements/Direct Modeling Express = ZIP)
i buduje galerie index.html. Uzycie: python pk2_miniatury.py [folder_z_pk2] [folder_wyjsciowy]
Pliki .pk2 sa tylko czytane."""
import sys, zipfile, html, pathlib
src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
out = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else pathlib.Path(__file__).parent)
(out / "png").mkdir(parents=True, exist_ok=True)
items = []
for f in sorted(src.rglob("*.pk2"), key=lambda p: p.stat().st_mtime, reverse=True):
    try:
        with zipfile.ZipFile(f) as z:
            png = z.read("Thumbnail.png")
    except Exception as e:
        print("pomijam", f.name, e); continue
    name = f.stem + ".png"
    (out / "png" / name).write_bytes(png)
    items.append((f, name))
cells = "".join(
    f'<figure><img src="png/{html.escape(n)}" width="200" height="200"><figcaption>{html.escape(f.name)}<br><small>{f.stat().st_size//1024} kB, {pathlib.Path(f).stat().st_mtime and __import__("datetime").datetime.fromtimestamp(f.stat().st_mtime):%Y-%m-%d}</small></figcaption></figure>'
    for f, n in items)
(out / "index.html").write_text(
    '<!doctype html><meta charset="utf-8"><title>Miniatury PK2</title>'
    '<style>body{font:14px sans-serif;background:#222;color:#ddd;display:flex;flex-wrap:wrap;gap:12px;padding:12px}'
    'figure{margin:0;background:#fff;color:#222;padding:6px;width:212px;text-align:center}img{display:block}</style>' + cells,
    encoding="utf-8")
print(len(items), "miniatur ->", out / "index.html")
