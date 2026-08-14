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

# Is this pixel UI ink (the black HUD lines, borders and text)?
#
# Threshold picked from measured pixels, after two wrong guesses:
#
#   "all channels < 60"        called BEAST's whole body ink once its colour
#                              became 16,24,56 at 0.3.5. Fill refused to
#                              start; the grid rendered BEAST at 0x0.
#   "< 60 AND spread < 20"     fixed that but stopped the downward walk on
#                              anti-aliasing INSIDE the ball -- the navy/
#                              yellow boundary rows in beast-ball.png are
#                              (21,24,39) and (28,25,16), dark and nearly
#                              neutral. BEAST came out clipped in half.
#
# What actually separates them is plain darkness:
#
#   HUD ledge (beast-ball.png y=788+)  (0,0,0) .. (0,2,5)     max <= 5
#   HUD ledge top row (fast-ball.png)  (21,0,0)               max = 21
#   Darkest pixel inside a ball        (28,25,16)             max = 28
#   BEAST body                         (18,23,53)             max = 53
#
# 25 sits in the gap between the ledge's anti-aliased top row and the
# darkest pixel any ball actually contains. Saturation is not consulted at
# all -- it was a red herring.
function Test-IsInk($p) {
  $max = [Math]::Max($p.R, [Math]::Max($p.G, $p.B))
  return ($max -lt 25)
}

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$out  = Join-Path $docs "ball-colors.png"

$balls = @(
  @{ n = "PREMIER";f = "premier-ball.png";now = @(240,240,240); old = @(240,240,240)},
  @{ n = "NEST";   f = "nest-ball.png";   now = @(80,200,128);  old = @(132,172,84) },
  @{ n = "MOON";   f = "moon-ball.png";   now = @(60,68,128);   old = @(60,68,128)  },
  @{ n = "HEAL";   f = "heal-ball.png";   now = @(232,160,196); old = @(232,160,196)},
  @{ n = "FAST";   f = "fast-ball.png";   now = @(232,148,48);  old = @(232,148,48) },
  @{ n = "MIRROR"; f = "mirror-ball.png"; now = @(168,180,200); old = @(168,180,200)},
  @{ n = "SILPH";  f = "silph-ball.png";  now = @(120,88,168);  old = @(120,88,168) },
  @{ n = "GS";     f = "gs-ball.png";     now = @(248,224,160); old = @(224,188,76) },
  @{ n = "BEAST";  f = "beast-ball.png";  now = @(16,24,56);    old = @(44,72,148)  },
  # The craft tier, shot on GOLD -- they cannot be obtained on Red at all,
  # since Kurt and the apricorns are Johto's.  Colours are the same `body`
  # values as Gen 1: on Gold the body tone is pal2 of the same palette.
  @{ n = "SNARE";  f = "snare-ball.png";  now = @(56,104,72);   old = @(56,104,72)  },
  # CATALYST gets NO fallback, deliberately, and it is the one ball that
  # must not have one.  The `old` colour here would be the pre-0.4.23
  # stone grey -- the exact look that was replaced BECAUSE it read as a
  # second CRADLE on device.  Accepting it would quietly publish the bug.
  #
  # This is not hypothetical: the first catalyst-ball.png supplied was
  # captured on a pre-0.4.23 build and the script resolved it through the
  # fallback, reporting "pre-0.3.5 palette" -- a line easy to read past.
  # With `old` equal to `now` a stale screenshot instead prints
  # "NOT FOUND" and the cell is skipped, which cannot be missed.
  @{ n = "CATALYST";f= "catalyst-ball.png";now= @(200,72,208);  old = @(200,72,208) },
  @{ n = "DRIFT";  f = "drift-ball.png";  now = @(152,200,232); old = @(152,200,232)},
  @{ n = "CRADLE"; f = "cradle-ball.png"; now = @(184,168,216); old = @(184,168,216)}
  # KECLEON is deliberately absent: on Gold it has no fixed colour to
  # search for -- it takes the target's palette, which is the whole point
  # of the ball. It gets the paired before/after shots in the READMEs
  # instead, which show the effect far better than one grid cell could.
)

