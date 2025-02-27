local extension = Package:new("tenyear_heg")
extension.extensionName = "hegemony"
extension.game_modes_whitelist = { 'nos_heg_mode', 'new_heg_mode' }

local H = require "packages/hegemony/util"
local U = require "packages/utility/utility"

Fk:loadTranslationTable{
  ["tenyear_heg"] = "国战-十周年专属",
  ["ty_heg"] = "新服",
}

local huaxin = General(extension, "ty_heg__huaxin", "wei", 3)
local wanggui = fk.CreateTriggerSkill{
  name = "ty_heg__wanggui",
  mute = true,
  events = {fk.Damage, fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasShownSkill(self) and player:usedSkillTimes(self.name) == 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if player.general ~= "anjiang" and player.deputyGeneral ~= "anjiang" then
      if room:askForSkillInvoke(player, self.name, data, "#ty_heg__wanggui_draw-invoke") then
        self.cost_data = nil
        return true
      end
    else
      local targets = table.map(table.filter(room.alive_players, function(p)
        return H.compareKingdomWith(p, player, true) end), Util.IdMapper)
      if #targets == 0 then return end
      local to = room:askForChoosePlayers(player, targets, 1, 1, "#ty_heg__wanggui_damage-choose", self.name, true)
      if #to > 0 then
        self.cost_data = to[1]
        return true
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke(self.name)
    if self.cost_data then
      room:notifySkillInvoked(player, self.name, "offensive")
      local to = room:getPlayerById(self.cost_data)
      room:damage{
        from = player,
        to = to,
        damage = 1,
        skillName = self.name,
      }
    else
      room:notifySkillInvoked(player, self.name, "drawcard")
      local targets = table.map(table.filter(room.alive_players, function(p) return H.compareKingdomWith(p, player) end), Util.IdMapper)
      room:sortPlayersByAction(targets)
      for _, pid in ipairs(targets) do
        local p = room:getPlayerById(pid)
        if not p.dead then
          p:drawCards(1, self.name)
        end
      end
    end
  end,
}
local xibing = fk.CreateTriggerSkill{
  name = "ty_heg__xibing",
  anim_type = "control",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    if not (player:hasSkill(self) and target ~= player and target.phase == Player.Play and
      data.card.color == Card.Black and (data.card.trueName == "slash" or data.card:isCommonTrick()) and #AimGroup:getAllTargets(data.tos) == 1) then return false end
    local events = target.room.logic:getEventsOfScope(GameEvent.UseCard, 1, function(e) 
      local use = e.data[1]
      return use.from == target.id and use.card.color == Card.Black and (use.card.trueName == "slash" or use.card:isCommonTrick())
    end, Player.HistoryTurn)
    return #events == 1 and events[1].id == target.room.logic:getCurrentEvent().id
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#ty_heg__xibing-invoke::"..target.id)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, {target.id})
    local num = math.min(target.hp, 5) - target:getHandcardNum()
    local cards
    if num > 0 then
      cards = target:drawCards(num, self.name)
    end
    if H.getGeneralsRevealedNum(player) == 2 and H.getGeneralsRevealedNum(target) == 2
      and room:askForChoice(player, {"ty_heg__xibing_hide::" .. target.id, "Cancel"}, self.name) ~= "Cancel" then
      for _, p in ipairs({player, target}) do
        local isDeputy = H.doHideGeneral(room, player, p, self.name)
        room:setPlayerMark(p, "@ty_heg__xibing_reveal-turn", H.getActualGeneral(p, isDeputy))
        local record = type(p:getMark(MarkEnum.RevealProhibited .. "-turn")) == "table" and p:getMark(MarkEnum.RevealProhibited .. "-turn") or {}
        table.insert(record, isDeputy and "d" or "m")
        room:setPlayerMark(p, MarkEnum.RevealProhibited .. "-turn", record)
      end
    end
    if cards and not target.dead then
      room:setPlayerMark(target, "@@ty_heg__xibing-turn", 1)
    end
  end,
}
local xibing_prohibit = fk.CreateProhibitSkill{
  name = "#ty_heg__xibing_prohibit",
  prohibit_use = function(self, player, card)
    if player:getMark("@@ty_heg__xibing-turn") == 0 then return false end 
    local subcards = Card:getIdList(card)
    return #subcards > 0 and table.every(subcards, function(id)
      return table.contains(player:getCardIds(Player.Hand), id)
    end)
  end,
}
xibing:addRelatedSkill(xibing_prohibit)

huaxin:addSkill(wanggui)
huaxin:addSkill(xibing)

Fk:loadTranslationTable{
  ["ty_heg__huaxin"] = "华歆",
  ["#ty_heg__huaxin"] = "渊清玉洁",
  ["designer:ty_heg__huaxin"] = "韩旭",
  ["illustrator:ty_heg__huaxin"] = "秋呆呆",

  ["ty_heg__wanggui"] = "望归",
  [":ty_heg__wanggui"] = "每回合限一次，当你造成或受到伤害后，若你：仅明置此武将牌，你可对与你势力不同的一名角色造成1点伤害；武将牌均明置，"..
  "你可令所有与你势力相同的角色各摸一张牌。",
  ["ty_heg__xibing"] = "息兵",
  [":ty_heg__xibing"] = "当其他角色于其出牌阶段内使用黑色【杀】或黑色普通锦囊牌指定唯一目标后，若其于此回合内未使用过黑色【杀】或黑色普通锦囊牌，你可令其将手牌摸至体力值"..
  "（至多摸至五张），然后若你与其均明置了所有武将牌，则你可暗置你与其各一张武将牌且本回合不能明置以此法暗置的武将牌。若其因此摸牌，其本回合不能使用手牌。",

  ["#ty_heg__xibing-invoke"] = "你想对 %dest 发动 “息兵” 吗？",
  ["ty_heg__xibing_hide"] = "暗置你与%dest各一张武将牌且本回合不能明置",
  ["@ty_heg__xibing_reveal-turn"] = "息兵禁亮",
  ["@@ty_heg__xibing-turn"] = "息兵 禁用手牌",
  ["#ty_heg__wanggui_damage-choose"] = "望归：你可对与你势力不同的一名角色造成1点伤害",
  ["#ty_heg__wanggui_draw-invoke"] = "望归：你可令所有与你势力相同的角色各摸一张牌",

  ["$ty_heg__wanggui1"] = "存志太虚，安心玄妙。",
  ["$ty_heg__wanggui2"] = "礼法有度，良德才略。",
  ["$ty_heg__xibing1"] = "千里运粮，非用兵之利。",
  ["$ty_heg__xibing2"] = "宜弘一代之治，绍三王之迹。",
  ["~ty_heg__huaxin"] = "大举发兵，劳民伤国。",
}

local yanghu = General(extension, "ty_heg__yanghu", "wei", 3)
local deshao = fk.CreateTriggerSkill{
  name = "ty_heg__deshao",
  anim_type = "defensive",
  events = {fk.TargetSpecified},
  can_trigger = function (self, event, target, player, data)
    return target ~= player and player:hasSkill(self) and U.isOnlyTarget(player, data, event)
      and data.card.color == Card.Black and H.getGeneralsRevealedNum(player) >= H.getGeneralsRevealedNum(target) 
      and player:usedSkillTimes(self.name, Player.HistoryTurn) < player.hp
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#ty_heg__deshao-invoke::"..data.from)
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    local from = room:getPlayerById(data.from)
    if not from:isNude() then
      local id = room:askForCardChosen(player, from, "he", self.name)
      room:throwCard(id, self.name, from, player)
    end
  end,
}

local mingfa = fk.CreateActiveSkill{
  name = "ty_heg__mingfa",
  anim_type = "offensive",
  card_num = 0,
  target_num = 1,
  can_use = function (self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function (self, to_select, selected)
    return false
  end,
  target_filter = function (self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id and (not H.compareKingdomWith(Fk:currentRoom():getPlayerById(to_select), Self))
  end,
  on_use = function(self, room, effect)
    local target = room:getPlayerById(effect.tos[1])
    room:addTableMark(target, "@@ty_heg__mingfa_delay", effect.from)
  end,
}

local mingfa_delay = fk.CreateTriggerSkill{
  name = "#ty_heg__mingfa_delay",
  anim_type = "offensive",
  events = {fk.TurnEnd},
  can_trigger = function (self, event, target, player, data)
    if target.dead or player.dead then return false end
    return table.contains(target:getTableMark("@@ty_heg__mingfa_delay"), player.id)
  end,
  on_cost = Util.TrueFunc,
  on_use = function (self, event, target, player, data)
    local room = player.room
    if player:getHandcardNum() > target:getHandcardNum() then
      room:damage{
        from = player,
        to = target,
        damage = 1,
        skillName = self.name,
      }
      if target:getHandcardNum() > 0 then
        local cards = room:askForCardsChosen(player, target, 1, 1, "h", self.name)
        room:obtainCard(player, cards, false, fk.ReasonPrey)
      end
    elseif player:getHandcardNum() < target:getHandcardNum() then
      player:drawCards(math.min(target:getHandcardNum() - player:getHandcardNum(), 5), self.name)
    end
  end,

  refresh_events = {fk.AfterTurnEnd, fk.BuryVictim},
  can_refresh = function(self, event, target, player, data)
    if event == fk.AfterTurnEnd then
      return player == target and player:getMark("@@ty_heg__mingfa_delay") ~= 0
    elseif event == fk.BuryVictim then
      local mark = player:getMark("@@ty_heg__mingfa_delay")
      return type(mark) == "table" and table.every(player.room.alive_players, function (p)
        return not table.contains(mark, p.id)
      end)
    end
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@@ty_heg__mingfa_delay", 0)
  end,
}

mingfa:addRelatedSkill(mingfa_delay)
yanghu:addSkill(deshao)
yanghu:addSkill(mingfa)
Fk:loadTranslationTable{
  ["ty_heg__yanghu"] = "羊祜",
  ["#ty_heg__yanghu"] = "制纮同轨",
  ["designer:ty_heg__yanghu"] = "韩旭",
  ["illustrator:ty_heg__yanghu"] = "匠人绘",
  ["ty_heg__deshao"] = "德劭",
  [":ty_heg__deshao"] = "每回合限X次（X为你的体力值），当其他角色使用黑色牌指定你为唯一目标后，若其已明置的武将牌数不大于你，你可弃置其一张牌。",
  ["ty_heg__mingfa"] = "明伐",
  [":ty_heg__mingfa"] = "出牌阶段限一次，你可以选择与你势力不同或未确定势力的一名其他角色，其下个回合结束时，若其手牌数：小于你，你对其造成1点伤害并获得其一张手牌；"..
  "不小于你，你摸至与其手牌数相同（最多摸五张）。",
  ["#ty_heg__mingfa_delay"] = "明伐",
  ["@@ty_heg__mingfa_delay"] = "明伐",
  ["#ty_heg__deshao-invoke"] = "德劭：你可以弃置 %dest 一张牌",

  ["$ty_heg__deshao1"] = "名德远播，朝野俱瞻。",
  ["$ty_heg__deshao2"] = "增修德信，以诚服人。",
  ["$ty_heg__mingfa1"] = "煌煌大势，无须诈取。",
  ["$ty_heg__mingfa2"] = "开示公道，不为掩袭。",
  ["~ty_heg__yanghu"] = "臣死之后，杜元凯可继之……",
}


local zongyu = General(extension, "ty_heg__zongyu", "shu", 3)
local qiao = fk.CreateTriggerSkill{
  name = "ty_heg__qiao",
  anim_type = "control",
  events = {fk.TargetConfirmed},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and
      not player.room:getPlayerById(data.from):isNude() and player:usedSkillTimes(self.name, Player.HistoryTurn) < 2
      and not H.compareKingdomWith(player.room:getPlayerById(data.from), player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#ty_heg__qiao-invoke::"..data.from)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = room:getPlayerById(data.from)
    local id = room:askForCardChosen(player, from, "he", self.name)
    room:throwCard({id}, self.name, from, player)
    if not player:isNude() then
      room:askForDiscard(player, 1, 1, true, self.name, false)
    end
  end,
}
local chengshang = fk.CreateTriggerSkill{
  name = "ty_heg__chengshang",
  anim_type = "drawcard",
  events = {fk.CardUseFinished},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Play and data.tos and
      table.find(TargetGroup:getRealTargets(data.tos), function(id) return not H.compareKingdomWith(player.room:getPlayerById(id), player) end)
      and not data.damageDealt and data.card.suit ~= Card.NoSuit and player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil,
      "#ty_heg__chengshang-invoke:::"..data.card:getSuitCompletedString(true))
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = room:getCardsFromPileByRule(".|"..data.card:getNumberStr().."|"..data.card:getSuitString(), 9)
    if #cards > 0 then
      room:moveCardTo(cards, Card.PlayerHand, player, fk.ReasonJustMove, self.name, nil, false, player.id)
    else
      player:setSkillUseHistory(self.name, 0, Player.HistoryPhase)
    end
  end,
}
zongyu:addSkill(qiao)
zongyu:addSkill(chengshang)

Fk:loadTranslationTable{
  ["ty_heg__zongyu"] = "宗预",
  ["#ty_heg__zongyu"] = "九酝鸿胪",
  ["designer:ty_heg__zongyu"] = "韩旭",
  ["illustrator:ty_heg__zongyu"] = "铁杵文化",

  ["ty_heg__qiao"] = "气傲",
  [":ty_heg__qiao"] = "每回合限两次，当你成为与你势力不同或未确定势力角色使用牌的目标后，你可弃置其一张牌，然后你弃置一张牌。",
  ["ty_heg__chengshang"] = "承赏",
  [":ty_heg__chengshang"] = "每阶段限一次，当你于出牌阶段内使用指定有与你势力不同或未确定势力角色为目标的牌结算后，若此牌未造成伤害，你可获得牌堆中所有与此牌花色点数相同的牌。"..
  "若你没有因此获得牌，此技能视为此阶段未发动过。",

  ["#ty_heg__qiao-invoke"] = "气傲：你可以弃置 %dest 一张牌，然后你弃置一张牌",
  ["#ty_heg__chengshang-invoke"] = "承赏：你可以获得牌堆中所有的 %arg 牌",

  ["$ty_heg__qiao1"] = "吾六十何为不受兵邪？",
  ["$ty_heg__qiao2"] = "芝性骄傲，吾独不为屈。",
  ["$ty_heg__chengshang1"] = "嘉其抗直，甚爱待之。",
  ["$ty_heg__chengshang2"] = "为国鞠躬，必受封赏。",
  ["~ty_heg__zongyu"] = "吾年逾七十，唯少一死耳……",
}

local dengzhi = General(extension, "ty_heg__dengzhi", "shu", 3)
local jianliang = fk.CreateTriggerSkill{
  name = "ty_heg__jianliang",
  anim_type = "drawcard",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Draw and
      table.every(player.room.alive_players, function(p) return player:getHandcardNum() <= p:getHandcardNum() end)
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    local targets = table.map(table.filter(room.alive_players, function(p) return H.compareKingdomWith(p, player) end), Util.IdMapper)
    room:sortPlayersByAction(targets)
    for _, pid in ipairs(targets) do
      local p = room:getPlayerById(pid)
      if not p.dead then
        p:drawCards(1, self.name)
      end
    end
  end,
}

local weimeng = fk.CreateActiveSkill{
  name = "ty_heg__weimeng",
  anim_type = "control",
  card_num = 0,
  target_num = 1,
  prompt = function (self, selected, selected_cards)
    return "#ty_heg__weimeng:::"..Self.hp
  end,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected)
    return false
  end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id and not Fk:currentRoom():getPlayerById(to_select):isKongcheng()
  end,
  on_use = function (self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local cards = room:askForCardsChosen(player, target, 1, player.hp, "h", self.name)
    room:obtainCard(player, cards, false, fk.ReasonPrey)
    if player.dead or player:isNude() or target.dead then return end
    local cards2
    if #player:getCardIds("he") <= #cards then
      cards2 = player:getCardIds("he")
    else
      cards2 = room:askForCard(player, #cards, #cards, true, self.name, false, ".",
        "#ty_heg__weimeng-give::"..target.id..":"..#cards)
      if #cards2 < #cards then
        cards2 = table.random(player:getCardIds("he"), #cards)
      end
    end
    room:obtainCard(target, cards2, false, fk.ReasonGive)
    local choices = {"ty_heg__weimeng_mn_ask::" .. target.id, "Cancel"}
    if room:askForChoice(player, choices, self.name) ~= "Cancel" then
      room:setPlayerMark(target, "@@ty_heg__weimeng_manoeuvre", 1)
      room:handleAddLoseSkills(target, "ty_heg__weimeng_manoeuvre", nil)
    end
  end,
}

local weimeng_mn = fk.CreateActiveSkill{
  name = "ty_heg__weimeng_manoeuvre",
  anim_type = "control",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = function(self, to_select, selected)
    return false
  end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id and not Fk:currentRoom():getPlayerById(to_select):isKongcheng()
  end,
  on_use = function (self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local card1 = room:askForCardChosen(player, target, "h", self.name)
    room:obtainCard(player, card1, false, fk.ReasonPrey)
    if player.dead or player:isNude() or target.dead then return end
    local cards2 = room:askForCard(player, 1, 1, true, self.name, false, ".", "#ty_heg__weimeng-give::"..target.id..":"..tostring(1))
    room:obtainCard(target, cards2[1], false, fk.ReasonGive)
  end,
}

local weimeng_mn_detach = fk.CreateTriggerSkill{
  name = "#ty_heg__weimeng_manoeuvre_detach",
  refresh_events = {fk.AfterTurnEnd},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill("ty_heg__weimeng_manoeuvre", true, true) 
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:handleAddLoseSkills(player, "-ty_heg__weimeng_manoeuvre", nil)
    room:setPlayerMark(player, "@@ty_heg__weimeng_manoeuvre", 0)
  end,
}

weimeng_mn:addRelatedSkill(weimeng_mn_detach)
Fk:addSkill(weimeng_mn)
dengzhi:addSkill(jianliang)
dengzhi:addSkill(weimeng)
Fk:loadTranslationTable{
  ["ty_heg__dengzhi"] = "邓芝",
  ["#ty_heg__dengzhi"] = "绝境的外交家",
  ["designer:ty_heg__dengzhi"] = "韩旭",
  ["illustrator:ty_heg__dengzhi"] = "凝聚永恒",

  ["ty_heg__jianliang"] = "简亮",
  [":ty_heg__jianliang"] = "摸牌阶段开始时，若你的手牌数为全场最少，你可令与你势力相同的所有角色各摸一张牌。",
  ["ty_heg__weimeng"] = "危盟",
  [":ty_heg__weimeng"] = "出牌阶段限一次，你可选择一名其他角色，获得其至多X张手牌，然后交给其等量的牌（X为你的体力值）。"..
  "<br><font color=\"blue\">◆纵横：〖危盟〗描述中的X改为1。<font><br><font color=\"grey\">\"<b>纵横</b>\"："..
  "当拥有“纵横”效果技能发动结算完成后，可以令技能目标角色获得对应修订描述后的技能，直到其下回合结束。",
  ["#ty_heg__weimeng-give"] = "危盟：交还 %dest %arg 张牌。",
  ["ty_heg__weimeng_mn_ask"] = "令%dest获得〖危盟（纵横）〗直到其下回合结束。",
  ["@@ty_heg__weimeng_manoeuvre"] = "危盟 纵横",
  ["ty_heg__weimeng_manoeuvre"] = "危盟⇋",
  ["#ty_heg__weimeng"] = "危盟：获得一名其他角色至多%arg张牌，交还等量牌。",
  [":ty_heg__weimeng_manoeuvre"] = "出牌阶段限一次，你可以获得目标角色一张手牌，然后交给其等量的牌。",

  ["$ty_heg__jianliang1"] = "岂曰少衣食，与君共袍泽！",
  ["$ty_heg__jianliang2"] = "义士同心力，粮秣应期来！",
  ["$ty_heg__weimeng1"] = "此礼献于友邦，共赴兴汉大业！",
  ["$ty_heg__weimeng2"] = "吴有三江之守，何故委身侍魏？",
  ["~ty_heg__dengzhi"] = "伯约啊，我帮不了你了……",
}

local luyusheng = General(extension, "ty_heg__luyusheng", "wu", 3, 3, General.Female)
local zhente = fk.CreateTriggerSkill{
  name = "ty_heg__zhente",
  anim_type = "defensive",
  events = {fk.TargetConfirmed},
  can_trigger = function(self, event, target, player, data)
    if target == player and player:hasSkill(self) and player:usedSkillTimes(self.name) == 0 and data.from ~= player.id then
      return (data.card:isCommonTrick() or data.card.type == Card.TypeBasic) and data.card.color == Card.Black
    end
  end,
  on_cost = function(self, event, target, player, data)
    if player.room:askForSkillInvoke(player, self.name, nil,
    "#ty_heg__zhente-invoke:".. data.from .. "::" .. data.card:toLogString() .. ":" .. data.card:getColorString()) then
      player.room:doIndicate(player.id, {data.from})
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = room:getPlayerById(data.from)
    local color = data.card:getColorString()
    local choice = room:askForChoice(to, {
      "ty_heg__zhente_negate::" .. tostring(player.id) .. ":" .. data.card.name,
      "ty_heg__zhente_colorlimit:::" .. color
    }, self.name)
    if choice:startsWith("ty_heg__zhente_negate") then
      table.insertIfNeed(data.nullifiedTargets, player.id)
    else
      local colorsRecorded = type(to:getMark("@ty_heg__zhente-turn")) == "table" and to:getMark("@ty_heg__zhente-turn") or {}
      table.insertIfNeed(colorsRecorded, color)
      room:setPlayerMark(to, "@ty_heg__zhente-turn", colorsRecorded)
    end
  end,
}
local zhente_prohibit = fk.CreateProhibitSkill{
  name = "#ty_heg__zhente_prohibit",
  prohibit_use = function(self, player, card)
    local mark = player:getMark("@ty_heg__zhente-turn")
    return type(mark) == "table" and table.contains(mark, card:getColorString())
  end,
}

---@param room Room
---@param player ServerPlayer
---@param target ServerPlayer
local function zhiweiUpdate(room, player, target)
  room:setPlayerMark(player, "@zhiwei", target.general == "anjiang" and "seat#" .. tostring(target.seat) or target.general)
end

local zhiwei = fk.CreateTriggerSkill{
  name = "ty_heg__zhiwei",
  events = {fk.GeneralRevealed, fk.AfterCardsMove, fk.Damage, fk.Damaged}, --- TODO
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if player:hasSkill(self) then
      if event == fk.GeneralRevealed then
        for _, v in pairs(data) do
          if v == "ty_heg__luyusheng" then return true end
        end
      elseif event == fk.AfterCardsMove then
        if player.phase ~= Player.Discard then return false end
        local zhiwei_id = player:getMark(self.name)
        if zhiwei_id == 0 then return false end
        local room = player.room
        local to = room:getPlayerById(zhiwei_id)
        if to == nil or to.dead then return false end
        local cards = {}
        for _, move in ipairs(data) do
          if move.from == player.id and move.moveReason == fk.ReasonDiscard then
            for _, info in ipairs(move.moveInfo) do
              if (info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip) and
              room:getCardArea(info.cardId) == Card.DiscardPile then
                table.insertIfNeed(cards, info.cardId)
              end
            end
          end
        end
        if #cards > 0 then
          self.cost_data = cards
          return true
        end
      else
        return target and player:getMark(self.name) == target.id and not target.dead and (event == fk.Damage or not player:isKongcheng())
      end
    end
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke(self.name)
    if event == fk.GeneralRevealed then
      room:notifySkillInvoked(player, self.name, "special")
      local targets = table.map(room:getOtherPlayers(player, false), Util.IdMapper)
      if #targets == 0 then return false end
      local to = room:askForChoosePlayers(player, targets, 1, 1, "#ty_heg__zhiwei-choose", self.name, false, true)
      if #to > 0 then
        room:setPlayerMark(player, self.name, to[1])
        zhiweiUpdate(room, player, room:getPlayerById(to[1]))
      end
    elseif event == fk.AfterCardsMove then
      local zhiwei_id = player:getMark(self.name)
      if zhiwei_id == 0 then return false end
      local to = room:getPlayerById(zhiwei_id)
      if to == nil or to.dead then return false end
      local cards = self.cost_data
      if #cards > 0 then
        room:notifySkillInvoked(player, self.name, "support")
        zhiweiUpdate(room, player, to)
        room:moveCards({
        ids = cards,
        to = zhiwei_id,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonPrey,
        proposer = player.id,
        skillName = self.name,
      })
      end
    elseif event == fk.Damage then
      room:notifySkillInvoked(player, self.name, "drawcard")
      zhiweiUpdate(room, player, target)
      room:drawCards(player, 1, self.name)
    elseif event == fk.Damaged then
      room:notifySkillInvoked(player, self.name, "negative")
      zhiweiUpdate(room, player, target)
      room:throwCard(table.random(player:getCardIds(Player.Hand), 1), self.name, player, player)
    end
  end,

  refresh_events = {fk.BuryVictim},
  can_refresh = function(self, event, target, player, data)
    return player:getMark(self.name) == target.id
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, self.name, 0)
    room:setPlayerMark(player, "@zhiwei", 0)
    H.hideBySkillName(player, self.name)
  end,
}
zhente:addRelatedSkill(zhente_prohibit)
luyusheng:addSkill(zhente)
luyusheng:addSkill(zhiwei)

Fk:loadTranslationTable{
  ["ty_heg__luyusheng"] = "陆郁生",
  ["#ty_heg__luyusheng"] = "义姑",
  ["designer:ty_heg__luyusheng"] = "韩旭",
  ["illustrator:ty_heg__luyusheng"] = "君桓文化",

  ["ty_heg__zhente"] = "贞特",
  [":ty_heg__zhente"] = "每回合限一次，当你成为其他角色使用黑色基本牌或黑色普通锦囊牌的目标后，你可令使用者选择一项：1.本回合不能使用黑色牌；"..
  "2.此牌对你无效",
  ["ty_heg__zhiwei"] = "至微",
  [":ty_heg__zhiwei"] = "当你明置此武将牌后，你可选择一名其他角色：当该角色造成伤害后，你摸一张牌；当该角色受到伤害后，你随机弃置一张手牌；"..
  "你弃牌阶段弃置的牌均被该角色获得；当该角色死亡时，若你武将牌均明置，你暗置此武将牌。",

  ["#ty_heg__zhente-invoke"] = "是否使用贞特，令%src选择令【%arg】对你无效或不能再使用%arg2牌",
  ["ty_heg__zhente_negate"] = "令【%arg】对%dest无效",
  ["ty_heg__zhente_colorlimit"] = "本回合不能再使用%arg牌",
  ["@ty_heg__zhente-turn"] = "贞特",
  ["#ty_heg__zhiwei-choose"] = "至微：选择一名其他角色",
  ["@ty_heg__zhiwei"] = "至微",

  ["$ty_heg__zhente1"] = "抗声昭节，义形于色。",
  ["$ty_heg__zhente2"] = "少履贞特之行，三从四德。",
  ["$ty_heg__zhiwei1"] = "体信贯于神明，送终以礼。",
  ["$ty_heg__zhiwei2"] = "昭德以行，生不能侍奉二主。",
  ["~ty_heg__luyusheng"] = "父亲，郁生甚是想念……",
}

local fengxiw = General(extension, "ty_heg__fengxiw", "wu", 3)
local yusui = fk.CreateTriggerSkill{
  name = "ty_heg__yusui",
  anim_type = "offensive",
  events = {fk.TargetConfirmed},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.from ~= player.id and data.card.color == Card.Black and
      player:usedSkillTimes(self.name, Player.HistoryTurn) == 0 and H.compareKingdomWith(player.room:getPlayerById(data.from), player, true) and
      player.hp > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = room:getPlayerById(data.from)
    room:loseHp(player, 1, self.name)
    if player.dead then return end
    local choices = {}
    if not to:isKongcheng() then
      table.insert(choices, "ty_heg__yusui_discard::" .. to.id .. ":" .. to.maxHp)
    end
    if to.hp > player.hp then
      table.insert(choices, "ty_heg__yusui_loseHp::" .. to.id .. ":" .. player.hp)
    end
    if #choices == 0 then return false end
    local choice = room:askForChoice(player, choices, self.name)
    if choice:startsWith("ty_heg__yusui_discard") then
      room:askForDiscard(to, to.maxHp, to.maxHp, false, self.name, false)
    else
      room:loseHp(to, to.hp - player.hp, self.name)
    end
  end,
}
local boyan = fk.CreateActiveSkill{
  name = "ty_heg__boyan",
  anim_type = "control",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local n = target.maxHp - target:getHandcardNum()
    if n > 0 then
      target:drawCards(n, self.name)
    end
    room:setPlayerMark(target, "@@ty_heg__boyan-turn", 1)
    local choices = {"ty_heg__boyan_mn_ask::" .. target.id, "Cancel"}
    if room:askForChoice(player, choices, self.name) ~= "Cancel" then
      room:setPlayerMark(target, "@@ty_heg__boyan_manoeuvre", 1)
      room:handleAddLoseSkills(target, "ty_heg__boyan_manoeuvre", nil)
    end
  end,
}
local boyan_prohibit = fk.CreateProhibitSkill{
  name = "#ty_heg__boyan_prohibit",
  prohibit_use = function(self, player, card)
    if player:getMark("@@ty_heg__boyan-turn") == 0 then return false end
    local subcards = Card:getIdList(card)
    return #subcards > 0 and table.every(subcards, function(id)
      return table.contains(player:getCardIds(Player.Hand), id)
    end)
  end,
  prohibit_response = function(self, player, card)
    if player:getMark("@@ty_heg__boyan-turn") == 0 then return false end
    local subcards = Card:getIdList(card)
    return #subcards > 0 and table.every(subcards, function(id)
      return table.contains(player:getCardIds(Player.Hand), id)
    end)
  end,
}
boyan:addRelatedSkill(boyan_prohibit)
local boyan_mn = fk.CreateActiveSkill{
  name = "ty_heg__boyan_manoeuvre",
  anim_type = "control",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  on_use = function(self, room, effect)
    local target = room:getPlayerById(effect.tos[1])
    room:setPlayerMark(target, "@@ty_heg__boyan-turn", 1)
  end,
}
local boyan_mn_detach = fk.CreateTriggerSkill{
  name = "#ty_heg__boyan_manoeuvre_detach",
  refresh_events = {fk.AfterTurnEnd},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill("ty_heg__boyan_manoeuvre", true, true)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:handleAddLoseSkills(player, "-ty_heg__boyan_manoeuvre", nil)
    room:setPlayerMark(player, "@@ty_heg__boyan_manoeuvre", 0)
  end,
}
boyan_mn:addRelatedSkill(boyan_mn_detach)
Fk:addSkill(boyan_mn)
fengxiw:addSkill(yusui)
fengxiw:addSkill(boyan)
Fk:loadTranslationTable{
  ["ty_heg__fengxiw"] = "冯熙",
  ["#ty_heg__fengxiw"] = "东吴苏武",
  ["designer:ty_heg__fengxiw"] = "韩旭",
  ["illustrator:ty_heg__fengxiw"] = "匠人绘",

  ["ty_heg__yusui"] = "玉碎",
  [":ty_heg__yusui"] = "每回合限一次，当你成为其他角色使用黑色牌的目标后，若你与其势力不同，你可失去1点体力，然后选择一项：1.令其弃置X张手牌"..
  "（X为其体力上限）；2.令其失去体力值至与你相同。",
  ["ty_heg__boyan"] = "驳言",
  [":ty_heg__boyan"] = "出牌阶段限一次，你可选择一名其他角色，其将手牌摸至其体力上限，其本回合不能使用或打出手牌。"..
  "<br><font color=\"blue\">◆纵横：删去〖驳言〗描述中的“其将手牌摸至体力上限”。<font><br><font color=\"grey\">\"<b>纵横</b>\"："..
  "当拥有“纵横”效果技能发动结算完成后，可以令技能目标角色获得对应修订描述后的技能，直到其下回合结束。",

  ["ty_heg__yusui_discard"] = "令%dest弃置%arg张手牌",
  ["ty_heg__yusui_loseHp"] = "令%dest失去体力至%arg",
  ["ty_heg__boyan_mn_ask"] = "令%dest获得〖驳言（纵横）〗直到其下回合结束",
  ["@@ty_heg__boyan-turn"] = "驳言",
  ["@@ty_heg__boyan_manoeuvre"] = "驳言 纵横",

  ["ty_heg__boyan_manoeuvre"] = "驳言⇋",
  [":ty_heg__boyan_manoeuvre"] = "出牌阶段限一次，你可选择一名其他角色，其本回合不能使用或打出手牌。",

  ["$ty_heg__boyan1"] = "黑白颠倒，汝言谬矣！",
  ["$ty_heg__boyan2"] = "魏王高论，实为无知之言。",
  ["$ty_heg__yusui1"] = "宁为玉碎，不为瓦全！",
  ["$ty_heg__yusui2"] = "生义相左，舍生取义。",
  ["~ty_heg__fengxiw"] = "乡音未改双鬓苍，身陷北国有义求。",
}

local miheng = General(extension, "ty_heg__miheng", "qun", 3)
miheng:addCompanions("hs__kongrong")
local kuangcai = fk.CreateTriggerSkill{
  name = "ty_heg__kuangcai",
  mute = true,
  frequency = Skill.Compulsory,
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    if target == player and player:hasSkill(self) and player.phase == Player.Discard then
      local used = #player.room.logic:getEventsOfScope(GameEvent.UseCard, 1, function(e)
        local use = e.data[1]
        return use.from == player.id
      end, Player.HistoryTurn) > 0
      if not used then
        self.cost_data = "noused"
        return true
      elseif #player.room.logic:getActualDamageEvents(1, function(e) return e.data[1].from == player end) == 0 then
        self.cost_data = "used"
        return true
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke(self.name)
    if self.cost_data == "noused" then
      room:notifySkillInvoked(player, self.name, "support")
      room:addPlayerMark(player, MarkEnum.AddMaxCards, 1)
    else
      room:notifySkillInvoked(player, self.name, "negative")
      room:addPlayerMark(player, MarkEnum.MinusMaxCards, 1)
    end
    room:broadcastProperty(player, "MaxCards")
  end,
}
local kuangcai_targetmod = fk.CreateTargetModSkill{
  name = "#ty_heg__kuangcai_targetmod",
  bypass_times = function(self, player, skill, scope, card, to)
    return card and player:hasSkill("ty_heg__kuangcai") and player.phase ~= Player.NotActive
  end,
  bypass_distances = function(self, player, skill, card, to)
    return card and player:hasSkill("ty_heg__kuangcai") and player.phase ~= Player.NotActive
  end,
}
kuangcai:addRelatedSkill(kuangcai_targetmod)
local ty_heg__shejian = fk.CreateTriggerSkill{
  name = "ty_heg__shejian",
  anim_type = "control",
  events = {fk.TargetConfirmed},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.from ~= player.id and #AimGroup:getAllTargets(data.tos) == 1 and
      not player:isKongcheng()
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#ty_heg__shejian-invoke::"..data.from..":"..data.card:toLogString())
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = room:getPlayerById(data.from)
    local n = player:getHandcardNum()
    player:throwAllCards("h")
    if not (player.dead or from.dead) then
      room:doIndicate(player.id, {data.from})
      local choices = {"shejian_damage::" .. data.from}
      n = math.min(n, #from:getCardIds("he"))
      if not from:isNude() then
        table.insert(choices, 1, "shejian_discard::" .. data.from .. ":" .. n)
      end
      local choice = room:askForChoice(player, choices, self.name, "#ty_heg__shejian-choice::"..data.from..":"..n)
      if choice:startsWith("shejian_discard") then
        local cards = room:askForCardsChosen(player, from, n, n, "he", self.name)
        room:throwCard(cards, self.name, from, player)
      else
        room:damage{
          from = player,
          to = from,
          damage = 1,
          skillName = self.name
        }
      end
    end
  end,
}
miheng:addSkill(kuangcai)
miheng:addSkill(ty_heg__shejian)
Fk:loadTranslationTable{
  ["ty_heg__miheng"] = "祢衡",
  ["#ty_heg__miheng"] = "狂傲奇人",
  ["designer:ty_heg__miheng"] = "韩旭",
  ["illustrator:ty_heg__miheng"] = "MuMu",

  ["ty_heg__kuangcai"] = "狂才",
  [":ty_heg__kuangcai"] = "锁定技，①你的回合内，你使用牌无距离和次数限制。②弃牌阶段开始时，若你本回合：没有使用过牌，你的手牌上限+1；使用过牌且没有造成伤害，你手牌上限-1。",
  ["ty_heg__shejian"] = "舌剑",
  [":ty_heg__shejian"] = "当你成为其他角色使用牌的唯一目标后，你可弃置所有手牌。若如此做，你选择一项：1.弃置其等量的牌；2.对其造成1点伤害。",
  ["#ty_heg__shejian-invoke"] = "舌剑：%dest 对你使用 %arg，你可以弃置所有手牌，弃置其等量的牌或对其造成1点伤害",
  ["#ty_heg__shejian-choice"] = "舌剑：弃置 %dest %arg张牌或对其造成1点伤害",
  ["shejian_discard"] = "弃置%dest%arg张牌",
  ["shejian_damage"] = "对%dest造成1点伤害",

  ["$ty_heg__kuangcai1"] = "耳所瞥闻，不忘于心。",
  ["$ty_heg__kuangcai2"] = "吾焉能从屠沽儿耶？",
  ["$ty_heg__shejian1"] = "伤人的，可不止刀剑！  ",
  ["$ty_heg__shejian2"] = "死公！云等道？",
  ["~ty_heg__miheng"] = "恶口……终至杀身……",
}

local xunchen = General(extension, "ty_heg__xunchen", "qun", 3)
local anyong = fk.CreateTriggerSkill{
  name = "ty_heg__anyong",
  events = {fk.DamageCaused},
  anim_type = "offensive",
  can_trigger = function (self, event, target, player, data)
    return target and H.compareKingdomWith(target, player) and player:hasSkill(self)
      and data.to ~= player and data.to ~= target
      and player:usedSkillTimes(self.name, Player.HistoryTurn) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, nil, "#ty_heg__anyong-invoke:"..data.from.id .. ":" .. data.to.id .. ":" .. data.damage)
  end,
  on_use = function (self, event, target, player, data)
    local room = player.room
    local to = data.to
    local num = H.getGeneralsRevealedNum(to)
    if num == 1 then
      room:askForDiscard(player, 2, 2, false, self.name, false)
    elseif num == 2 then
      room:loseHp(player, 1, self.name)
      room:handleAddLoseSkills(player, "-ty_heg__anyong", nil)
    end
    data.damage = data.damage * 2
  end,
}

local fenglve = fk.CreateActiveSkill{
  name = "ty_heg__fenglve",
  anim_type = "control",
  prompt = "#ty_heg__fenglve-active",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0 and not player:isKongcheng()
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id and not Fk:currentRoom():getPlayerById(to_select):isKongcheng()
  end,
  on_use = function (self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local pindian = player:pindian({target}, self.name)
    if pindian.results[target.id].winner == player then
      if not (player.dead or target.dead or target:isNude()) then
        local cards = target:getCardIds("hej")
        if #cards > 2 then
          cards = room:askForCardsChosen(target, target, 2, 2, "hej", self.name)
        end
        room:moveCardTo(cards, Player.Hand, player, fk.ReasonGive, self.name, nil, false, player.id)
      end
    elseif pindian.results[target.id].winner == target then
      if not (player.dead or target.dead or player:isNude()) then
        local cards2 = room:askForCard(player, 1, 1, true, self.name, false, ".", "#ty_heg__fenglve-give::" .. target.id)
        room:obtainCard(target, cards2[1], false, fk.ReasonGive)
      end
    end
    if player.dead or target.dead then return false end
    local choices = {"ty_heg__fenglve_mn_ask::" .. target.id, "Cancel"}
    if room:askForChoice(player, choices, self.name) ~= "Cancel" then
      room:setPlayerMark(target, "@@ty_heg__fenglve_manoeuvre", 1)
      room:handleAddLoseSkills(target, "ty_heg__fenglve_manoeuvre", nil)
    end
  end,
}

local fenglve_mn = fk.CreateActiveSkill{
  name = "ty_heg__fenglve_manoeuvre",
  anim_type = "control",
  prompt = "#ty_heg__fenglve-active",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0 and not player:isKongcheng()
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id and not Fk:currentRoom():getPlayerById(to_select):isKongcheng()
  end,
  on_use = function (self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local pindian = player:pindian({target}, self.name)
    if pindian.results[target.id].winner == player then
      if not (player.dead or target.dead or target:isNude()) then
        local cards1 = room:askForCardChosen(target, target, "hej", self.name)
        room:obtainCard(player, cards1, false, fk.ReasonGive)
      end
    elseif pindian.results[target.id].winner == target then
      if not (player.dead or target.dead or player:isNude()) then
        local cards = player:getCardIds("he")
        if #cards > 2 then
          cards = room:askForCard(player, 2, 2, true, self.name, false, ".", "#ty_heg__fenglve-give::" .. target.id .. ":" .. tostring(2))
        end
        room:moveCardTo(cards, Player.Hand, target, fk.ReasonGive, self.name, nil, false, player.id)
      end
    end
  end,
}

local fenglve_mn_detach = fk.CreateTriggerSkill{
  name = "#ty_heg__fenglve_manoeuvre_detach",
  refresh_events = {fk.AfterTurnEnd},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill("ty_heg__fenglve_manoeuvre", true, true)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:handleAddLoseSkills(player, "-ty_heg__fenglve_manoeuvre", nil)
    room:setPlayerMark(player, "@@ty_heg__fenglve_manoeuvre", 0)
  end,
}

fenglve_mn:addRelatedSkill(fenglve_mn_detach)
Fk:addSkill(fenglve_mn)
xunchen:addSkill(anyong)
xunchen:addSkill(fenglve)

Fk:loadTranslationTable{
  ["ty_heg__xunchen"] = "荀谌",
  ["#ty_heg__xunchen"] = "三公谋主",
  ["designer:ty_heg__xunchen"] = "韩旭",
  ["illustrator:ty_heg__xunchen"] = "凝聚永恒",
  ["ty_heg__fenglve"] = "锋略",
  [":ty_heg__fenglve"] = "出牌阶段限一次，你可和一名其他角色拼点，若你赢，该角色交给你其区域内的两张牌；若其赢，你交给其一张牌。"..
  "<br><font color=\"blue\">◆纵横：交换〖锋略〗描述中的“一张牌”和“两张牌”。<font><br><font color=\"grey\">\"<b>纵横</b>\"："..
  "当拥有“纵横”效果技能发动结算完成后，可以令技能目标角色获得对应修订描述后的技能，直到其下回合结束。",

  ["#ty_heg__fenglve-active"] = "发动“锋略”，与一名角色拼点",
  ["#ty_heg__fenglve-give"] = "锋略：选择 %arg 张牌交给 %dest",
  ["ty_heg__fenglve_mn_ask"] = "令%dest获得〖锋略（纵横）〗直到其下回合结束",
  ["@@ty_heg__fenglve_manoeuvre"] = "锋略 纵横",

  ["ty_heg__fenglve_manoeuvre"] = "锋略⇋",
  [":ty_heg__fenglve_manoeuvre"] = "出牌阶段限一次，你可以和一名其他角色拼点，若你赢，该角色交给你其区域内的一张牌；若其赢，你交给其两张牌。",

  ["ty_heg__anyong"] = "暗涌",
  ["#ty_heg__anyong-invoke"] = "暗涌：是否令 %src 对 %dest 造成的 %arg 点伤害翻倍！",
  [":ty_heg__anyong"] = "每回合限一次，当与你势力相同的一名角色对另一名其他角色造成伤害时，你可令此伤害翻倍，然后若受到伤害的角色："..
  "武将牌均明置，你失去1点体力并失去此技能；只明置了一张武将牌，你弃置两张手牌。",

  ["$ty_heg__fenglve1"] = "冀州宝地，本当贤者居之。",
  ["$ty_heg__fenglve2"] = "当今敢称贤者，唯袁氏本初一人。",
  ["$ty_heg__anyong1"] = "冀州暗潮汹涌，群仕居危思变。",
  ["$ty_heg__anyong2"] = "殿上太守且相看，殿下几人还拥韩。",
  ["~ty_heg__xunchen"] = "为臣当不贰，贰臣不当为。",
}

local jianggan = General(extension, "ty_heg__jianggan", "wei", 3)
local weicheng = fk.CreateTriggerSkill{
  name = "ty_heg__weicheng",
  anim_type = "drawcard",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self) or player:getHandcardNum() >= player.hp then return false end
    for _, move in ipairs(data) do
      if move.from and move.from == player.id and move.to and move.to ~= player.id and move.toArea == Card.PlayerHand then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}
local daoshu = fk.CreateActiveSkill{
  name = "ty_heg__daoshu",
  card_num = 0,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id and not Fk:currentRoom():getPlayerById(to_select):isKongcheng()
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local suits = {"log_spade", "log_club", "log_heart", "log_diamond"}
    local choice = room:askForChoice(player, suits, self.name)
    room:sendLog{
      type = "#ty_heg__DaoshuLog",
      from = player.id,
      to = effect.tos,
      arg = choice,
      arg2 = self.name,
      toast = true,
    }
    local card = room:askForCardChosen(player, target, "h", self.name)
    room:obtainCard(player, card, true, fk.ReasonPrey)
    if Fk:getCardById(card):getSuitString(true) == choice then
      room:damage{
        from = player,
        to = target,
        damage = 1,
        skillName = self.name,
      }
      player:addSkillUseHistory(self.name, -1)
    else
      local suit = Fk:getCardById(card):getSuitString(true)
      table.removeOne(suits, suit)
      suits = table.map(suits, function(s) return s:sub(5) end)
      local others = table.filter(player:getCardIds(Player.Hand), function(id) return Fk:getCardById(id):getSuitString(true) ~= suit end)
      if #others > 0 then
        local cards = room:askForCard(player, 1, 1, false, self.name, false, ".|.|"..table.concat(suits, ","),
          "#ty_heg__daoshu-give::"..target.id..":"..suit)
        if #cards > 0 then
          cards = cards[1]
        else
          cards = table.random(others)
        end
        room:obtainCard(target, cards, true, fk.ReasonGive)
      else
        player:showCards(player:getCardIds(Player.Hand))
      end
    end
  end,
}
jianggan:addSkill(weicheng)
jianggan:addSkill(daoshu)
Fk:loadTranslationTable{
  ["ty_heg__jianggan"] = "蒋干",
  ["#ty_heg__jianggan"] = "锋谪悬信",
  ["designer:ty_heg__jianggan"] = "韩旭",
  ["illustrator:ty_heg__jianggan"] = "biou09",
  ["ty_heg__weicheng"] = "伪诚",
  [":ty_heg__weicheng"] = "你交给其他角色手牌，或你的手牌被其他角色获得后，若你的手牌数小于体力值，你可以摸一张牌。",
  ["ty_heg__daoshu"] = "盗书",
  [":ty_heg__daoshu"] = "出牌阶段限一次，你可以选择一名其他角色并选择一种花色，然后获得其一张手牌。若此牌与你选择的花色："..
  "相同，你对其造成1点伤害且此技能视为未发动过；不同，你交给其一张其他花色的手牌（若没有需展示所有手牌）。",
  ["#ty_heg__DaoshuLog"] = "%from 对 %to 发动了 “%arg2”，选择了 %arg",
  ["#ty_heg__daoshu-give"] = "盗书：交给 %dest 一张非%arg手牌",

  ["$ty_heg__weicheng1"] = "略施谋略，敌军便信以为真。",
  ["$ty_heg__weicheng2"] = "吾只观雅规，而非说客。",
  ["$ty_heg__daoshu1"] = "得此文书，丞相定可高枕无忧。",
  ["$ty_heg__daoshu2"] = "让我看看，这是什么机密。",
  ["~ty_heg__jianggan"] = "丞相，再给我一次机会啊！",
}

local zhouyi = General(extension, "ty_heg__zhouyi", "wu", 3,3,General.Female)
local zhukou = fk.CreateTriggerSkill{
  name = "ty_heg__zhukou",
  anim_type = "offensive",
  events = {fk.Damage},
  can_trigger = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self)) then return end
    local room = player.room
    if room.current and room.current.phase == Player.Play then
      local damage_event = room.logic:getCurrentEvent()
      if not damage_event then return false end
      local events = room.logic:getActualDamageEvents(1, function(e)
        return e.data[1].from == player
      end, Player.HistoryPhase)
      if #events > 0 and damage_event.id == events[1].id then
        local n = #room.logic:getEventsOfScope(GameEvent.UseCard, 999, function(e)
          return e.data[1].from == player.id
        end, Player.HistoryTurn)
        if n > 0 then
          self.cost_data = n
          return true
        end
      end
    end
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, data, "#ty_heg__zhukou:::" .. self.cost_data)
  end,
  on_use = function(self, event, target, player, data)
    local n = self.cost_data
    player:drawCards(math.min(5, n), self.name)
  end,
}

