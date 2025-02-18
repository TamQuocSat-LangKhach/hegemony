local halberdSkill = fk.CreateSkill{
  name = "#sa__halberd_skill",
  attached_equip = "sa__halberd",
}
local H = require "packages/hegemony/util"
halberdSkill:addEffect(fk.AfterCardTargetDeclared, {
  anim_type = "offensive",
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(halberdSkill.name) and data.card.trueName == "slash" and #player.room:getUseExtraTargets(data) > 0
  end, -- 爆炸！
  on_cost = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "_sa__halberd", data.tos)
    local _, ret = room:askToUseActiveSkill(player, {skill_name = "sa__halberd", cancelable = true, prompt = "#sa__halberd-ask", extra_data = data.tos})
    room:setPlayerMark(player, "_sa__halberd", 0)
    if ret then
      event:setCostData(self, {tos = ret.targets})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:broadcastPlaySound("./packages/standard_cards/audio/card/halberd")
    room:setEmotion(player, "./packages/standard_cards/image/anim/halberd")
    local tos = event:getCostData(self).tos
    data.extra_data = data.extra_data or {}
    data.extra_data.saHalberd = true
    data.card.skillName = "sa__halberd"
    room:sendLog{
      type = "#HalberdTargets",
      from = player.id,
      to = table.map(tos, Util.IdMapper),
      arg = "sa__halberd",
      card = Card:getIdList(data.card),
    }
    for _, p in ipairs(tos) do
      data:addTarget(p)
    end
  end
})
halberdSkill:addEffect("active", {
  name = "#sa__halberd_targets",
  can_use = Util.FalseFunc,
  min_target_num = 1,
  card_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    local orig = table.simpleClone(player:getMark("_sa__halberd"))
    if table.contains(orig, to_select.id) or to_select == player then return false end
    local room = Fk:currentRoom()
    if to_select.kingdom == "unknown" or (table.every(orig, function(id)
      return not H.compareKingdomWith(to_select, room:getPlayerById(id))
    end) and table.every(selected, function(p)
      return not H.compareKingdomWith(to_select, p)
    end)) then
      local card = Fk:cloneCard("slash")
      return not player:isProhibited(to_select, card) and card.skill:modTargetFilter(player, to_select, table.map(orig, function(pid) return Fk:currentRoom():getPlayerById(pid) end), card, true)
    end
  end,
})
halberdSkill:addEffect(fk.CardEffectCancelledOut, {
  name = "#sa__halberd_delay",
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and data.card.trueName == "slash" and (player.room.logic:getCurrentEvent():findParent(GameEvent.UseCard).data.extra_data or {}).saHalberd
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local e = room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
    local use = e.data
    if #use.tos > 0 then
      room:sendLog{
        type = "#HalberdNullified",
        from = target.id,
        -- to = {player.id},
        arg = "sa__halberd",
        arg2 = data.card:toLogString(),
      }
      use.nullifiedTargets = use.tos
    end
  end,
})

halberdSkill:addTest(function(room, me)
  local card = room:printCard("sa__halberd")
  local comp2 = room.players[2]

  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      tos = { me },
      card = card,
    }
    FkTest.setNextReplies(comp2, { "__cancel" })
    room:useCard {
      from = me,
      tos = { comp2 },
      card = Fk:cloneCard("slash"),
    }
  end)
end)

Fk:loadTranslationTable{
  ["sa__halberd"] = "方天画戟",
  [":sa__halberd"] = "装备牌·武器<br /><b>攻击范围</b>：４<br /><b>武器技能</b>：当你使用【杀】选择目标后，"..
  "可以令任意名{势力各不相同且与已选择的目标势力均不相同的}角色和任意名没有势力的角色也成为目标，当此【杀】被【闪】抵消后，此【杀】对所有目标均无效。",
  ["#sa__halberd_skill"] = "方天画戟",
  ["#sa__halberd_targets"] = "方天画戟",
  ["#sa__halberd-ask"] = "你可发动〖方天画戟〗，令任意名势力各不相同且与已选择的目标势力均不相同的角色和任意名没有势力的角色也成为目标",
  ["#sa__halberd_delay"] = "方天画戟",
  ["#HalberdTargets"] = "%from 发动了〖%arg〗，令 %to 也成为 %card 的目标",
  ["#HalberdNullified"] = "由于〖%arg〗的效果，%from 对所有剩余目标使用的 %arg2 无效",
}

return halberdSkill
