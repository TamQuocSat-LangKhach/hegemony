local H = {}

-- 势力相关

--- 获取势力（野心家为role）
---@param player Player
---@return string
H.getKingdom = function(player)
  local ret = player.kingdom
  if ret == "wild" then
    ret = player.role -- 野心家改为role（即建国势力，新月杀为了胜率统计野心家自动建国）
  end
  return ret
end

--- from与to势力是否相同
---
--- diff为false为相同，true为不同
---@param from Player
---@param to Player
---@param diff boolean?
---@return boolean
function H.compareKingdomWith(from, to, diff)
  if from == to then
    return not diff
  end
  if from.kingdom == "unknown" or to.kingdom == "unknown" then
    return false
  end

  local ret = H.getKingdom(from) == H.getKingdom(to)
  if diff then ret = not ret end
  return ret
end

--- from明置后与to势力是否会相同
---
--- diff为false为相同，true为不同
---@param from Player @ 将明置的角色
---@param to Player @ 另一角色
---@param diff boolean? @ 是否为不同势力
---@return boolean?
H.compareExpectedKingdomWith = function(from, to, diff)
  local room = Fk:currentRoom()
  if from == to then
    return not diff
  end

  if H.compareKingdomWith(from, to) then
    return not diff
  end
  if to.kingdom == "unknown" then
    return not diff
  end
  if from.kingdom == "unknown" then
    local kingdom = from:getMark("__heg_kingdom")
    local i = 1
    local lord = false

    for _, p in ipairs(room.players) do
      if H.getKingdom(p) == kingdom then
        i = i + 1
        if string.find(p.general, "lord") then
          lord = true
        end
      end
    end

    if i > #room.players // 2 and not lord then
      return diff
    elseif kingdom == H.getKingdom(to) then
      return not diff
    end
  end
  return diff
end

--- 获取势力角色数列表，注意键unknown的值为nil
---@param room AbstractRoom @ 房间
---@param include_dead? boolean @ 包括死人
---@return table<string, number> @ 势力与角色数映射表
H.getKingdomPlayersNum = function(room, include_dead)
  local kingdomMapper = {}
  for _, p in ipairs(include_dead and room.players or room.alive_players) do
    local kingdom = H.getKingdom(p)
    if kingdom ~= "unknown" then
      kingdomMapper[kingdom] = (kingdomMapper[kingdom] or 0) + 1
    end
  end
  return kingdomMapper
end

--- 获取势力角色数列表，注意键unknown的值为nil
---@param room AbstractRoom @ 房间
---@param player? Player @ 角色，与此角色相同的势力，填写则覆盖``kingdom``
---@param kingdom? string @ 势力，与``player``参数至少要填写一个
---@param include_dead? boolean @ 包括死人
---@return integer
function H.getSameKingdomPlayersNum(room, player, kingdom, include_dead)
  assert(player or kingdom, "must provide player or kingdom")
  if player then kingdom = H.getKingdom(player) end
  if kingdom == "unknown" then return 0 end
  local ret = 0
  for _, p in ipairs(include_dead and room.players or room.alive_players) do
    if H.getKingdom(p) == kingdom then
      ret = ret + 1
    end
  end
  return ret
end