local duannian = fk.CreateTriggerSkill{
  name = "ty_heg__duannian",
  anim_type = "drawcard",
  events = {fk.EventPhaseEnd},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Play and not player:isKongcheng()
  end,
  on_use = function(self, event, target, player, data)
    player.room:throwCard(player:getCardIds("h"), self.name, player, player)
    if player.dead then return end
    player:drawCards(player.maxHp - player:getHandcardNum(), self.name)
  end,
}

local lianyou = fk.CreateTriggerSkill{
  name = "ty_heg__lianyou",
  anim_type = "control",
  events = {fk.Death},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self, false, true)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = table.map(table.filter(room.alive_players,  function(p)
      return not p:hasSkill(self) end), Util.IdMapper)
    if #targets > 0 then
      local to = room:askForChoosePlayers(player, targets, 1, 1, "#ty_heg__lianyou-choose", self.name, true)
      if #to > 0 then
        to = to[1]
        room:handleAddLoseSkills(room:getPlayerById(to), "xinghuo")
      end
    end
  end,
}

local xinghuo = fk.CreateTriggerSkill{
  name = "xinghuo",
  frequency = Skill.Compulsory,
  anim_type = "offensive",
  events = {fk.DamageCaused},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and data.damageType == fk.FireDamage and data.from == player
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.damage = data.damage + 1
  end,
}

