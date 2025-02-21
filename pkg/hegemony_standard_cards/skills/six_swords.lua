local sixSwordsSkill = fk.CreateSkill{
  name = "#six_swords_skill",
  attached_equip = "six_swords",
}

local H = require "packages/hegemony/util"

sixSwordsSkill:addEffect("atkrange", {
  correct_func = function (self, from, to)
    if from.kingdom ~= "unknown" then
      local num = table.filter(Fk:currentRoom().alive_players, function(p)
        return from ~= p and H.compareKingdomWith(from, p) and
          table.find(p:getEquipments(Card.SubtypeWeapon), function(c) return Fk:getCardById(c).name == "six_swords" end) end)
      return #num
    end
    return 0
  end,
})

sixSwordsSkill:addTest(function (room, me)
  local tar = table.find(room:getOtherPlayers(me, false), function(p)
    return H.compareKingdomWith(me, p)
  end)
  if tar then
    local card = room:printCard("six_swords")
    FkTest.runInRoom(function()
      room:useCard {
        from = me,
        tos = { me },
        card = card,
      }
    end)
    lu.assertEquals(me:getAttackRange(), 2)
    for _, _p in ipairs(room.players) do
      p{_p.general, _p:getAttackRange()}
    end
    print(me:hasSkill(sixSwordsSkill.name))
    lu.assertEquals(tar:getAttackRange(), 2)
  end
end)

Fk:loadTranslationTable{
  ["six_swords"] = "吴六剑",
  [":six_swords"] = "装备牌·武器<br/><b>攻击范围</b>：２ <br/><b>武器技能</b>：锁定技，与你势力相同的其他角色攻击范围+1。",
}

return sixSwordsSkill
