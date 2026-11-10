-- REQUESTS 740 engine render: the Ball Case and Crystal View, drawn by
-- kanto_balls itself in the real engine (lab copy, VANILLA look).
-- Run through lab/render740.py.  Nothing here ships.
return function(game)
 local H=assert(loadfile(os.getenv('MOD_LAB_ROOT')..'/common.lua'))()(game)
 love.window.setMode(640,576);H.wait(10)
 H.seed('QUILAVA',16)
 H.enter('NEW_BARK_TOWN',6,6)
 local inv=game.save.inventory
 inv.GRN_APRICORN=0;inv.YLW_APRICORN=1;inv.BLK_APRICORN=2;inv.WHT_APRICORN=3
 inv.PNK_APRICORN=1;inv.RED_APRICORN=0;inv.BLU_APRICORN=1
 local Screens=require('src.ui.Screens')
 local function open(id,opts)
  game.stack:clear();H.wait(10)
  local ok,err=pcall(Screens.push,game,id,opts)
  H.check(ok,'pushed '..id..' '..tostring(err))
  H.wait(40)
 end
 local function taps(list)for _,k in ipairs(list)do H.tap(k);H.wait(12)end end
 open('KbBallCase')
 H.shot('01-case')
 taps({'down','down'});H.shot('02-case-snare')
 taps({'a'});H.shot('03-case-ask')
 taps({'b','down','down'});H.shot('04-case-cradle')
 taps({'down','down'});H.shot('05-case-stow')
 taps({'up','up','up','up','up','up','a'});H.shot('06-case-short')
 taps({'b'})
 local mon=game.save.party[1]
 open('KbCrystalReview',{record={game=game,mon=mon}})
 H.shot('07-crystal')
 taps({'down','a'});H.shot('08-crystal-release')
 taps({'b','down','a'});H.shot('09-crystal-moves')
 taps({'b'})
 game.stack:clear();H.wait(5)
 H.finish()
end