--- 判断角色是否为大势力角色
---@param player Player
---@return boolean
H.isBigKingdomPlayer = function(player)
  if player.kingdom == "unknown" then return false end
  local room = Fk:currentRoom()

  local status_skills = room.status_skills[H.BigKingdomSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    for _, p in ipairs(room.alive_players) do
      if skill:getFixed(p) then
        return H.compareKingdomWith(p, player)
      end
    end
  end

  local mapper = H.getKingdomPlayersNum(room)
  local num = mapper[H.getKingdom(player)]
  if num < 2 then return false end
  for k, n in pairs(mapper) do
    if n > num then return false end
  end
  return true
end

--- 判断角色是否为小势力角色
---@param player ServerPlayer
---@return boolean?
H.isSmallKingdomPlayer = function(player)
  if H.isBigKingdomPlayer(player) then return false end
  return table.find(Fk:currentRoom().alive_players, function(p) return H.isBigKingdomPlayer(p) end)
end

-- 阵型

--- 获取与角色成队列的其余角色
---@param player Player
---@return ServerPlayer[]? @ 队列中的角色
H.getFormationRelation = function(player)
  if player:isRemoved() then return {} end
  local players = {}
  local p = player
  while true do
    p = p:getNextAlive(false)
    if p == player then break end
    if H.compareKingdomWith(p, player) then
      table.insert(players, p)
    else
      break
    end
  end
  p = player
  while true do
    p = p:getLastAlive(false)
    if p == player then break end
    if H.compareKingdomWith(p, player) then
      table.insertIfNeed(players, p)
    else
      break
    end
  end
  return players
end

--- 确认与某角色是否处于队列中
---@param player Player @ 角色1
---@param target Player @ 角色2，若为 player 即 player 是否处于某一队列
---@return boolean?
H.inFormationRelation = function(player, target)
  if target == player then
    return #H.getFormationRelation(player) > 0
  else
    return table.contains(H.getFormationRelation(player), target)
  end
end

--- 确认与某角色是否处于围攻关系
---@param player ServerPlayer @ 围攻角色1
---@param target ServerPlayer @ 围攻角色2，可填 player
---@param victim ServerPlayer @ 被围攻角色
---@return boolean?
H.inSiegeRelation = function(player, target, victim)
  if H.compareKingdomWith(player, victim) or not H.compareKingdomWith(player, target) or victim.kingdom == "unknown" then return false end
  if player == target then
    return (player:getNextAlive() == victim and player:getNextAlive(false, 2) ~= player and H.compareKingdomWith(player:getNextAlive(false, 2), player))
    or (victim:getNextAlive() == player and player:getLastAlive(false, 2) ~= player and H.compareKingdomWith(player:getLastAlive(false, 2), player))
  else
    return (player:getNextAlive() == victim and victim:getNextAlive() == target) -- P V T
    or (victim:getNextAlive() == player and target:getNextAlive() == victim) -- T V P
  end
end

--- 阵法召唤技
---@class ArraySummonSkill : ActiveSkill
H.ArraySummonSkill = ActiveSkill:subclass("ArraySummonSkill")

local function readActiveSpecToSkill(skill, spec)
  fk.readUsableSpecToSkill(skill, spec)

  if spec.can_use then
    skill.canUse = function(curSkill, player, card)
      return spec.can_use(curSkill, player, card) and curSkill:isEffectable(player)
    end
  end
  if spec.card_filter then skill.cardFilter = spec.card_filter end
  if spec.target_filter then skill.targetFilter = spec.target_filter end
  if spec.mod_target_filter then skill.modTargetFilter = spec.mod_target_filter end
  if spec.feasible then
    -- print(spec.name .. ": feasible is deprecated. Use target_num and card_num instead.")
    skill.feasible = spec.feasible
  end
  if spec.on_use then skill.onUse = spec.on_use end
  if spec.about_to_effect then skill.aboutToEffect = spec.about_to_effect end
  if spec.on_effect then skill.onEffect = spec.on_effect end
  if spec.on_nullified then skill.onNullified = spec.on_nullified end
  if spec.prompt then skill.prompt = spec.prompt end

  if spec.interaction then
    skill.interaction = setmetatable({}, {
      __call = function(self)
        if type(spec.interaction) == "function" then
          return spec.interaction(self)
        else
          return spec.interaction
        end
      end,
    })
  end
end

---@class ArraySummonSpec: ActiveSkillSpec
---@field public array_type string

--- 阵法召唤技
---@param spec ArraySummonSpec
---@return ArraySummonSkill
H.CreateArraySummonSkill = function(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.array_type) == "string")

  local skill = H.ArraySummonSkill:new(spec.name)
  readActiveSpecToSkill(skill, spec)

  skill.arrayType = spec.array_type -- 围攻 siege，队列 formation

  skill.canUse = function(curSkill, player, card)
    local room = Fk:currentRoom()
    local ret = curSkill:isEffectable(player) and player:usedSkillTimes(curSkill.name, Player.HistoryPhase) == 0 and player.kingdom ~= "wild"
      and H.inGeneralSkills(player, curSkill.name) and table.find(room.alive_players, function(p) return p.kingdom == "unknown" end)
      and H.getKingdomPlayersNum(room, true)[H.getKingdom(player)] < #room.players // 2
    if not ret then return false end
    local pattern = curSkill.arrayType
    if pattern == "formation" then -- 队列
      local p = player
      while true do
        p = p:getNextAlive() -- 下家
        if p == player then break end
        if not H.compareKingdomWith(p, player) then
          if p.kingdom == "unknown" then return true
          else break end
        end
      end
      while true do
        p = p:getLastAlive() -- 上家
        if p == player then break end
        if not H.compareKingdomWith(p, player) then
          if p.kingdom == "unknown" then return true
          else break end
        end
      end
    elseif pattern == "siege" then -- 围攻
      if H.compareKingdomWith(player:getNextAlive(), player, true) and player:getNextAlive(false, 2).kingdom == "unknown" then return true end
      if H.compareKingdomWith(player:getLastAlive(), player, true) and player:getLastAlive(false, 2).kingdom == "unknown" then return true end
    end
    return false
  end

  skill.onUse = function(curSkill, room, effect)
    local player = room:getPlayerById(effect.from)
    local pattern = curSkill.arrayType
    local kingdom = H.getKingdom(player)
    local function ArraySummonAskForReveal(_kingdom, to, skill_name)
      local main, deputy = false, false
      if H.compareExpectedKingdomWith(to, player) then
        local general = Fk.generals[to:getMark("__heg_general")]
        main = general.kingdom == _kingdom or general.subkingdom == _kingdom
        general = Fk.generals[to:getMark("__heg_deputy")]
        deputy = general.kingdom == _kingdom or general.subkingdom == _kingdom
      end
      return H.askForRevealGenerals(room, to, skill_name, main, deputy)
    end
    if pattern == "formation" then
      for i = 1, 2 do
        local p = player
        while true do
          if H.getKingdomPlayersNum(room, true)[kingdom] >= #room.players // 2 then break end
          p = i == 1 and p:getNextAlive() or p:getLastAlive()
          if p == player then break end
          if not H.compareKingdomWith(p, player) then
            if p.kingdom == "unknown" then
              if not ArraySummonAskForReveal(kingdom, p, curSkill.name) then break end
            else break end
          end
        end
      end
    elseif pattern == "siege" then -- 围攻
      local p
      if H.compareKingdomWith(player:getNextAlive(), player, true) then
        p = player:getNextAlive(false, 2)
      elseif H.compareKingdomWith(player:getLastAlive(), player, true) and H.getKingdomPlayersNum(room, true)[kingdom] < #room.players // 2 then
        p = player:getLastAlive(false, 2)
      end
      if p.kingdom == "unknown" then
        ArraySummonAskForReveal(kingdom, p, curSkill.name)
      end
    end
  end

  return skill
