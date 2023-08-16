local extension = Package:new("formation")
extension.extensionName = "hegemony"

Fk:loadTranslationTable{
  ["formation"] = "君临天下·阵",
  ["ld"] = "君临",
}

local function noKingdom(player)
  return player.general == "anjiang" and player.deputyGeneral == "anjiang"
end

local function sameKingdom(player, target) --isFriendWith
  if player == target then return true end
  return player.kingdom == target.kingdom and player.kingdom ~= "wild" and not (noKingdom(player) or noKingdom(target)) --野心家拉拢……
end

local jiangfei = General(extension, "ld__jiangwanfeiyi", "shu", 3)
local shengxi = fk.CreateTriggerSkill{
  name = "ld__shengxi",
  anim_type = "drawcard",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return player == target and player:hasSkill(self.name) and player.phase == Player.Finish and 
      #player.room.logic:getEventsOfScope(GameEvent.ChangeHp, 1, function (e)
        local damage = e.data[5]
        if damage and target == damage.from then
          return true
        end
      end, Player.HistoryTurn) == 0
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(2, self.name)
  end,
}

local shoucheng = fk.CreateTriggerSkill{
  name = "shoucheng",
  anim_type = "support",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    for _, move in ipairs(data) do
      if move.from then
        local from = player.room:getPlayerById(move.from)
        if from:isKongcheng() and sameKingdom(from, player) then
          for _, info in ipairs(move.moveInfo) do
            if info.fromArea == Card.PlayerHand then
              return true
            end
          end
        end
      end
    end
  end,
  on_trigger = function(self, event, target, player, data)
    local targets = {}
    local room = player.room
    for _, move in ipairs(data) do
      if move.from then
        local from = room:getPlayerById(move.from)
        if from:isKongcheng() and sameKingdom(from, player) then
          for _, info in ipairs(move.moveInfo) do
            if info.fromArea == Card.PlayerHand then
              table.insertIfNeed(targets, from.id)
            end
          end
        end
      end
    end
    room:sortPlayersByAction(targets)
    for _, p in ipairs(targets) do
      local to = room:getPlayerById(p)
      if to.dead or not player:hasSkill(self.name) then break end
      self:doCost(event, p, player, nil)
    end
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#shoucheng-draw::" .. target)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, {target})
    room:getPlayerById(target):drawCards(1, self.name)
  end,
}

jiangfei:addSkill(shengxi)
jiangfei:addSkill(shoucheng)

Fk:loadTranslationTable{
  ["ld__jiangwanfeiyi"] = "蒋琬费祎",
  ["ld__shengxi"] = "生息",
  [":ld__shengxi"] = "结束阶段开始时，若你未于此回合内造成过伤害，你可摸两张牌。",
  ["shoucheng"] = "守成",
  [":shoucheng"] = "与你势力相同的角色于其回合外失去最后的手牌后，你可令其摸一张牌。",

  ["#shoucheng-draw"] = "守成：你可令 %dest 摸一张牌",

  ["$ld__shengxi1"] = "国之生计，在民生息。",
  ["$ld__shengxi2"] = "安民止战，兴汉室！",
  ["$shoucheng1"] = "待吾等助将军一臂之力！",
  ["$shoucheng2"] = "国库盈余，可助军威。",
  ["~ld__jiangwanfeiyi"] = "墨守成规，终为其害啊……",
}

local hetaihou = General(extension, "ld__hetaihou", "qun", 3, 3, General.Female)
hetaihou:addSkill("zhendu")
hetaihou:addSkill("qiluan")
Fk:loadTranslationTable{
  ["ld__hetaihou"] = "何太后",
}

return extension
