local extension = Package:new("overseas_heg")
extension.extensionName = "hegemony"
extension.game_modes_whitelist = { 'nos_heg_mode', 'new_heg_mode' }

local H = require "packages/hegemony/util"
local U = require "packages/utility/utility"

Fk:loadTranslationTable{
  ["overseas_heg"] = "国战-国际服专属",
  ["os_heg"] = "国际",
}

local yangxiu = General(extension, "os_heg__yangxiu", "wei", 3)
yangxiu:addSkill("danlao")
yangxiu:addSkill("jilei")
Fk:loadTranslationTable{
  ['os_heg__yangxiu'] = '杨修',
  ["#os_heg__yangxiu"] = "恃才放旷",
  ["designer:os_heg__yangxiu"] = "KayaK",
  ["illustrator:os_heg__yangxiu"] = "张可",
  ["~os_heg__yangxiu"] = "我固自以死之晚也……",
}

local xiahoushang = General(extension, "os_heg__xiahoushang", "wei", 4)
xiahoushang:addCompanions("hs__caopi")
local tanfeng = fk.CreateTriggerSkill{
  name = "os_heg__tanfeng",
  anim_type = "offensive",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and
      player.phase == Player.Start and table.find(player.room.alive_players, function(p) return
        not H.compareKingdomWith(p, player) and not p:isAllNude()
      end)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local availableTargets = table.map(table.filter(room.alive_players, function(p)
        return not H.compareKingdomWith(p, player) and not p:isAllNude() -- not willBeFriendWith，救命！
      end), Util.IdMapper)
    if #availableTargets == 0 then return false end
    target = room:askForChoosePlayers(player, availableTargets, 1, 1, "#os_heg__tanfeng-ask", self.name, true)
    if #target > 0 then
      self.cost_data = target[1]
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    target = room:getPlayerById(self.cost_data)
    local cid = room:askForCardChosen(player, target, "hej", self.name)
    room:throwCard({cid}, self.name, target, player)
    local choices = {"os_heg__tanfeng_damaged::" .. player.id, "Cancel"}
    local slash = Fk:cloneCard("slash")
    slash.skillName = self.name
    local choice = room:askForChoice(target, choices, self.name, nil)
    if choice ~= "Cancel" then
      room:damage{
        from = player,
        to = target,
        damage = 1,
        damageType = fk.FireDamage,
        skillName = self.name,
      }
      if not (target.dead or player.dead) then
        local phase = {"phase_judge", "phase_draw", "phase_play", "phase_discard", "phase_finish"}
        player:skip(table.indexOf(phase, room:askForChoice(target, phase, self.name, "#os_heg__tanfeng-skip:" .. player.id)) + 2)
      end
    end
  end,
}
xiahoushang:addSkill(tanfeng)
Fk:loadTranslationTable{
  ["os_heg__xiahoushang"] = "夏侯尚",
  ["#os_heg__xiahoushang"] = "魏胤前驱",
  ["designer:os_heg__xiahoushang"] = "豌豆&Loun老萌",
  ["illustrator:os_heg__xiahoushang"] = "M云涯",

  ["os_heg__tanfeng"] = "探锋",
  [":os_heg__tanfeng"] = "准备阶段开始时，你可弃置一名没有势力或势力与你不同的角色区域内的一张牌，然后其选择是否受到你造成的1点火焰伤害，令你跳过一个阶段。",

  ["#os_heg__tanfeng-ask"] = "探锋：你可选择一名其他势力角色，弃置其区域内的一张牌", -- 留一下
  ["os_heg__tanfeng_damaged"] = "受到%dest造成的1点火焰伤害，令其跳过一个阶段",
  ["#os_heg__tanfeng-skip"] = "探锋：令 %src 跳过此回合的一个阶段",

  ["$os_heg__tanfeng1"] = "探敌薄防之地，夺敌不备之间。",
  ["$os_heg__tanfeng2"] = "探锋之锐，以待进取之机。",
  ["~os_heg__xiahoushang"] = "陛下垂怜至此，臣纵死无憾……",
}