zhouyi:addSkill(zhukou)
zhouyi:addSkill(duannian)
zhouyi:addSkill(lianyou)
zhouyi:addRelatedSkill(xinghuo)

Fk:loadTranslationTable{
  ["ty_heg__zhouyi"] = "周夷",
  ["#ty_heg__zhouyi"] = "靛情雨黛",
  ["designer:ty_heg__zhouyi"] = "韩旭",
  ["illustrator:ty_heg__zhouyi"] = "Tb罗根",

  ["ty_heg__zhukou"] = "逐寇",
  [":ty_heg__zhukou"] = "当你于每回合的出牌阶段首次造成伤害后，你可摸X张牌（X为本回合你已使用的牌数且至多为5）。",
  ["ty_heg__duannian"] = "断念",
  [":ty_heg__duannian"] = "出牌阶段结束时，你可弃置所有手牌，然后将手牌摸至体力上限。",
  ["ty_heg__lianyou"] = "莲佑",
  [":ty_heg__lianyou"] = "当你死亡时，你可令一名其他角色获得“兴火”。",
  ["#ty_heg__lianyou-choose"] = "莲佑：选择一名角色，其获得“兴火”。",
  ["xinghuo"] = "兴火",
  [":xinghuo"] = "锁定技，当你造成火属性伤害时，你令此伤害+1。",

  ["#ty_heg__zhukou"] = "逐寇：你可摸 %arg 张牌",

  ["$ty_heg__zhukou1"] = "草莽贼寇，不过如此。",
  ["$ty_heg__zhukou2"] = "轻装上阵，利剑出鞘。",
  ["$ty_heg__duannian1"] = "断思量，莫思量。",
  ["$ty_heg__duannian2"] = "一别两宽，不负相思。",
  ["$xinghuo1"] = "莲花佑兴，业火可兴。",
  ["$xinghuo2"] = "昔日莲花开，今日红火燃。",
  ["~ty_heg__zhouyi"] = "江水寒，萧瑟起……",
}

