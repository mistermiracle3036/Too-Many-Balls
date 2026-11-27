-- pc_nolimit.lua -- the item PC holds everything (Gold, Silver, Crystal).
--
-- Developer, via the TMC Question Desk 2026-11-27 (REQUESTS 1220): picked
-- "No limit, Too Many Balls owns it"; VANILLA BAG LIMITS turns it off with
-- the PACK limits.  So a full PC never happens and a free ball is never
-- dropped.
--
-- ENGINE FACTS (v0.4.0, read 2026-11-27)
--   * The PC's own DEPOSIT is ItemPcMenu:pcAdd (src/ui/gen2/ItemPcMenu.lua
--     289-297), capped by a LOCAL PC_ITEM_CAPACITY = 50 stacks, so it cannot
--     be raised through data; it is wrapped here.  It stores one count per
--     id (pc[id] = held + qty), and ItemPcMenu:rebuild draws any count as
--     99-stacks with a scrolling list (VISIBLE_ROWS 4) -- nothing caps rows.
--   * Every other PC add (src/inventory/Bag.lua Bag.pcAdd: Mom's shopping,
--     lib/item_overflow.lua) goes through Bag.addTo with a cap, and on Gen 2
--     refuses old + qty > 99 for one id.  Wrapped here: the cap is lifted,
--     and a refused add onto an id already in the PC just grows its count,
--     the same shape ItemPcMenu:pcAdd writes.
--   * The game's own save (SaveSerializer) has no limit.  The launcher's
--     export to a cartridge .sav (SaveConvert -> Gen2Save writeStacks,
--     1499-1500) REFUSES a PC over 50 stacks and says so; nothing is cut.
--   * GEN 1 IS NOT COVERED, deliberately: Red's export (GenSave.lua
--     encodeItems, :977 math.min(#rows, 50)) silently TRUNCATES the PC at 50,
--     which would lose items from an exported save.  Red keeps the 50.
--
-- Stash-originals under our own key on each module (CLAUDE.md hard rule).

local Bag = require("src.inventory.Bag")
local ItemPcMenu = require("src.ui.gen2.ItemPcMenu")

local M = {}

function M.install(enabled)
  ItemPcMenu._kbPcOriginals = ItemPcMenu._kbPcOriginals
    or { pcAdd = ItemPcMenu.pcAdd }
  Bag._kbPcOriginals = Bag._kbPcOriginals or { pcAdd = Bag.pcAdd }
  local vanillaMenuAdd = ItemPcMenu._kbPcOriginals.pcAdd
  local vanillaBagPcAdd = Bag._kbPcOriginals.pcAdd

  if not enabled then
    -- Restore rather than skip: a reload with VANILLA BAG LIMITS newly ON
    -- must not leave the old wrapper live.
    ItemPcMenu.pcAdd = vanillaMenuAdd
    Bag.pcAdd = vanillaBagPcAdd
    return false
  end

  ItemPcMenu.pcAdd = function(self, id, qty)
    if vanillaMenuAdd(self, id, qty) then return true end
    local save = self and self.save
    if not save or type(id) ~= "string" or type(qty) ~= "number" or qty < 1 then
      return false
    end
    save.pcItems = save.pcItems or {}
    save.pcItems[id] = (save.pcItems[id] or 0) + qty
    return true
  end

  Bag.pcAdd = function(save, id, qty, data, _cap)
    if vanillaBagPcAdd(save, id, qty, data, math.huge) then return true end
    qty = qty or 1
    if not save or type(id) ~= "string" or type(qty) ~= "number" or qty < 1 then
      return false
    end
    local pc = save.pcItems
    local old = pc and pc[id]
    -- Only the per-id 99 refusal is left once the cap is huge, and that
    -- only happens when the id is already there (so it is already ordered).
    if type(old) ~= "number" or old < 1 then return false end
    pc[id] = old + qty
    return true
  end
  return true
end

return M