end

-- 军令

--- 对某角色发起军令（抽取、选择、询问）
---@param from ServerPlayer @ 军令发起者
---@param to ServerPlayer @ 军令执行者
---@param skill_name string @ 技能名
---@param forced? boolean @ 是否强制执行
---@return boolean @ 是否执行
H.askCommandTo = function(from, to, skill_name, forced)
  if from.dead or to.dead then return false end
  local room = from.room
  room:sendLog{
    type = "#AskCommandTo",
    from = from.id,
    to = {to.id},
    arg = skill_name,
    toast = true,
  }
  --[[ -- 酷炫顶栏
  local ret = "<b><font color='#0C8F0C'>" .. Fk:translate(from.general)
  if from.deputyGeneral and from.deputyGeneral ~= "" then
    ret = ret .. "/" .. Fk:translate(from.deputyGeneral)
  end
  ret = ret .. "</b></font> " .. Fk:translate("to") .. " <b><font color='#CC3131'>" .. Fk:translate(to.general)
  if to.deputyGeneral and to.deputyGeneral ~= "" then
    ret = ret .. "/" .. Fk:translate(to.deputyGeneral)
  end
  ret = ret .. "</b></font> " .. " <b>" .. Fk:translate("start_command") .. "</b>"
  room:doBroadcastNotify("ServerMessage", ret)
  --]]
  local index = H.startCommand(from, skill_name)
  local invoke = H.doCommand(to, skill_name, index, from, forced)
  return invoke
end

--- 军令发起者抽取并选择军令
---@param from ServerPlayer @ 军令发起者
---@param skill_name? string @ 技能名
---@param num? integer @ 抽取数量
---@return integer @ 选择的军令序号
H.startCommand = function(from, skill_name, num)
  local allcommands = {"command1", "command2", "command3", "command4", "command5", "command6"}
  num = num or 2
  local commands = table.random(allcommands, num) ---@type string[]

  local room = from.room
  local choice = room:askForChoice(from, commands, "start_command", nil, true)

  room:sendLog{
    type = "#CommandChoice",
    from = from.id,
    arg = ":"+choice,
    toast = true,
  }
  --[[ -- 酷炫顶栏
  local ret = "<b><font color='#0C8F0C'>" .. Fk:translate(from.general)
  if from.deputyGeneral and from.deputyGeneral ~= "" then
    ret = ret .. "/" .. Fk:translate(from.deputyGeneral)
  end
  ret = ret .. "</b></font> " .. Fk:translate("chose") .. " <b>" .. Fk:translate(":"+choice) .. "</b>"
  room:doBroadcastNotify("ServerMessage", ret)
  --]]

  return table.indexOf(allcommands, choice)
end

