"""REQUESTS 740: render the Ball Case and Crystal View in the real engine.

    python lab/render740.py [--lab C:/Users/dwitt/tmc-worktrees/balls-lab] [--out <dir>]

The lab is a copy of UI Theme's lab with engine/src (v0.4.0) over its src; this
script installs kanto_balls from this repo into it, runs lab/ui740.lua on a hidden
desktop and writes a labelled contact sheet. Nothing here ships.
"""
from pathlib import Path
import argparse, os, shutil, sys, time
sys.path.insert(0, r"C:\Users\dwitt\gen1recomp-work\exchange")
from offscreen import popen_hidden
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
LOVE = Path.home() / 'Documents/Codex/2026-09-04/wo/work/love/lovec.exe'
SHOTS = [('01-case', 'Ball Case'), ('02-case-snare', 'apricorns met'),
         ('03-case-ask', 'Make this ball?'), ('04-case-cradle', 'four apricorns'),
         ('05-case-stow', 'STOW ALL (scrolled)'), ('06-case-short', 'not enough'),
         ('07-crystal', 'Crystal View'), ('08-crystal-release', 'RELEASE asks'),
         ('09-crystal-moves', 'MOVES page')]

ap = argparse.ArgumentParser()
ap.add_argument('--lab', default=str(Path.home() / 'tmc-worktrees/balls-lab'))
ap.add_argument('--out', default=str(REPO.parent / 'exchange/outbox/too-many-balls/740'))
args = ap.parse_args()
lab, out = Path(args.lab), Path(args.out)
out.mkdir(parents=True, exist_ok=True)
run = lab / 'runs' / time.strftime('%Y%m%d-%H%M%S')
run.mkdir(parents=True)
mod = lab / 'game/mods/kanto_balls'
if mod.exists():
    shutil.rmtree(mod)
mod.mkdir()
for name in ['main.lua', 'manifest.json']:
    shutil.copy2(REPO / 'kanto_balls' / name, mod / name)
env = {k: v for k, v in os.environ.items() if not k.startswith('POKEPORT_')}
env.update(POKEPORT_IDENTITY='balls-lab', POKEPORT_GAME='crystal', POKEPORT_SPEED='4',
           MOD_LAB_FILM='0', POKEPORT_DRIVER=str(HERE / 'ui740.lua'), MOD_LAB_CASE='ui740',
           MOD_LAB_ROOT=str(lab), MOD_LAB_RESULT=str(run / 'result.txt'), MOD_LAB_OUTPUT=str(run),
           MOD_LAB_CAPTURE='1')
with (run / 'engine.log').open('w', encoding='utf-8') as log:
    p = popen_hidden([LOVE, lab / 'game'], cwd=lab / 'game', env=env, stdout=log)
    code = p.wait(timeout=400)
res = (run / 'result.txt').read_text() if (run / 'result.txt').exists() else 'FAIL no result'
print(run, code, res.splitlines()[0])
if not res.startswith('PASS'):
    print(res)
    raise SystemExit(1)

S, PAD, HEAD, N = 3, 16, 36, 3
font = ImageFont.truetype('arial.ttf', 22)
w, h = 160 * S, 144 * S
rows = (len(SHOTS) + N - 1) // N
sheet = Image.new('RGB', (PAD + N * (w + PAD), PAD + rows * (h + HEAD + PAD)), (40, 40, 44))
d = ImageDraw.Draw(sheet)
for k, (tag, label) in enumerate(SHOTS):
    x, y = PAD + (k % N) * (w + PAD), PAD + (k // N) * (h + HEAD + PAD)
    d.text((x, y), label, fill=(240, 240, 240), font=font)
    im = Image.open(run / f'{tag}.png').convert('RGB')
    im = im.resize((160, 144), Image.NEAREST) if im.size != (160, 144) else im
    sheet.paste(im.resize((w, h), Image.NEAREST), (x, y + HEAD))
dest = out / 'too-many-balls-740-engine-1.png'
sheet.save(dest)
print(dest)
