-- Name pick for the four too-long round-2 balls (Desk, 2026-11-24): the real
-- PACK, BALL pocket, drawn by the engine with each candidate name set.
-- Run through lab/rendernames.py.  Nothing here ships.
return function(game)
 local H=assert(loadfile(os.getenv('MOD_LAB_ROOT')..'/common.lua'))()(game)
 love.window.setMode(640,576);H.wait(10)
 H.seed('QUILAVA',16)
 H.enter('NEW_BARK_TOWN',6,6)
 local inv=game.save.inventory
 local Bag=require('src.inventory.Bag')
 for id in pairs(inv) do Bag.remove(game.save,id,inv[id]) end
 local IDS={'BOOMERANG_BALL','BOMB_BOMB_BALL','MAGMA_GREAT_BALL','AQUA_GREAT_BALL'}
 for _,id in ipairs(IDS) do Bag.add(game.save,id,5,game.data) end
 local SETS={
  -- Round 2 (Desk, 2026-11-24 "not the magma aqua names"): new MAGMA/AQUA
  -- approaches; BOOMERANG/BOMB-BOMB asked again beside them.
  {'BOOMRANGBALL','BOMBOMB BALL','GREAT MAGMA','GREAT AQUA'},
  {'BOOMER BALL','BOMB BALL','MAGMABALL II','AQUA BALL II'},
 }
 local Screens=require('src.ui.Screens')
 for n,set in ipairs(SETS) do
  for i,id in ipairs(IDS) do game.data.items[id].name=set[i] end
  game.stack:clear();H.wait(10)
  local ok,err=pcall(function()
   local Pack=require('src.ui.gen2.PackMenu')
   game.stack:push(Pack.new(game,{pocket='BALL'}))
  end)
  H.check(ok,'pushed pack '..tostring(err))
  H.wait(40)
  H.shot(('%02d-set'):format(n))
 end
 game.stack:clear();H.wait(5)
 H.finish()
end