--- 询问军令执行者是否执行军令（执行效果也在这里）
---@param to ServerPlayer @ 军令执行者
---@param skill_name string @ 技能名
---@param index integer @ 军令序数
---@param from ServerPlayer @ 军令发起者
---@param forced? boolean @ 是否强制执行
---@return boolean @ 是否执行
H.doCommand = function(to, skill_name, index, from, forced)
  if to.dead or from.dead then return false end
  local room = to.room

  local allcommands = {"command1", "command2", "command3", "command4", "command5", "command6"}

  local choice
  if not forced then
    choice = room:askForChoice(to, {allcommands[index], "Cancel"}, "do_command", nil, true)
  else
    choice = room:askForChoice(to, {allcommands[index]}, "do_command", nil, true, {allcommands[index], "Cancel"})
  end

  local result = choice == "Cancel" and "#commandselect_no" or "#commandselect_yes"
  room:sendLog{
    type = "#CommandChoice",
    from = to.id,
    arg = result,
    toast = true,
  }
  --[[ -- 酷炫顶栏
  local ret = "<b><font color='#CC3131'>" .. Fk:translate(to.general)
  if to.deputyGeneral and to.deputyGeneral ~= "" then
    ret = ret .. "/" .. Fk:translate(to.deputyGeneral)
  end
  ret = ret .. "</b></font> " .. Fk:translate("chose") .. " <b>" .. Fk:translate(result) .. "</b>"
  room:doBroadcastNotify("ServerMessage", ret)
  --]]
  local commandData = {
    from = from,
    to = to,
    command = index,
  }
  if choice == "Cancel" then 
    room.logic:trigger("fk.AfterCommandUse", to, commandData)
    return false 
  end
  if room.logic:trigger("fk.ChooseDoCommand", to, commandData) then
    room.logic:trigger("fk.AfterCommandUse", to, commandData)
    return true
  end
  if index == 1 then
    local dest = room:askForChoosePlayers(from, table.map(room.alive_players, Util.IdMapper), 1, 1, "#command1-damage::" .. to.id, skill_name)[1]
    room:sendLog{
      type = "#Command1Damage",
      from = from.id,
      to = {dest},
    }
    room:doIndicate(from.id, {dest})
    room:damage{
      from = to,
      to = room:getPlayerById(dest),
      damage = 1,
      skillName = "command",
    }
  elseif index == 2 then
    to:drawCards(1, "command")
    if to == from or to:isNude() then return true end
    local cards = {}
    if #to:getCardIds{Player.Hand, Player.Equip} == 1 then
      cards = to:getCardIds{Player.Hand, Player.Equip}
    else
      cards = room:askForCard(to, 2, 2, true, "command", false, nil, "#command2-give::" .. from.id)
    end
    room:moveCardTo(cards, Player.Hand, from, fk.ReasonGive, "command", nil, false, from.id)
  elseif index == 3 then
    room:loseHp(to, 1, "command")
  elseif index == 4 then
    room:setPlayerMark(to, "@@command4_effect-turn", 1)
    room:addPlayerMark(to, MarkEnum.UncompulsoryInvalidity .. "-turn")
    room:handleAddLoseSkills(to, "#command4_prohibit", nil, false, true) --为了不全局，流汗了
  elseif index == 5 then
    to:turnOver()
    room:setPlayerMark(to, "@@command5_effect-turn", 1)
    room:handleAddLoseSkills(to, "#command5_cannotrecover", nil, false, true) --为了不全局，流汗了
  elseif index == 6 then
    if to:getHandcardNum() < 2 and #to:getCardIds(Player.Equip) < 2 then return true end
    local to_remain = {}
    if not to:isKongcheng() then
      table.insert(to_remain, to:getCardIds(Player.Hand)[1])
    end
    if #to:getCardIds(Player.Equip) > 0 then
      table.insert(to_remain, to:getCardIds(Player.Equip)[1])
    end
    local _, ret = room:askForUseActiveSkill(to, "#command6_select", "#command6-select", false)
    if ret then
      to_remain = ret.cards
    end
    local cards = table.filter(to:getCardIds{Player.Hand, Player.Equip}, function (id)
      return not (table.contains(to_remain, id) or to:prohibitDiscard(Fk:getCardById(id)))
    end)
    if #cards > 0 then
      room:throwCard(cards, "command", to)
    end
  end
  room.logic:trigger("fk.AfterCommandUse", to, commandData)
  return true
end

Fk:loadTranslationTable{
  ["command"] = "军令",

  ["#StartCommand"] = "%arg：请选择一项军令<br>%arg2；<br>%arg3",
  ["command1"] = "军令一",
  ["command2"] = "军令二",
  ["command3"] = "军令三",
  ["command4"] = "军令四",
  ["command5"] = "军令五",
  ["command6"] = "军令六",

  [":command1"] = "军令一：对发起者指定的角色造成1点伤害",
  [":command2"] = "军令二：摸一张牌，然后交给发起者两张牌",
  [":command3"] = "军令三：失去1点体力",
  [":command4"] = "军令四：本回合不能使用或打出手牌且所有非锁定技失效",
  [":command5"] = "军令五：叠置，本回合不能回复体力",
  [":command6"] = "军令六：选择一张手牌和一张装备区里的牌，弃置其余的牌",

  ["start_command"] = "发起军令",
  ["#AskCommandTo"] = "%from 发动了 “%arg”，对 %to 发起了 <font color='#0598BC'><b>军令",
  ["#CommandChoice"] = "%from 选择了 %arg",
  ["chose"] = "选择了",

  ["do_command"] = "执行军令",
  ["#commandselect_yes"] = "执行军令",
  ["#commandselect_no"] = "不执行军令",

  ["#command1-damage"] = "军令：请选择 %dest 伤害的目标",
  ["#Command1Damage"] = "%from 选择对 %to 造成伤害",
  ["#command2-give"] = "军令：请选择两张牌交给 %dest",
  ["@@command4_effect-turn"] = "军令禁出牌技能",
  ["@@command5_effect-turn"] = "军令 不能回血",
  ["#command6-select"] = "军令：请选择要保留的一张手牌和一张装备",
}