local liaohua = General(extension, "os_heg__liaohua", "shu", 4)
liaohua:addCompanions("hs__guanyu")
local dangxian = fk.CreateTriggerSkill{
  name = "os_heg__dangxian",
  anim_type = "special",
  frequency = Skill.Compulsory,
  events = {fk.EventPhaseEnd, fk.GeneralRevealed},
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(self) then return false end
    if event == fk.GeneralRevealed then
      if player:usedSkillTimes(self.name, Player.HistoryGame) == 0 then
        for _, v in pairs(data) do
          if table.contains(Fk.generals[v]:getSkillNameList(), self.name) then return true end
        end
      end
    else
      return player.phase == Player.RoundStart
    end
  end,
  on_use = function(self, event, target, player, data)
    if event == fk.GeneralRevealed then
      H.addHegMark(player.room, player, "vanguard")
    else
      player:gainAnExtraPhase(Player.Play)
    end
  end
}
liaohua:addSkill(dangxian)

Fk:loadTranslationTable{
  ['os_heg__liaohua'] = '廖化',
  ["#os_heg__liaohua"] = "历尽沧桑",
  ["designer:os_heg__liaohua"] = "梦魇狂朝",
  ["illustrator:os_heg__liaohua"] = "聚一工作室",

  ["os_heg__dangxian"] = "当先",
  [":os_heg__dangxian"] = "锁定技，当你首次明置此武将牌后，你获得一枚“先驱”标记；回合开始时，你执行一个额外的出牌阶段。",

  ["$os_heg__dangxian1"] = "谁言蜀汉已无大将？",
  ["$os_heg__dangxian2"] = "老将虽白发，宝刀刃犹锋！",
  ["~os_heg__liaohua"] = "兴复大业，就靠你们了……",
}

local chendao = General(extension, "os_heg__chendao", "shu", 4)
chendao:addCompanions("hs__zhaoyun")
chendao:addSkill("wangliec")
Fk:loadTranslationTable{
  ["os_heg__chendao"] = "陈到",
  ["#os_heg__chendao"] = "白毦督",
  ["designer:os_heg__chendao"] = "荼蘼",
  ["illustrator:os_heg__chendao"] = "王立雄",
  ["~os_heg__chendao"] = "我的白毦兵，再也不能为先帝出力了。",
}

local zhugejin = General(extension, "os_heg__zhugejin", "wu", 3)
zhugejin:addCompanions("hs__sunquan")

local huanshi = fk.CreateTriggerSkill{
  name = "os_heg__huanshi",
  anim_type = "control",
  events = {fk.AskForRetrial},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self) and not player:isNude() and H.compareKingdomWith(target, player)
  end,
  on_cost = function(self, event, target, player, data)
    local card = player.room:askForResponse(player, self.name, ".|.|.|hand,equip|.|", "#os_heg__huanshi-ask::" .. target.id .. ":" .. data.reason, true)
    if card then
      self.cost_data = card
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:retrial(self.cost_data, player, data, self.name)
  end,
}

---@param object Card|Player
---@param markname string
---@param suffixes string[]
---@return boolean
local function hasMark(object, markname, suffixes)
  if not object then return false end
  for mark, _ in pairs(object.mark) do
    if mark == markname then return true end
    if mark:startsWith(markname .. "-") then
      for _, suffix in ipairs(suffixes) do
        if mark:find(suffix, 1, true) then return true end
      end
    end
  end
  return false
end

local hongyuan = fk.CreateActiveSkill{
  name = "os_heg__hongyuan",
  anim_type = "support",
  can_use = function(self, player)
    return player:getMark(self.name .. "-phase") == 0 and not player:isKongcheng() -- FIXME
  end,
  card_num = 1,
  card_filter = function(self, to_select, selected)
    if #selected > 0 then return false end
    return Fk:currentRoom():getCardArea(to_select) == Card.PlayerHand and not hasMark(Fk:getCardById(to_select), "@@alliance", MarkEnum.CardTempMarkSuffix)
  end,
  target_filter = Util.FalseFunc,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    room:addPlayerMark(player, self.name .. "-phase")
    local card = effect.cards[1]
    room:setCardMark(Fk:getCardById(card), "@@alliance-inhand-turn", 1)
  end,
}
local hongyuanTrigger = fk.CreateTriggerSkill{
  name = "#os_heg__hongyuan_trigger",
  anim_type = "support",
  mute = true,
  events = {fk.BeforeDrawCard},
  main_skill = hongyuan,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and data.skillName == "alliance&" and table.find(player.room.alive_players, function(p) return H.compareKingdomWith(p, player) and p ~= player end)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = table.map(table.filter(room.alive_players, function(p) return H.compareKingdomWith(p, player) and p ~= player end), Util.IdMapper)
    target = room:askForChoosePlayers(player, targets, 1, 1, "#os_heg__hongyuan-ask:::" .. data.num, self.name, true)
    if #target > 0 then
      self.cost_data = target[1]
      player:revealBySkillName("os_heg__hongyuan") -- FIXME
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    target = self.cost_data
    local room = player.room
    room:notifySkillInvoked(player, "os_heg__hongyuan", "support")
    player:broadcastSkillInvoke("os_heg__hongyuan")
    data.who = room:getPlayerById(target)
  end,
}
hongyuan:addRelatedSkill(hongyuanTrigger)