local lvlingqi = General(extension, "ty_heg__lvlingqi", "qun", 4,4,General.Female)
lvlingqi.mainMaxHpAdjustedValue = -1

local guowu = fk.CreateTriggerSkill{
  name = "ty_heg__guowu",
  anim_type = "offensive",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Play and not player:isKongcheng()
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = player:getCardIds(Player.Hand)
    player:showCards(cards)
    room:delay(300)
    local types = {}
    for _, id in ipairs(cards) do
      table.insertIfNeed(types, Fk:getCardById(id).type)
    end
    local card = room:getCardsFromPileByRule("slash", 1, "discardPile")
    if #card > 0 then
      room:moveCards({
        ids = card,
        to = player.id,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonJustMove,
        proposer = player.id,
        skillName = self.name,
      })
    end
    if #types > 1 then
      room:addPlayerMark(player, "guowu2-phase", 1)
    end
    if #types > 2 then
      room:addPlayerMark(player, "guowu3-phase", 1)
    end
  end,
}


local guowu_delay = fk.CreateTriggerSkill{
  name = "#ty_heg__guowu_delay",
  anim_type = "offensive",
  frequency = Skill.Compulsory,
  events = {fk.CardUsing},
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:getMark("guowu3-phase") > 0 and not player.dead and
      (data.card.trueName == "slash") and #player.room:getUseExtraTargets(data) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = room:getUseExtraTargets(data)
    if #targets == 0 then return false end
    local tos = room:askForChoosePlayers(player, targets, 1, 2, "#guowu-choose:::"..data.card:toLogString(), guowu.name, true)
    if #tos > 0 then
      table.forEach(tos, function (id)
        table.insert(data.tos, {id})
      end)
      room:removePlayerMark(player, "guowu3-phase", 1)
    end
  end,
}
local guowu_targetmod = fk.CreateTargetModSkill{
  name = "#ty_heg__guowu_targetmod",
  bypass_distances =  function(self, player)
    return player:getMark("guowu2-phase") > 0
  end,
}