-- 武将牌相关

--- 判断有无主将/副将
---@param player Player
---@param isDeputy boolean?
---@return boolean?
H.hasGeneral = function(player, isDeputy)
  local orig = isDeputy and (player.deputyGeneral or "") or player.general
  return orig ~= "" and not orig:startsWith("blank_")
end

--- 获得真正的主将/副将（而非暗将）
---@param player Player
---@param isDeputy boolean?
---@return string
H.getActualGeneral = function(player, isDeputy)
  if isDeputy then
    return player.deputyGeneral == "anjiang" and player:getMark("__heg_deputy") or player.deputyGeneral or ""
  else
    return player.general == "anjiang" and player:getMark("__heg_general") or player.general
  end
end

--- 获取明置的武将牌数
---@param player Player
---@return integer
H.getGeneralsRevealedNum = function(player)
  local num = 0
  if player.general ~= "anjiang" then num = num + 1 end
  if player.deputyGeneral and player.deputyGeneral ~= "anjiang" then num = num + 1 end
  return num
end

-- 君主将。为了方便……
H.lordGenerals = {}

--- 获取所属势力的君主，可能为nil
---@param room AbstractRoom
---@param player Player
---@return ServerPlayer? @ 君主
H.getHegLord = function(room, player)
  local kingdom = player.kingdom
  return table.find(room.alive_players, function(p) return p.kingdom == kingdom and string.find(p.general, "lord") end)
end

--- 询问亮将
---@param room Room
---@param player ServerPlayer
---@param skill_name string
---@param main? boolean
---@param deputy? boolean
---@param all? boolean
---@param cancelable? boolean
---@param lord_convert? boolean
---@return boolean
H.askForRevealGenerals = function(room, player, skill_name, main, deputy, all, cancelable, lord_convert)
  if H.getGeneralsRevealedNum(player) == 2 then return false end
  main = (main == nil) and true or main
  deputy = (deputy == nil) and true or deputy
  all = (all == nil) and true or all
  cancelable = (cancelable == nil) and true or cancelable
  local all_choices = {"revealMain:::" .. player:getMark("__heg_general"), "revealDeputy:::" .. player:getMark("__heg_deputy"), "revealAll", "Cancel"}
  local choices = {}

  if main and player.general == "anjiang" and not player:prohibitReveal() then
    table.insert(choices, "revealMain:::" .. player:getMark("__heg_general"))
  end
  if deputy and player.deputyGeneral == "anjiang" and not player:prohibitReveal(true) then
    table.insert(choices, "revealDeputy:::" .. player:getMark("__heg_deputy"))
  end
  if #choices == 2 and all then table.insert(choices, "revealAll") end
  if cancelable then table.insert(choices, "Cancel") end
  if #choices == 0 then return false end

  -- 能否变身君主
  local convert = false
  if lord_convert and room:getBanner("RoundCount") == 1 and player:getMark("hasShownMainGeneral") == 0 then
    local lord = H.lordGenerals[player:getMark("__heg_general")]
    if lord then
      if not table.contains(room.disabled_packs, Fk.generals[lord].package.name) and not table.contains(room.disabled_generals, lord) then
        convert = true
      end
    end
  end

  local choice = room:askToChoice(player, {choices = choices, skill_name = skill_name, prompt = convert and "#HegPrepareConvertLord" or nil, all_choices = all_choices, cancelable = false})
  -- 先变身君主
  if convert and (choice:startsWith("revealMain") or choice == "revealAll") and room:askForChoice(player, {"ConvertToLord:::" .. H.lordGenerals[player:getMark("__heg_general")], "Cancel"}, skill_name, nil) ~= "Cancel" then
    for _, s in ipairs(Fk.generals[player:getMark("__heg_general")]:getSkillNameList()) do
      local skill = Fk.skills[s]
      player:loseFakeSkill(skill)
    end
    room:setPlayerMark(player, "__heg_general", H.lordGenerals[player:getMark("__heg_general")])
    local general = Fk.generals[player:getMark("__heg_general")]
    local deputy = Fk.generals[player:getMark("__heg_deputy")]
    local dmaxHp = deputy.maxHp + deputy.deputyMaxHpAdjustedValue
    local gmaxHp = general.maxHp + general.mainMaxHpAdjustedValue
    local maxHp = (dmaxHp + gmaxHp) // 2
    local num = maxHp - player.maxHp
    if num > 0 then
      player.maxHp = maxHp
      player.hp = player.hp + num
      room:broadcastProperty(player, "maxHp")
      room:broadcastProperty(player, "hp")
    end
    if (dmaxHp + gmaxHp) % 2 == 1 then -- 重新计算阴阳鱼
      player:setMark("HalfMaxHpLeft", 1)
      player:doNotify("SetPlayerMark", json.encode{ player.id, "HalfMaxHpLeft", 1})
    else
      player:setMark("HalfMaxHpLeft", 0)
      player:doNotify("SetPlayerMark", json.encode{ player.id, "HalfMaxHpLeft", 0})
    end
    player:setMark("CompanionEffect", 1)
    player:doNotify("SetPlayerMark", json.encode{ player.id, "CompanionEffect", 1})
  end

  if choice:startsWith("revealMain") then player:revealGeneral(false)
  elseif choice:startsWith("revealDeputy") then player:revealGeneral(true)
  elseif choice == "revealAll" then
    player:revealGenerals()
  elseif choice == "Cancel" then
    return false
  end
  return true
