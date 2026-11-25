"""Desk pick, 2026-11-24: the four shortened round-2 ball names in the real PACK.

    python lab/rendernames.py [--lab C:/Users/dwitt/tmc-worktrees/balls-lab]

Same lab and runner as render740.py; driver lab/uinames.lua.  Nothing here ships.
"""
from pathlib import Path
import argparse, os, shutil, sys, time
sys.path.insert(0, r"C:\Users\dwitt\gen1recomp-work\exchange")
from offscreen import popen_hidden
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
LOVE = Path.home() / 'Documents/Codex/2026-09-04/wo/work/love/lovec.exe'
SHOTS = [('01-set', 'Option 1'), ('02-set', 'Option 2')]

ap = argparse.ArgumentParser()
ap.add_argument('--lab', default=str(Path.home() / 'tmc-worktrees/balls-lab'))
ap.add_argument('--out', default=str(REPO.parent / 'exchange/outbox/too-many-balls/names-0.9.1'))
args = ap.parse_args()
lab, out = Path(args.lab), Path(args.out)
out.mkdir(parents=True, exist_ok=True)
run = lab / 'runs' / time.strftime('%Y%m%d-%H%M%S')
run.mkdir(parents=True)
mod = lab / 'game/mods/kanto_balls'
if mod.exists():
    shutil.rmtree(mod)
shutil.copytree(REPO / 'kanto_balls', mod, ignore=shutil.ignore_patterns('tests'))
env = {k: v for k, v in os.environ.items() if not k.startswith('POKEPORT_')}
env.update(POKEPORT_IDENTITY='balls-lab', POKEPORT_GAME='crystal', POKEPORT_SPEED='4',
           MOD_LAB_FILM='0', POKEPORT_DRIVER=str(HERE / 'uinames.lua'), MOD_LAB_CASE='uinames',
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

S, PAD, HEAD = 3, 16, 36
font = ImageFont.truetype('arial.ttf', 22)
w, h = 160 * S, 144 * S
sheet = Image.new('RGB', (PAD + len(SHOTS) * (w + PAD), PAD + h + HEAD + PAD), (40, 40, 44))
d = ImageDraw.Draw(sheet)
for k, (tag, label) in enumerate(SHOTS):
    x, y = PAD + k * (w + PAD), PAD
    d.text((x, y), label, fill=(240, 240, 240), font=font)
    im = Image.open(run / f'{tag}.png').convert('RGB')
    im = im.resize((160, 144), Image.NEAREST) if im.size != (160, 144) else im
    sheet.paste(im.resize((w, h), Image.NEAREST), (x, y + HEAD))
dest = out / 'names-pack.png'
sheet.save(dest)
print(dest)