local wushuangZR = fk.CreateTriggerSkill{
  name = "ty_heg__zhuanrong_hs_wushuang",
  anim_type = "offensive",
  frequency = Skill.Compulsory,
  events = {fk.TargetSpecified, fk.TargetConfirmed},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self) then
      return false
    end
    if event == fk.TargetSpecified then
      return target == player and table.contains({ "slash", "duel" }, data.card.trueName)
    else
      return data.to == player.id and data.card.trueName == "duel"
    end
  end,
  on_use = function(self, event, target, player, data)
    data.fixedResponseTimes = data.fixedResponseTimes or {}
    if data.card.trueName == "slash" then
      data.fixedResponseTimes["jink"] = 2
    else
      data.fixedResponseTimes["slash"] = 2
      data.fixedAddTimesResponsors = data.fixedAddTimesResponsors or {}
      table.insert(data.fixedAddTimesResponsors, (event == fk.TargetSpecified and data.to or data.from))
    end
  end,
}

local zhuangrong = fk.CreateActiveSkill{
  name = "ty_heg__zhuangrong",
  anim_type = "offensive",
  card_num = 1,
  target_num = 0,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0 and not player:isKongcheng()
  end,
  card_filter = function(self, to_select, selected)
    local card = Fk:getCardById(to_select)
    return #selected == 0 and card.type == Card.TypeTrick and not Self:prohibitDiscard(to_select)
  end,
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from, from)
    if from.dead then return end
    room:setPlayerMark(from, "@@ty_heg__zhuanrong_hs_wushuang", 1)
    room:handleAddLoseSkills(from, "ty_heg__zhuanrong_hs_wushuang", nil)
  end,
}