local mingzhe = fk.CreateTriggerSkill{
  name = "os_heg__mingzhe",
  anim_type = "drawcard",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self) or player.phase ~= Player.NotActive then return end
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if Fk:getCardById(info.cardId).color == Card.Red then
            if info.fromArea == Card.PlayerEquip then
              return true
            end
            if table.contains({fk.ReasonUse, fk.ReasonResonpse}, move.moveReason) 
              and table.contains({Card.PlayerHand, Card.PlayerEquip}, info.fromArea) then
                return true
            end
          end
        end
      end
    end
  end,
  on_trigger = function(self, event, target, player, data)
    local num = 0
    for _, move in ipairs(data) do
      if not player:hasSkill(self) then break end
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if Fk:getCardById(info.cardId).color == Card.Red then
            if info.fromArea == Card.PlayerEquip then
              num = num + 1
            end
            if table.contains({fk.ReasonUse, fk.ReasonResonpse}, move.moveReason)
              and table.contains({Card.PlayerHand, Card.PlayerEquip}, info.fromArea) then
                num = num + 1
            end
          end
        end
      end
    end
    if num == 0 then return end
    for _ = 1, num do
      if not player:hasSkill(self) then return end
      self:doCost(event, nil, player, nil)
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}

zhugejin:addSkill(huanshi)
zhugejin:addSkill(hongyuan)
zhugejin:addSkill(mingzhe)
Fk:loadTranslationTable{
  ["os_heg__zhugejin"] = "诸葛瑾",
  ["#os_heg__zhugejin"] = "联盟的维系者",
  ["designer:os_heg__zhugejin"] = "梦魇狂朝",
  ["illustrator:os_heg__zhugejin"] = "G.G.G.",

  ["os_heg__huanshi"] = "缓释",
  [":os_heg__huanshi"] = "当与你势力相同的角色的判定牌生效前，你可打出一张牌代替之。",
  ["os_heg__hongyuan"] = "弘援",
  [":os_heg__hongyuan"] = "①当你因合纵摸牌时，你可改为令与你势力相同的一名其他角色摸牌。②出牌阶段限一次，你可令一张无合纵标记的手牌于本回合视为有合纵标记。",
  ["os_heg__mingzhe"] = "明哲",
  [":os_heg__mingzhe"] = "当你于回合外{因使用、打出而失去一张红色牌或失去装备区里的红色牌}后，你可摸一张牌。",

  ["#os_heg__huanshi-ask"] = "缓释：你可打出一张牌代替 %dest 的 %arg 判定",
  ["#os_heg__hongyuan-ask"] = "弘援：你将摸%arg张牌，可改为令与你势力相同的一名其他角色摸牌",
  ["#os_heg__hongyuan_trigger"] = "弘援",

  ["$os_heg__huanshi1"] = "缓乐之危急，释兵之困顿。",
  ["$os_heg__huanshi2"] = "尽死生之力，保友邦之安。",
  ["$os_heg__hongyuan1"] = "诸将莫慌，粮草已到。",
  ["$os_heg__hongyuan2"] = "自舍其身，施于天下。",
  ["$os_heg__mingzhe1"] = "明以洞察，哲以保身。",
  ["$os_heg__mingzhe2"] = "塞翁失马，焉知非福。",
  ["~os_heg__zhugejin"] = "君臣不相负，来世复君臣。",
}

local zumao = General(extension, "os_heg__zumao", "wu", 4)
zumao:addSkill("yinbing")
zumao:addSkill("juedi")
Fk:loadTranslationTable{
  ['os_heg__zumao'] = '祖茂',
  ["#os_heg__zumao"] = "碧血染赤帻",
  ["designer:os_heg__zumao"] = "红莲的焰神",
  ["illustrator:os_heg__zumao"] = "DH",
  ["~os_heg__zumao"] = "孙将军，已经，安全了吧……",
}