end

Fk:loadTranslationTable{
  ["#HegPrepareConvertLord"] = "国战规则：请选择要明置的武将（仅本次明置主将可变身君主）",
  ["ConvertToLord"] = "<b>变身为<font color='goldenrod'>%arg</font></b>！",
}

--- A暗置B的武将牌
---@param room Room
---@param player ServerPlayer
---@param target ServerPlayer
---@param skill_name string
---@return boolean @ 是否为副将
function H.doHideGeneral(room, player, target, skill_name)
  if player.dead or target.dead then return false end
  local all_choices = {target.general, target.deputyGeneral}
  local disable_choices = {}
  if not (target.general ~= "anjiang" and not target.general:startsWith("blank_") and not string.find(target.general, "lord")) then -- 耦合君主
    table.insert(disable_choices, target.general)
  end
  if not (target.deputyGeneral ~= "anjiang" and not target.deputyGeneral:startsWith("blank_")) then
    table.insert(disable_choices, target.deputyGeneral)
  end
  if #disable_choices == 2 then return false end
  local result = room:askForCustomDialog(player, skill_name,
  "packages/utility/qml/ChooseGeneralsAndChoiceBox.qml", {
    all_choices,
    {"OK"},
    "#hide_general-ask::" .. target.id .. ":" .. skill_name,
    {},
    1,
    1,
    disable_choices
  })
  local choice
  if result ~= "" then
    local reply = json.decode(result)
    choice = reply.cards[1]
  else
    choice = table.find(all_choices, function(g)
      return not table.contains(disable_choices, g)
    end)
  end
  local isDeputy = choice == target.deputyGeneral
  if isDeputy then room:setPlayerMark(target, "__heg_deputy", target.deputyGeneral)
  else room:setPlayerMark(target, "__heg_general", target.general) end
  target:hideGeneral(isDeputy)
  room:sendLog{
    type = "#HideOtherGeneral",
    from = player.id,
    to = {target.id},
    arg = isDeputy and "deputyGeneral" or "mainGeneral",
    arg2 = isDeputy and target:getMark("__heg_deputy") or target:getMark("__heg_general"),
  }
  return isDeputy
end
Fk:loadTranslationTable{
  ["#hide_general-ask"] = "%arg：暗置 %dest 一张武将牌",
  ["#HideOtherGeneral"] = "%from 暗置了 %to 的 %arg %arg2",
}

-- 根据技能暗置武将牌
---@param player ServerPlayer
---@param skill string | Skill
---@param allowBothHidden? boolean?
---@return string? @ 暗置的是主将还是副将，或没有暗置
H.hideBySkillName = function(player, skill, allowBothHidden)
  local isDeputy = H.inGeneralSkills(player, skill)
  if isDeputy and (allowBothHidden or H.getGeneralsRevealedNum(player) == 2) then
    player:hideGeneral(isDeputy == "d")
    return isDeputy
  end
end

-- 移除武将牌
---@param room Room
---@param player ServerPlayer
---@param isDeputy? boolean @ 是否为副将，默认主将
H.removeGeneral = function(room, player, isDeputy)
  player:setMark("CompanionEffect", 0)
  player:setMark("HalfMaxHpLeft", 0)
  player:doNotify("SetPlayerMark", json.encode{ player.id, "CompanionEffect", 0})
  player:doNotify("SetPlayerMark", json.encode{ player.id, "HalfMaxHpLeft", 0})

  --if player.kingdom == "unknown" then player:revealGeneral(isDeputy, true) end 
  player:revealGeneral(isDeputy, true) -- 先摆

  if room.logic:trigger("fk.GeneralRemoving", player, isDeputy) then return false end

  local orig = isDeputy and (player.deputyGeneral or "") or player.general

  if orig:startsWith("blank_") then return false end

  orig = Fk.generals[orig]

  local orig_skills = orig and orig:getSkillNameList() or {}

  local new_general = orig.gender == General.Male and "blank_shibing" or "blank_nvshibing"

  orig_skills = table.map(orig_skills, function(e)
    return "-" .. e
  end)

  room:handleAddLoseSkills(player, table.concat(orig_skills, "|"), nil, false)

  if isDeputy then
    room:setPlayerProperty(player, "deputyGeneral", new_general)
    room:setPlayerMark(player, "__heg_deputy", new_general)
  else
    room:setPlayerProperty(player, "general", new_general)
    room:setPlayerMark(player, "__heg_general", new_general)
  end

  player:filterHandcards()
  room:sendLog{
    type = "#GeneralRemoved",
    from = player.id,
    arg = isDeputy and "deputyGeneral" or "mainGeneral",
    arg2 = orig.name,
  }
  room:returnToGeneralPile({orig.name})
  room.logic:trigger("fk.GeneralRemoved", player, orig.name)