local zhuangrong_refresh = fk.CreateTriggerSkill{
  name = "#ty_heg__zhuangrong_refresh",
  refresh_events = {fk.EventPhaseEnd},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill("ty_heg__zhuanrong_hs_wushuang", true, true)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:handleAddLoseSkills(player, "-ty_heg__zhuanrong_hs_wushuang", nil)
    room:setPlayerMark(player, "@@ty_heg__zhuanrong_hs_wushuang", 0)
  end,
}

local shenwei = fk.CreateTriggerSkill{
  name = "ty_heg__shenwei",
  relate_to_place = "m",
  anim_type = "drawcard",
  events = {fk.DrawNCards},
  frequency = Skill.Compulsory,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Draw and
      table.every(player.room.alive_players, function(p) return player.hp >= p.hp end)
  end,
  on_use = function(self, event, target, player, data)
    data.n = data.n + 2
  end,
}

local shenwei_maxcards = fk.CreateMaxCardsSkill{
  name = "#ty_heg__shenwei_maxcards",
  fixed_func = function(self, player)
    if player:hasShownSkill(shenwei) then
      return player.hp + 2
    end
  end
}

guowu:addRelatedSkill(guowu_delay)
guowu:addRelatedSkill(guowu_targetmod)
lvlingqi:addSkill(guowu)
lvlingqi:addRelatedSkill(wushuangZR)
zhuangrong:addRelatedSkill(zhuangrong_refresh)
lvlingqi:addSkill(zhuangrong)
shenwei:addRelatedSkill(shenwei_maxcards)
lvlingqi:addSkill(shenwei)

