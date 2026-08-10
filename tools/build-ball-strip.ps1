# Build docs/ball-colors.png -- a labelled grid of every ball sprite --
# from the full battle screenshots in docs/.
#
#   powershell -File tools\build-ball-strip.ps1
#
# Lives at the repo root, so it is NOT inside either mod folder and never
# ships in a release zip (the workflow zips from INSIDE kanto_balls/ and
# shop_events/).
#
# HOW IT FINDS THE BALL.  The ball sits at a different height in every
# screenshot -- it tracks the enemy HUD, which moves -- so a fixed crop box
# does not work.  Each ball is located by its own BODY COLOUR instead,
# taken from kanto_balls' COLORS table, and the crop is centred on the
# MEDIAN matching pixel.  Median, not mean: a few stray matching pixels
# elsewhere on screen would drag a mean off target.
#
# Each ball lists its 0.3.5+ colour first and its pre-0.3.5 colour as a
# fallback, so this works against screenshots taken either side of that
# retune.  NEST, GS and BEAST changed; the rest did not.

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$out  = Join-Path $docs "ball-colors.png"

$balls = @(
  @{ n = "NEST";   f = "nest-ball.png";   now = @(80,200,128);  old = @(132,172,84) },
  @{ n = "MOON";   f = "moon-ball.png";   now = @(60,68,128);   old = @(60,68,128)  },
  @{ n = "HEAL";   f = "heal-ball.png";   now = @(232,160,196); old = @(232,160,196)},
  @{ n = "FAST";   f = "fast-ball.png";   now = @(232,148,48);  old = @(232,148,48) },
  @{ n = "MIRROR"; f = "mirror-ball.png"; now = @(168,180,200); old = @(168,180,200)},
  @{ n = "SILPH";  f = "silph-ball.png";  now = @(120,88,168);  old = @(120,88,168) },
  @{ n = "GS";     f = "gs-ball.png";     now = @(248,224,160); old = @(224,188,76) },
  @{ n = "BEAST";  f = "beast-ball.png";  now = @(16,24,56);    old = @(44,72,148)  }
)

$CROP  = 116   # source pixels around the ball
$LIFT  = 10    # nudge up so the enemy HUD underline falls outside the box
$CELL  = 200   # rendered cell size
$LABEL = 34
$COLS  = 4

function Find-Ball($bmp, $rgb) {
  $xs = New-Object System.Collections.ArrayList
  $ys = New-Object System.Collections.ArrayList
  # bottom third is the text box; nothing we want is down there
  $ymax = [int]($bmp.Height * 0.68)
  for ($y = 0; $y -lt $ymax; $y += 2) {
    for ($x = 0; $x -lt $bmp.Width; $x += 2) {
      $p = $bmp.GetPixel($x, $y)
      $d = [Math]::Abs($p.R - $rgb[0]) + [Math]::Abs($p.G - $rgb[1]) + [Math]::Abs($p.B - $rgb[2])
      if ($d -le 40) { [void]$xs.Add($x); [void]$ys.Add($y) }
    }
  }
  if ($xs.Count -lt 40) { return $null }
  $sx = @($xs | Sort-Object); $sy = @($ys | Sort-Object)
  $mid = [int]($sx.Count / 2)
  return @{ x = $sx[$mid]; y = $sy[$mid]; hits = $xs.Count }
}

$rows = [Math]::Ceiling($balls.Count / $COLS)
$W = $COLS * $CELL
$H = $rows * ($CELL + $LABEL)
$canvas = New-Object System.Drawing.Bitmap($W, $H)
$gfx = [System.Drawing.Graphics]::FromImage($canvas)
$gfx.Clear([System.Drawing.Color]::White)
$gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gfx.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$font  = New-Object System.Drawing.Font("Consolas", 15, [System.Drawing.FontStyle]::Bold)
$brush = [System.Drawing.Brushes]::Black
$fmt   = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center

$i = 0
foreach ($ball in $balls) {
  $path = Join-Path $docs $ball.f
  if (-not (Test-Path $path)) { Write-Output "MISSING $($ball.f)"; $i++; continue }
  $bmp = New-Object System.Drawing.Bitmap($path)

  $hit = Find-Ball $bmp $ball.now
  $which = "current"
  if ($null -eq $hit) { $hit = Find-Ball $bmp $ball.old; $which = "pre-0.3.5" }
  if ($null -eq $hit) {
    Write-Output "$($ball.n): NOT FOUND -- is $($ball.f) the right ball?"
    $bmp.Dispose(); $i++; continue
  }
  Write-Output "$($ball.n): $which palette, found at $($hit.x),$($hit.y) ($($hit.hits) px)"

  $sx = [Math]::Max(0, [Math]::Min($bmp.Width  - $CROP, $hit.x - [Math]::Floor($CROP / 2)))
  $sy = [Math]::Max(0, [Math]::Min($bmp.Height - $CROP, $hit.y - [Math]::Floor($CROP / 2) - $LIFT))
  $src = New-Object System.Drawing.Rectangle($sx, $sy, $CROP, $CROP)

  # [int] in PowerShell rounds to NEAREST (banker's), so [int](3/4) is 1.
  # A grid index needs Floor, or cell 3 lands on row 1 and the last two
  # cells fall off the canvas entirely.
  $col = $i % $COLS
  $row = [Math]::Floor($i / $COLS)
  $dst = New-Object System.Drawing.Rectangle(($col * $CELL), ($row * ($CELL + $LABEL)), $CELL, $CELL)
  $gfx.DrawImage($bmp, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)

  $gfx.DrawString($ball.n, $font, $brush,
    (($col * $CELL) + ($CELL / 2)), (($row * ($CELL + $LABEL)) + $CELL + 6), $fmt)

  $bmp.Dispose()
  $i++
}

$canvas.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose(); $canvas.Dispose(); $font.Dispose()
Write-Output "wrote $out ($W x $H)"