end
Fk:loadTranslationTable{
  ["#GeneralRemoved"] = "%from 移除了 %arg %arg2",
}

local function addHegSkill(player, skill, room)
  if skill.frequency == Skill.Compulsory then
    player:addFakeSkill("reveal_skill&")
  end
  player:addFakeSkill(skill)
  local toget = {table.unpack(skill.related_skills)}
  table.insert(toget, skill)
  for _, s in ipairs(toget) do
    if s:isInstanceOf(TriggerSkill) then
      room.logic:addTriggerSkill(s)
    end
  end
end

--- 变更武将牌
---@param room Room
---@param player ServerPlayer
---@param isMain boolean? @ 是否为主将，默认副将
---@param isHidden boolean? @ 是否暗置变更
---@param num? integer @ 选将数量，默认为3
H.transformGeneral = function(room, player, isMain, isHidden, num)
  local data = {
    isMain = isMain,
    isHidden = isHidden,
    num = num,
  }
  if room.logic:trigger("fk.GeneralTransforming", player, data) then return false end
  isMain = data.isMain
  isHidden = data.isHidden
  num = data.num
  local orig = isMain and player.general or player.deputyGeneral
  num = num or 3
  if not orig then return false end
  if orig == "anjiang" then
    player:revealGeneral(not isMain, true)
    orig = isMain and player.general or player.deputyGeneral
  end
  local existingGenerals = {}
  for _, p in ipairs(room.players) do
    table.insert(existingGenerals, H.getActualGeneral(p, false))
    table.insert(existingGenerals, H.getActualGeneral(p, true))
  end
  local kingdom = player:getMark("__heg_kingdom")
  if kingdom == "wild" then
    kingdom = player:getMark("__heg_init_kingdom")
  end
  local generals = room:findGenerals(function(g)
    return Fk.generals[g].kingdom == kingdom or Fk.generals[g].subkingdom== kingdom
  end, num)
  local general = room:askForGeneral(player, generals, 1, true) ---@type string
  table.removeOne(generals, general)
  table.insert(generals, orig)
  room:returnToGeneralPile(generals)
  if not isHidden then
    room:changeHero(player, general, false, not isMain, true, false, false)
  else
    if isMain then
      room:setPlayerGeneral(player, "anjiang", true)
      local general = Fk.generals[player:getMark("__heg_general")]
      local skills = table.connect(general.skills, table.map(general.other_skills, Util.Name2SkillMapper))
      for _, s in ipairs(skills) do
        if s.relate_to_place ~= "d" then
          addHegSkill(player, s, room)
        end
      end
    else
      room:setDeputyGeneral(player, "anjiang")
      local deputy = Fk.generals[player:getMark("__heg_deputy")]
      if deputy then
        local skills = table.connect(deputy.skills, table.map(deputy.other_skills, Util.Name2SkillMapper))
        for _, s in ipairs(skills) do
          if s.relate_to_place ~= "m" then
            addHegSkill(player, s, room)
          end
        end
      end
    end
  end
  room:setPlayerMark(player, isMain and "__heg_general" or "__heg_deputy", general)
  if not isHidden then
    room:changeHero(player, general, false, not isMain, true, false, false)
  else
    -- 暗置变更
    local lose = Fk.generals[orig]
    local general = isMain and Fk.generals[player:getMark("__heg_general")] or Fk.generals[player:getMark("__heg_deputy")]
    room:setPlayerGeneral(player, "anjiang", isMain)
    local skills = table.connect(general.skills, table.map(general.other_skills, Util.Name2SkillMapper))
    local location = isMain and "d" or "m"
    for _, s in ipairs(skills) do
      if s.relate_to_place ~= location then
        addHegSkill(player, s, room)
      end
    end
    for _, s in ipairs(lose:getSkillNameList()) do
      room:handleAddLoseSkills(player, "-"..s, nil)
    end
  end
  room.logic:trigger("fk.GeneralTransformed", player, orig)
end

-- 技能相关