# Source pixels around the ball.  DERIVED PER BALL, not fixed, because the
# ball sprite is not the same size in every screenshot: the Gen 1 captures
# measure ~100px across and the Gold ones ~60px.  A single crop box made
# the craft tier render visibly shrunken next to the Kanto balls -- same
# cell, half the ball.  Scaling the crop to each ball's own flood-filled
# bounding box makes every ball fill the same fraction of its cell, and
# DrawImage does the rest.  CROP_MIN keeps a tiny detection from blowing
# a ball up to fill the frame.
$CROP_SCALE = 1.35
$CROP_MIN   = 72
$CROP_FALLBACK = 116   # when the fill returned nothing to measure
$LIFT  = 10    # nudge up so the enemy HUD underline falls outside the box
$CELL  = 200   # rendered cell size
$LABEL = 34
$COLS  = 4

# Centre on the ball's BOUNDING BOX via FLOOD FILL from the colour-match
# seed, not a same-window any-pixel scan.
#
# Tried the any-pixel version first: "not background, not ink" anywhere in
# a window around the seed. It worked for eight balls and broke on the
# ninth -- PREMIER BALL's body is 240,240,240, close enough to white that
# telling it apart from the page background needs a loose threshold, but
# a loose threshold also waves through the HP bar and text box chrome
# sitting in the SAME window, which are similarly near-white and are not
# the ball at all. The window has no notion of "these pixels belong to
# the same object."
#
# Flood fill does. Growing outward from the seed through only CONNECTED
# non-background, non-ink pixels cannot leak into a separate UI element
# even if that element happens to be a similar shade -- it is walled off
# by an actual gap of true-white background or a black border, same as it
# would be to a person looking at the screenshot.
function Get-BallCentre($bmp, $seedX, $seedY) {
  $win = 70   # half-size of the area flood fill is allowed to explore
  $x0 = [Math]::Max(0, $seedX - $win); $x1 = [Math]::Min($bmp.Width  - 1, $seedX + $win)
  $y0 = [Math]::Max(0, $seedY - $win); $y1 = [Math]::Min($bmp.Height - 1, $seedY + $win)

  function TestFillable($bmp, $x, $y, $x0, $x1, $y0, $y1) {
    if ($x -lt $x0 -or $x -gt $x1 -or $y -lt $y0 -or $y -gt $y1) { return $false }
    $p = $bmp.GetPixel($x, $y)
    $bg = ($p.R -gt 250 -and $p.G -gt 250 -and $p.B -gt 250)
    return (-not $bg -and -not (Test-IsInk $p))
  }

  if (-not (TestFillable $bmp $seedX $seedY $x0 $x1 $y0 $y1)) {
    return @{ x = $seedX; y = $seedY; w = 0; h = 0; maxY = $seedY }
  }

  # Two PARALLEL stacks of scalar ints, not one stack of int-pair arrays.
  # A Stack[int[]] here kept degrading into nested arrays -- @($x+1,$y)
  # built from an $x that PowerShell had already boxed as System.Object[]
  # on a previous pop, and once one entry nests the whole stack does,
  # since Pop returns whatever got pushed. Two flat stacks cannot nest.
  $visited = New-Object 'System.Collections.Generic.HashSet[int]'
  $stackX = New-Object 'System.Collections.Generic.Stack[int]'
  $stackY = New-Object 'System.Collections.Generic.Stack[int]'
  $stackX.Push([int]$seedX); $stackY.Push([int]$seedY)
  $minX = $seedX; $maxX = $seedX; $minY = $seedY; $maxY = $seedY; $n = 0
  $stride = $bmp.Width

  while ($stackX.Count -gt 0) {
    $x = $stackX.Pop(); $y = $stackY.Pop()
    $key = $y * $stride + $x
    if ($visited.Contains($key)) { continue }
    [void]$visited.Add($key)
    if (-not (TestFillable $bmp $x $y $x0 $x1 $y0 $y1)) { continue }

    $n++
    if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
    if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }

    # 8-connected: pixel art anti-aliasing often only touches diagonally
    foreach ($dx in -1..1) {
      foreach ($dy in -1..1) {
        if ($dx -eq 0 -and $dy -eq 0) { continue }
        $stackX.Push([int]($x + $dx)); $stackY.Push([int]($y + $dy))
      }
    }
  }

  if ($n -lt 40) { return @{ x = $seedX; y = $seedY; w = 0; h = 0; maxY = $seedY } }
  return @{ x = [int](($minX + $maxX) / 2); y = [int](($minY + $maxY) / 2);
            w = ($maxX - $minX + 1); h = ($maxY - $minY + 1); maxY = $maxY }
}