Fk:loadTranslationTable{
  ["ty_heg__lvlingqi"] = "吕玲绮",
  ["#ty_heg__lvlingqi"] = "无双虓姬",
  ["designer:ty_heg__lvlingqi"] = "xat1k",
  ["illustrator:ty_heg__lvlingqi"] = "君桓文化",

  ["ty_heg__guowu"] = "帼武",
  ["#ty_heg__guowu_delay"] = "帼武",
  [":ty_heg__guowu"] = "出牌阶段开始时，你可展示所有手牌，若包含的类别数：不小于1，你从弃牌堆中获得一张【杀】；不小于2，你本阶段使用牌无距离限制；"..
  "不小于3，你本阶段使用【杀】可以多指定两个目标（限一次）。",
  ["ty_heg__zhuangrong"] = "妆戎",
  [":ty_heg__zhuangrong"] = "出牌阶段限一次，你可以弃置一张锦囊牌，然后获得“无双”至此阶段结束。",
  ["ty_heg__shenwei"] = "神威",
  [":ty_heg__shenwei"] = "主将技，此武将牌上单独的阴阳鱼个数-1。①摸牌阶段，若你的体力值为全场最高，你多摸两张牌。②你的手牌上限+2。",
  ["ty_heg__zhuanrong_hs_wushuang"] = "无双",
  ["@@ty_heg__zhuanrong_hs_wushuang"] = "无双",
  [":ty_heg__zhuanrong_hs_wushuang"] = "锁定技，当你使用【杀】指定一个目标后，该角色需依次使用两张【闪】才能抵消此【杀】；当你使用【决斗】指定一个目标后，或成为一名角色使用【决斗】的目标后，该角色每次响应此【决斗】需依次打出两张【杀】。",
  ["#ty_heg__guowu-choose"] = "帼武：你可以为%arg增加至多两个目标",

  ["$ty_heg__guowu1"] = "方天映黛眉，赤兔牵红妆。",
  ["$ty_heg__guowu2"] = "武姬青丝利，巾帼女儿红。",
  ["$ty_heg__shenwei1"] = "锋镝鸣手中，锐戟映秋霜。",
  ["$ty_heg__shenwei2"] = "红妆非我愿，学武觅封侯。",
  ["$ty_heg__zhuangrong1"] = "继父神威，无坚不摧！",
  ["$ty_heg__zhuangrong2"] = "我乃温侯吕奉先之女！",
  ["$ty_heg__wushuang1"] = "猛将策良骥，长戟破敌营。",
  ["$ty_heg__wushuang2"] = "杀气腾剑戟，严风卷戎装。",
  ["~ty_heg__lvlingqi"] = "父亲，女儿好累……",
}

local nanhualaoxian = General(extension, "ty_heg__nanhualaoxian", "qun", 4)
local gongxiu = fk.CreateTriggerSkill{
  name = "ty_heg__gongxiu",
  anim_type = "offensive",
  events = {fk.DrawNCards},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.n > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askForSkillInvoke(player, self.name, data, "#ty_heg__gongxiu_" .. player:getMark("ty_heg__gongxiu") .. "-ask:::" .. player.maxHp)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.n = data.n - 1
    local choices = {}
    if player:getMark("ty_heg__gongxiu") ~= 1 then
      table.insert(choices, "ty_heg__gongxiu_draw:::" .. player.maxHp)
    end
    if player:getMark("ty_heg__gongxiu") ~= 2 then
      table.insert(choices, "ty_heg__gongxiu_discard:::" .. player.maxHp)
    end 
    local choice = room:askForChoice(player, choices, self.name, "#ty_heg__gongxiu-choice")
    local targets, tos
    if choice:startsWith("ty_heg__gongxiu_draw") then
      room:setPlayerMark(player, "ty_heg__gongxiu", 1)
      targets = table.map(room.alive_players, Util.IdMapper)
      tos = room:askForChoosePlayers(player, targets, 1, player.maxHp, "#ty_heg__gongxiu_draw-choose:::" .. player.maxHp, self.name, false)
      room:sortPlayersByAction(tos)
      for _, id in ipairs(tos) do
        local p = room:getPlayerById(id)
        if not p.dead then
          p:drawCards(1, self.name)
        end
      end
    else
      room:setPlayerMark(player, "ty_heg__gongxiu", 2)
      targets = table.map(table.filter(room.alive_players,  function(p) return not p:isNude() end), Util.IdMapper)
      tos = room:askForChoosePlayers(player, targets, 1, player.maxHp, "#ty_heg__gongxiu_discard-choose:::" .. player.maxHp, self.name, false)
      room:sortPlayersByAction(tos)
      for _, id in ipairs(tos) do
        local p = room:getPlayerById(id)
        if not p.dead and not p:isNude() then
          room:askForDiscard(p, 1, 1, true, self.name, false)
        end
      end
    end
  end,
}

local jinghe = fk.CreateActiveSkill{
  name = "ty_heg__jinghe",
  anim_type = "support",
  min_card_num = 1,
  min_target_num = 1,
  prompt = "#ty_heg__jinghe",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0 and not player:isKongcheng()
  end,
  card_filter = function(self, to_select, selected)
    if #selected < Self.maxHp and Fk:currentRoom():getCardArea(to_select) == Player.Hand then
      if #selected == 0 then
        return true
      else
        return table.every(selected, function(id) return Fk:getCardById(to_select).trueName ~= Fk:getCardById(id).trueName end)
      end
    end
  end,
  target_filter = function(self, to_select, selected, selected_cards)
    return #selected < #selected_cards and H.getGeneralsRevealedNum(Fk:currentRoom():getPlayerById(to_select)) > 0
  end,
  feasible = function (self, selected, selected_cards)
    return #selected > 0 and #selected == #selected_cards
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    room:setPlayerMark(player, "ty_heg__jinghe_used", 1)
    player:showCards(effect.cards)
    room:sortPlayersByAction(effect.tos)

    local num = 0 + #effect.tos
    local skills = table.random({"ty_heg__leiji", "ty_heg__yinbingn", "ty_heg__huoqi", "ty_heg__guizhu", "ty_heg__xianshou", "ty_heg__lundao", "ty_heg__guanyue", "ty_heg__yanzhengn"}, num)
    local selected = {}
    for _, id in ipairs(effect.tos) do
      local p = room:getPlayerById(id)
      if not p.dead then
        local choices = table.filter(skills, function(s) return not p:hasSkill(s, true) and not table.contains(selected, s) end)
        if #choices > 0 then
          local choice = room:askForChoice(p, choices, self.name, "#ty_heg__jinghe-choice:::"..#skills, true, skills)
          room:setPlayerMark(p, self.name, choice)
          table.insert(selected, choice)
          room:handleAddLoseSkills(p, choice, nil, true, false)
        end
      end
    end
  end,
}
local jinghe_trigger = fk.CreateTriggerSkill {
  name = "#ty_heg__jinghe_trigger",
  mute = true,
  events = {fk.TurnStart, fk.BuryVictim},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:getMark("ty_heg__jinghe_used") > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "ty_heg__jinghe_used", 0)
    for _, p in ipairs(room.alive_players) do
      if p:getMark("ty_heg__jinghe") ~= 0 then
        local skill = p:getMark("ty_heg__jinghe")
        room:setPlayerMark(p, "ty_heg__jinghe", 0)
        room:handleAddLoseSkills(p, "-"..skill, nil, true, false)
      end
    end
  end,
}