--- 技能是否亮出
--- deprecated，已写入本体
---@param player Player
---@param skill string | Skill
---@return boolean?
H.hasShownSkill = function(player, skill, ignoreNullified, ignoreAlive)
  return player:hasShownSkill(skill, ignoreNullified, ignoreAlive)
end

--- 技能是否为主将/副将武将牌上的技能，返回“m”“d”或nil
---@param player ServerPlayer
---@param skill string | Skill @ 技能，建议技能名
---@return string?
H.inGeneralSkills = function(player, skill)
  assert(type(skill) == "string" or skill:isInstanceOf(Skill))
  if type(skill) ~= "string" then skill = skill.name end
  if table.contains(Fk.generals[player.general]:getSkillNameList(), skill) then
    return "m"
  elseif player.deputyGeneral and table.contains(Fk.generals[player.deputyGeneral]:getSkillNameList(), skill) then
    return "d"
  end
  return nil
end

-- 国战标记

--- 国战标记类型
---@alias HegMarkType "vanguard" | "yinyangfish" | "companion" | "wild"

--- 添加国战标记
---@param room Room @ 房间
---@param player ServerPlayer @ 角色
---@param markName string|HegMarkType @ 标记种类
---@param number? integer @ 数量，默认为1
H.addHegMark = function(room, player, markName, number)
  if not number then number = 1 end
  if markName == "vanguard" then
    room:addPlayerMark(player, "@!vanguard", number)
    player:addFakeSkill("vanguard_skill&")
  elseif markName == "yinyangfish" then
    room:addPlayerMark(player, "@!yinyangfish", number)
    player:addFakeSkill("yinyangfish_skill&")
    player:prelightSkill("yinyangfish_skill&", true)
  elseif markName == "companion" then
    room:addPlayerMark(player, "@!companion", number)
    player:addFakeSkill("companion_skill&")
    player:addFakeSkill("companion_peach&")
  elseif markName == "wild" then
    room:addPlayerMark(player, "@!wild", number)
    player:addFakeSkill("wild_draw&")
    player:addFakeSkill("wild_peach&")
    player:prelightSkill("wild_draw&", true)
  end
end

-- 合纵

H.allianceCards = {}

--- 向合纵库中加载一张卡牌。
---@param card table @ 要加载的卡牌
H.addCardToAllianceCards = function(card)
  table.insertIfNeed(H.allianceCards, card)
end

--- 向扩展包添加一张可合纵的牌。
---@param extension Package
---@param name string
---@param suit integer
---@param number integer
H.addAllianceCardSpec = function (extension, name, suit, number)
  extension:addCardSpec(name, suit, number)
  H.addCardToAllianceCards{name, suit, number}
end

--- 可合纵
---@param from Player
---@param to Player
---@return boolean
H.canAlliance = function(from, to)
  if to == from then return false end
  if H.compareKingdomWith(from, to, true) or to.kingdom == "unknown" then return true end
  local status_skills = Fk:currentRoom().status_skills[H.AllianceSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    if skill:allowAlliance(from, to) then
      return true
    end
  end
  return false
end

--- 允许合纵技
---@class AllianceSkill : StatusSkill
H.AllianceSkill = StatusSkill:subclass("AllianceSkill")

---@param from Player
---@param to Player
---@return boolean
function H.AllianceSkill:allowAlliance(from, to)
  return false
end

---@class AllianceSpec: StatusSkillSpec
---@field public allow_alliance? fun(self: AllianceSkill, from: Player, to:Player): boolean?

---@param spec AllianceSpec
---@return AllianceSkill
H.CreateAllianceSkill = function(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.allow_alliance) == "function")

  local skill = H.AllianceSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)
  skill.allowAlliance = spec.allow_alliance or skill.allowAlliance
  return skill
end

-- 卡牌替换

H.convertCards = {}

---@param card Card @ 要替换的卡牌
---@param convert string @ 要被替换的卡牌名
H.addCardToConvertCards = function(card, convert)
  assert(card.class:isSubclassOf(Card))
  H.convertCards[convert] = H.convertCards[convert] or {}
  table.insert(H.convertCards[convert], card)
end

-- 大势力

--- 视为大势力技
---@class BigKingdomSkill : StatusSkill
H.BigKingdomSkill = StatusSkill:subclass("BigKingdomSkill")

---@param player Player
---@return boolean?
function H.BigKingdomSkill:getFixed(player)
  return false
end

---@class BigKingdomSpec: StatusSkillSpec
---@field public fixed_func? fun(self: BigKingdomSkill, player: Player): boolean?

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: 'bigkingdom', data: BigKingdomSpec, attribute: nil)

---@param spec BigKingdomSpec
---@return BigKingdomSkill
H.CreateBigKingdomSkill = function(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.fixed_func) == "function")

  local skill = H.BigKingdomSkill:new(spec.name)
  fk.readStatusSpecToSkill(skill, spec)

  if spec.fixed_func then
    skill.getFixed = spec.fixed_func
  end

  return skill
end

return H