# The ball's last row, found by walking DOWN the ball's centre column until
# the enemy-name HUD ledge starts.
#
# The flood fill's maxY cannot be used for this. The ledge is notched, and
# the notch gaps are neither background-white nor ink-black, so the fill
# crawls THROUGH them and reports a bottom two or three rows inside the
# ledge -- which is exactly the black bar that kept surviving every attempt
# to pad it away. Measured on fast-ball.png: ball ends at y=570, ledge
# starts at 571, fill claimed 573.
#
# Walking one column is immune to that: the ledge is solid at the centre.
# The search is bounded to 70px below centre -- a little past the ball's own
# radius (~50px). Unbounded, a screenshot whose ball does NOT sit directly on
# a ledge keeps walking until it hits HUD *text* far below and crops that in
# instead; silph-ball.png and beast-ball.png both do this. Past the bound,
# fall back to the fill's own bottom minus the 3 rows it habitually
# overshoots through the ledge notches.
function Get-BallBottom($bmp, $cx, $startY, $fallback) {
  $limit = [Math]::Min($bmp.Height - 1, $startY + 70)
  for ($y = $startY; $y -le $limit; $y++) {
    if (Test-IsInk $bmp.GetPixel($cx, $y)) { return ($y - 1) }
  }
  return ($fallback - 3)
}

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
  if (-not (Test-Path $path)) { Write-Output "MISSING $($ball.f)"; continue }
  $bmp = New-Object System.Drawing.Bitmap($path)

  $hit = Find-Ball $bmp $ball.now
  $which = "current"
  if ($null -eq $hit) { $hit = Find-Ball $bmp $ball.old; $which = "pre-0.3.5" }
  if ($null -eq $hit) {
    Write-Output "$($ball.n): NOT FOUND -- is $($ball.f) the right ball?"
    $bmp.Dispose(); continue
  }
  $c = Get-BallCentre $bmp $hit.x $hit.y
  Write-Output ("{0}: {1} palette, centre {2},{3}  sprite {4}x{5}" -f `
    $ball.n, $which, $c.x, $c.y, $c.w, $c.h)

  # Per-ball crop, from the ball's own measured size (see CROP_SCALE).
  $span = [Math]::Max($c.w, $c.h)
  if ($span -lt 1) {
    $CROP = $CROP_FALLBACK
  } else {
    $CROP = [int][Math]::Max($CROP_MIN, [Math]::Round($span * $CROP_SCALE))
  }
  $CROP = [Math]::Min($CROP, [Math]::Min($bmp.Width, $bmp.Height))

  # Horizontal: still centred on the bbox centre, as before.
  $sx = [Math]::Max(0, [Math]::Min($bmp.Width - $CROP, $c.x - [Math]::Floor($CROP / 2)))
  # Vertical: anchored to the ball's OWN bottom edge (c.maxY), not centred.
  # The enemy HUD ledge (the black bar with notches) sits immediately
  # below the ball with no gap, so any crop that extends past maxY grabs
  # a slice of it -- centring the square on the ball's midpoint always
  # overshot by a few px. Anchoring the crop's bottom edge just past maxY
  # and letting it extend UPWARD instead (into plain background) keeps the
  # ball's own pixels intact and excludes the ledge entirely.
  # Bottom edge = the row just above the HUD ledge. The crop covers rows
  # sy .. sy+CROP-1, so sBottom is one past the last row we want.
  $ballBottom = Get-BallBottom $bmp $c.x $c.y $c.maxY
  $sBottom = [Math]::Min($bmp.Height, $ballBottom + 1)
  $sy = [Math]::Max(0, $sBottom - $CROP)
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

# Trim to the rows that actually rendered.  The canvas is sized from the
# ball LIST, but a ball whose screenshot is missing or stale draws nothing
# and no longer consumes a cell -- so the list can be a whole row longer
# than the output, leaving a band of white at the bottom that looks like a
# rendering fault rather than a skipped ball.
$usedRows = [Math]::Max(1, [Math]::Ceiling($i / $COLS))
$usedH = $usedRows * ($CELL + $LABEL)
if ($usedH -lt $H) {
  $trimmed = New-Object System.Drawing.Bitmap($W, $usedH)
  $tg = [System.Drawing.Graphics]::FromImage($trimmed)
  $tg.DrawImage($canvas, 0, 0)
  $tg.Dispose()
  $canvas.Dispose(); $canvas = $trimmed
  $H = $usedH
}

$canvas.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose(); $canvas.Dispose(); $font.Dispose()
Write-Output "wrote $out ($W x $H) -- $i balls"