local ty_heg__leiji = fk.CreateTriggerSkill{
  name = "ty_heg__leiji",
  anim_type = "offensive",
  events = {fk.CardUsing, fk.CardResponding},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and target == player and data.card.name == "jink"
  end,
  on_cost = function(self, event, target, player, data)
    local to = player.room:askForChoosePlayers(player, table.map(player.room:getOtherPlayers(player, false), Util.IdMapper), 1, 1, "#ty_heg__leiji-choose", self.name, true)
    if #to > 0 then
      self.cost_data = to[1]
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tar = room:getPlayerById(self.cost_data)
    local judge = {
      who = tar,
      reason = self.name,
      pattern = ".|.|spade",
    }
    room:judge(judge)
    if judge.card.suit == Card.Spade then
      room:damage{
        from = player,
        to = tar,
        damage = 2,
        damageType = fk.ThunderDamage,
        skillName = self.name,
      }
    end
end,
}
local ty_heg__yinbingn = fk.CreateTriggerSkill{
  name = "ty_heg__yinbingn",
  anim_type = "offensive",
  frequency = Skill.Compulsory,
  events = {fk.PreDamage, fk.HpLost},
  can_trigger = function(self, event, target, player, data)
    if player:hasSkill(self) then
      if event == fk.PreDamage then
        return target == player and data.card and data.card.trueName == "slash"
      else
        return target ~= player
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if event == fk.PreDamage then
      room:loseHp(data.to, data.damage, self.name)
      return true
    else
      player:drawCards(1, self.name)
    end
  end,
}
local ty_heg__huoqi = fk.CreateActiveSkill{
  name = "ty_heg__huoqi",
  anim_type = "support",
  card_num = 1,
  target_num = 1,
  prompt = "#huoqi",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0 and not player:isNude()
  end,
  card_filter = function(self, to_select, selected)
    return #selected == 0
  end,
  target_filter = function(self, to_select, selected)
    if #selected == 0 then
      local target = Fk:currentRoom():getPlayerById(to_select)
      return target:isWounded() and table.every(Fk:currentRoom().alive_players, function(p) return target.hp <= p.hp end)
    end
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    room:throwCard(effect.cards, self.name, player, player)
    if target:isWounded() then
      room:recover({
        who = target,
        num = 1,
        recoverBy = player,
        skillName = self.name
      })
    end
    if not target.dead then
      target:drawCards(1, self.name)
    end
  end,
}
local ty_heg__guizhu = fk.CreateTriggerSkill{
  name = "ty_heg__guizhu",
  anim_type = "drawcard",
  events = {fk.EnterDying},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and player:usedSkillTimes(self.name, Player.HistoryTurn) == 0
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(2, self.name)
  end,
}
local ty_heg__xianshou = fk.CreateActiveSkill{
  name = "ty_heg__xianshou",
  anim_type = "support",
  card_num = 0,
  target_num = 1,
  prompt = "#xianshou",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, to_select, selected)
    return #selected == 0
  end,
  on_use = function(self, room, effect)
    local target = room:getPlayerById(effect.tos[1])
    local n = not target:isWounded() and 2 or 1
    target:drawCards(n, self.name)
  end
}
local ty_heg__lundao = fk.CreateTriggerSkill{
  name = "ty_heg__lundao",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.from and not data.from.dead and
      data.from:getHandcardNum() ~= player:getHandcardNum()
  end,
  on_cost = function(self, event, target, player, data)
    if data.from:getHandcardNum() > player:getHandcardNum() then
      return player.room:askForSkillInvoke(player, self.name, nil, "#ty_heg__lundao-invoke::"..data.from.id)
    else
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if data.from:getHandcardNum() > player:getHandcardNum() then
      room:doIndicate(player.id, {from.id})
      local id = room:askForCardChosen(player, from, "he", self.name)
      room:throwCard({id}, self.name, from, player)
    else
      player:drawCards(1, self.name)
    end
  end
}
local ty_heg__guanyue = fk.CreateTriggerSkill{
  name = "ty_heg__guanyue",
  anim_type = "control",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Finish
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local result = room:askForGuanxing(player, room:getNCards(2), {1, 2}, {1, 1}, self.name, true, {"Top", "prey"})
    if #result.top > 0 then
      table.removeOne(room.draw_pile, result.top[1])
      table.insert(room.draw_pile, 1, result.top[1])
      room:sendLog{
        type = "#GuanxingResult",
        from = player.id,
        arg = 1,
        arg2 = 0,
      }
    end
    if #result.bottom > 0 then
      room:obtainCard(player.id, result.bottom[1], false, fk.ReasonJustMove)
    end
  end,
}
local ty_heg__yanzhengn = fk.CreateTriggerSkill{
  name = "ty_heg__yanzhengn",
  anim_type = "offensive",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player.phase == Player.Start and player:getHandcardNum() > 1
  end,
  on_cost = function(self, event, target, player, data)
    local targets = table.map(player.room.alive_players, Util.IdMapper)
    local tos, card = player.room:askForChooseCardAndPlayers(player, targets, 1, player:getHandcardNum() - 1, ".|.|.|hand",
      "#yanzhengn-invoke:::"..(player:getHandcardNum() - 1), self.name, true)
    if #tos > 0 and card then
      player.room:sortPlayersByAction(tos)
      self.cost_data = {tos, card}
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = player:getCardIds("h")
    table.removeOne(ids, self.cost_data[2])
    room:throwCard(ids, self.name, player, player)
    for _, id in ipairs(self.cost_data[1]) do
      local p = room:getPlayerById(id)
      if not p.dead then
        room:damage{
          from = player,
          to = p,
          damage = 1,
          skillName = self.name,
        }
      end
    end
  end,
}
nanhualaoxian:addSkill(gongxiu)
nanhualaoxian:addSkill(jinghe)
jinghe:addRelatedSkill(jinghe_trigger)

nanhualaoxian:addRelatedSkill(ty_heg__leiji)
nanhualaoxian:addRelatedSkill(ty_heg__yinbingn)
nanhualaoxian:addRelatedSkill(ty_heg__huoqi)
nanhualaoxian:addRelatedSkill(ty_heg__guizhu)
nanhualaoxian:addRelatedSkill(ty_heg__xianshou)
nanhualaoxian:addRelatedSkill(ty_heg__lundao)
nanhualaoxian:addRelatedSkill(ty_heg__guanyue)
nanhualaoxian:addRelatedSkill(ty_heg__yanzhengn)
Fk:loadTranslationTable{
  ["ty_heg__nanhualaoxian"] = "南华老仙",
  ["#ty_heg__nanhualaoxian"] = "仙人指路",
  ["designer:ty_heg__nanhualaoxian"] = "韩旭",
  ["illustrator:ty_heg__nanhualaoxian"] = "君桓文化",

  ["ty_heg__gongxiu"] = "共修",
  [":ty_heg__gongxiu"] = "摸牌阶段，你可少摸一张牌，然后选择一项：1.令至多X名角色各摸一张牌；"..
  "2.令至多X名角色各弃置一张牌。（X为你的体力上限，不能连续选择同一项）",
  ["ty_heg__jinghe"] = "经合",
  [":ty_heg__jinghe"] = "出牌阶段限一次，你可展示至多X张牌名各不同的手牌并选择等量有明置武将牌的角色，从“写满技能的天书”随机展示X个技能，这些角色依次选择并"..
  "获得其中一个技能，直到你下回合开始 （X为你的体力上限）。",

  ["#ty_heg__gongxiu-choice"] = "共修：选择令角色摸牌或弃牌",
  ["#ty_heg__gongxiu_0-ask"] = "是否发动 共修，令至多%arg名角色各摸一张牌或各弃置一张牌",
  ["#ty_heg__gongxiu_1-ask"] = "是否发动 共修，令至多%arg名角色各弃置一张牌",
  ["#ty_heg__gongxiu_2-ask"] = "是否发动 共修，令至多%arg名角色各摸一张牌",
  ["ty_heg__gongxiu_draw"] = "令至多%arg名角色各摸一张牌",
  ["ty_heg__gongxiu_discard"] = "令至多%arg名角色各弃置一张牌",

  ["#ty_heg__gongxiu_draw-choose"] = "共修：选择至多%arg名角色各摸一张牌",
  ["#ty_heg__gongxiu_discard-choose"] = "共修：选择至多%arg名角色各弃置一张牌",

  ["#ty_heg__jinghe"] = "经合：展示至多四张牌名各不同的手牌，令等量的角色获得技能",
  ["#ty_heg__jinghe-choice"] = "经合：选择你要获得的技能",
  ["ty_heg__leiji"] = "雷击",
  [":ty_heg__leiji"] = "当你使用或打出【闪】时，你可以令一名其他角色进行一次判定，若结果为：♠，你对其造成2点雷电伤害。",
  ["#ty_heg__leiji-choose"] = "雷击：令一名角色进行判定，若为♠，你对其造成2点雷电伤害。",
  ["ty_heg__yinbingn"] = "阴兵",
  [":ty_heg__yinbingn"] = "锁定技，你使用【杀】即将造成的伤害视为失去体力。当其他角色失去体力后，你摸一张牌。",
  ["ty_heg__huoqi"] = "活气",
  [":ty_heg__huoqi"] = "出牌阶段限一次，你可以弃置一张牌，然后令一名体力最少的角色回复1点体力并摸一张牌。",
  ["#ty_heg__huoqi"] = "活气：弃置一张牌，令一名体力最少的角色回复1点体力并摸一张牌",
  ["ty_heg__guizhu"] = "鬼助",
  [":ty_heg__guizhu"] = "每回合限一次，当一名角色进入濒死状态时，你可以摸两张牌。",
  ["ty_heg__xianshou"] = "仙授",
  [":ty_heg__xianshou"] = "出牌阶段限一次，你可以令一名角色摸一张牌。若其未受伤，则多摸一张牌。",
  ["#ty_heg__xianshou"] = "仙授：令一名角色摸一张牌，若其未受伤则多摸一张牌",
  ["ty_heg__lundao"] = "论道",
  [":ty_heg__lundao"] = "当你受到伤害后，若伤害来源的手牌多于你，你可以弃置其一张牌；若伤害来源的手牌数少于你，你摸一张牌。",
  ["#ty_heg__lundao-invoke"] = "论道：你可以弃置 %dest 一张牌",
  ["ty_heg__guanyue"] = "观月",
  [":ty_heg__guanyue"] = "结束阶段，你可以观看牌堆顶的两张牌，然后获得其中一张，将另一张置于牌堆顶。",
  ["prey"] = "获得",
  ["ty_heg__yanzhengn"] = "言政",
  [":ty_heg__yanzhengn"] = "准备阶段，若你的手牌数大于1，你可以选择一张手牌并弃置其余的牌，然后对至多等于弃置牌数的角色各造成1点伤害。",
  ["#ty_heg__yanzhengn-invoke"] = "言政：你可以选择保留一张手牌，弃置其余的手牌，对至多%arg名角色各造成1点伤害",

  ["$ty_heg__gongxiu1"] = "福祸与共，业山可移。",
  ["$ty_heg__gongxiu2"] = "修行退智，遂之道也。",
  ["$ty_heg__jinghe1"] = "大哉乾元，万物资始。",
  ["$ty_heg__jinghe2"] = "无极之外，复无无极。",
  ["~ty_heg__nanhualaoxian"] = "道亦有穷时……",
}
return extension