local fuwan = General(extension, "os_heg__fuwan", "qun", 4)
fuwan:addSkill("moukui")
Fk:loadTranslationTable{
  ['os_heg__fuwan'] = '伏完',
  ["#os_heg__fuwan"] = "沉毅的国丈",
  ["designer:os_heg__fuwan"] = "嘉言懿行",
  ["illustrator:os_heg__fuwan"] = "LiuHeng",
  ["~os_heg__fuwan"] = "后会有期……",
}

local huaxiong = General(extension, "os_heg__huaxiong", "qun", 4)

local yaowu = fk.CreateTriggerSkill{
  name = "os_heg__yaowu",
  frequency = Skill.Limited,
  events = {fk.Damage},
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self) and player:usedSkillTimes(self.name, Player.HistoryGame) == 0 and player:isFakeSkill(self) 
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:changeMaxHp(player, 2)
    if not player.dead then
      room:recover({
        who = player,
        num = 2,
        recoverBy = player,
        skillName = self.name
      })
      player.tag["os_heg__yaowu"] = true -- bury()!
    end
  end,
}
local yaowuDeath = fk.CreateTriggerSkill{
  name = "#os_heg__yaowu_death",
  events = {fk.Deathed},
  anim_type = "negative",
  frequency = Skill.Compulsory,
  can_trigger = function(self, event, target, player, data)
    return target == player and player.tag["os_heg__yaowu"]
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = table.map(table.filter(room.alive_players, function(p) return H.compareKingdomWith(p, player) end), Util.IdMapper)
    if #targets == 0 then return end
    room:doIndicate(player.id, targets)
    room:sortPlayersByAction(targets)
    for _, pid in ipairs(targets) do
      local p = room:getPlayerById(pid)
      if not p.dead then
        room:loseHp(p, 1, self.name)
      end
    end
  end,
}
yaowu:addRelatedSkill(yaowuDeath)

local shiyong = fk.CreateTriggerSkill{
  name = "os_heg__shiyong",
  frequency = Skill.Compulsory,
  events = {fk.Damaged},
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self) and data.card) then return end
    if player:usedSkillTimes(yaowu.name, Player.HistoryGame) == 0 then return data.card.color ~= Card.Red 
    else return data.card.color ~= Card.Black and data.from end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:broadcastSkillInvoke(self.name)
    if player:usedSkillTimes(yaowu.name, Player.HistoryGame) == 0 then
      if data.card.color ~= Card.Red then
        room:notifySkillInvoked(player, self.name, "drawcard")
        player:drawCards(1, self.name)
      end
    elseif data.card.color ~= Card.Black and data.from and not data.from.dead then
      room:notifySkillInvoked(player, self.name, "negative")
      data.from:drawCards(1, self.name)
    end
  end,
}

huaxiong:addSkill(yaowu)
huaxiong:addSkill(shiyong)

Fk:loadTranslationTable{
  ['os_heg__huaxiong'] = '华雄',
  ["#os_heg__huaxiong"] = "魔将",
  ["illustrator:os_heg__huaxiong"] = "地狱许",
  ["designer:os_heg__huaxiong"] = "Loun老萌",

  ["os_heg__yaowu"] = "耀武",
  [":os_heg__yaowu"] = "限定技，当你造成伤害后，若此武将处于暗置状态，你可明置此武将牌，加2点体力上限，回复2点体力，“升级”〖恃勇〗，且当你死亡后，与你势力相同的角色各失去1点体力。",
  ["os_heg__shiyong"] = "恃勇",
  [":os_heg__shiyong"] = "锁定技，当你受到伤害后，1级：若造成伤害的牌不为红色，你摸一张牌；2级：若造成伤害的牌不为黑色，伤害来源摸一张牌。",

  ["#os_heg__yaowu_death"] = "耀武",

  ["$os_heg__yaowu1"] = "潘凤已被我斩了，谁还来领死！",
  ["$os_heg__yaowu2"] = "十八路诸侯？！哼！乌合之众。",
  ["$os_heg__shiyong1"] = "你们不要笑得太早。",
  ["$os_heg__shiyong2"] = "哼，不痛不痒。",
  ["~os_heg__huaxiong"] = "我掉以轻心了……",
}

return extension
