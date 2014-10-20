UnitsInMeleeRange, UnitsInAoERange = 0

UnitsAroundMe = function ()
  UnitsInMeleeRange = 0
  UnitsInAoERange = 0
  if FireHack then
    local totalObjects = ObjectCount()
    for i = 1, totalObjects do
      local object = ObjectWithIndex(i)
      if bit.band(ObjectType(object), ObjectTypes.Unit) > 0 then
      	if UnitReaction("player", object) <= 4 and UnitAffectingCombat(object) then
      	  local ax, ay, az = ObjectPosition("player")
          local bx, by, bz = ObjectPosition(object)
          local dist = abs(math.sqrt(((bx-ax)^2) + ((by-ay)^2) + ((bz-az)^2)) - (UnitCombatReach("player") + UnitCombatReach(object)))
          if dist <= 1.2 then
            UnitsInMeleeRange = UnitsInMeleeRange + 1
          end
          if dist <= 10 then
            UnitsInAoERange = UnitsInAoERange + 1
          end
      	end
      end
    end
  end
  return false
end

RuptureCycle = function ()
  local spellName, spellRank = GetSpellName("1943", BOOKTYPE_SPELL)
  CastSpellByName(spellName)
  
  if FireHack then
    local totalObjects = ObjectCount()
    for i = 1, totalObjects do
      local object = ObjectWithIndex(i)
      if bit.band(ObjectType(object), ObjectTypes.Unit) > 0 then
      	if UnitReaction("player", object) <= 4 and UnitAffectingCombat(object) then
      	  local ax, ay, az = ObjectPosition("player")
          local bx, by, bz = ObjectPosition(object)
          if abs(math.sqrt(((bx-ax)^2) + ((by-ay)^2) + ((bz-az)^2)) - (UnitCombatReach("player") + UnitCombatReach(object))) <= 1.2 then
          	total = total + 1
          end
      	end
      end
    end
  end
end

RuptureCycleCheck = function ()
  -- actions.finisher+=/rupture,cycle_targets=1,if=(!ticking|remains<duration*0.3)&active_enemies<=3&(cooldown.death_from_above.remains>0|!talent.death_from_above.enabled)
  if UnitsInMeleeRange <= 3 then
    return true
  else
  	return false
  end
end

VanishCheck = function ()
  -- energy+cooldown.shadow_dance.remains*energy.regen<80|energy+cooldown.vanish.remains*energy.regen<60
  local energy = UnitPower("player", SPELL_POWER_ENERGY)
  local energyRegen = GetPowerRegen(player)
  local start, duration = GetSpellCooldown("1856")
  local vanishCD = (start + duration - GetTime())
  local start, duration = GetSpellCooldown("51713")
  local shadowDanceCD = (start + duration - GetTime())
  if (energy+shadowDanceCD*energyRegen) < 80 or (energy+vanishCD*energyRegen) < 60 then
    return true
  else
    return false
  end
end

local preparation = {
  -- preparation,if=!buff.vanish.up&cooldown.vanish.remains>60
  { "Подготовка", { "!player.buff(1856)", "player.spell(1856).cooldown > 60" }},
}

local generator = {
  -- actions.generator=run_action_list,name=pool,if=buff.master_of_subtlety.down&buff.shadow_dance.down&debuff.find_weakness.down&(energy+cooldown.shadow_dance.remains*energy.regen<80|energy+cooldown.vanish.remains*energy.regen<60)
  { preparation, { (function () return VanishCheck() end), "!player.buff(31223)", "!player.buff(51713)", "!target.debuff(91021)" }},
  -- actions.generator+=/fan_of_knives,if=active_enemies>6
  { "51723", (UnitsInAoERange >= 7) },
  -- actions.generator+=/hemorrhage,if=(remains<8&target.time_to_die>10)|position_front
  { "16511", "target.debuff(16511).duration < 8" },
  { "16511", "!player.behind"},
  -- actions.generator+=/shuriken_toss,if=energy<65&energy.regen<16
  { "114014", { "player.spell(114014).exists", "player.energy < 65", (function () return GetPowerRegen(player) < 16 end) }},
  -- actions.generator+=/backstab
  { "53" },
  -- actions.generator+=/run_action_list,name=pool
  { preparation },
}

local finisher = {
  -- actions.finisher=slice_and_dice,if=buff.slice_and_dice.remains<4
  { "5171", "player.buff(5171).duration < 4" },
  -- actions.finisher+=/death_from_above
  { "152150", "player.spell(152150).exists"},
  -- actions.finisher+=/rupture,cycle_targets=1,if=(!ticking|remains<duration*0.3)&active_enemies<=3&(cooldown.death_from_above.remains>0|!talent.death_from_above.enabled)
  { "/run RuptureCycle()", { "!target.debuff(1943)", (function () return RuptureCycleCheck() end), "player.spell(152150).cooldown > 0" }},
  { "/run RuptureCycle()", { "!target.debuff(1943)", (function () return RuptureCycleCheck() end), "!player.spell(152150).exists" }},
  { "/run RuptureCycle()", { "target.debuff(1943).duration <= 7.2", (function () return RuptureCycleCheck() end), "player.spell(152150).cooldown > 0" }},
  { "/run RuptureCycle()", { "target.debuff(1943).duration <= 7.2", (function () return RuptureCycleCheck() end), "!player.spell(152150).exists" }},
  -- actions.finisher+=/crimson_tempest,if=(active_enemies>3&dot.crimson_tempest_dot.ticks_remain<=2&combo_points=5)|active_enemies>=5&(cooldown.death_from_above.remains>0|!talent.death_from_above.enabled)
  { "121411", { (function () return UnitsInAoERange > 3 end), "target.debuff(121411).duration <= 5.9", "player.combopoints = 5"}},
  { "121411", { (function () return UnitsInAoERange >= 5 end), "player.spell(152150).cooldown > 0"}},
  { "121411", { (function () return UnitsInAoERange >= 5 end), "!player.spell(152150).exists"}},
  -- actions.finisher+=/eviscerate,if=active_enemies<4|(active_enemies>3&dot.crimson_tempest_dot.ticks_remain>=2)&(cooldown.death_from_above.remains>0|!talent.death_from_above.enabled)
  { "2098", { (function () return UnitsInAoERange < 4 end) }},
  { "2098", { (function () return UnitsInAoERange > 3 end), "target.debuff(121411).duration < 5.9", "player.spell(152150).cooldown > 0"}},
  { "2098", { (function () return UnitsInAoERange > 3 end), "target.debuff(121411).duration < 5.9", "!player.spell(152150).exists"}},
  -- actions.finisher+=/run_action_list,name=pool
  { preparation },
}
-- SPEC ID 261
ProbablyEngine.rotation.register_custom(261, "biGGerSub", {
  -- AoE Detection
  { "pause", (function () return UnitsAroundMe() end)},

  { "/targetenemy [noexists][dead]", { "toggle.autotarget", "!target.exists" }}, { "/targetenemy [dead]", { "toggle.autotarget", "target.exists", "target.dead" }},

  { "2823", { "!player.buff(2823)", "!player.moving" }},
  
  -- actions+=/premeditation,if=combo_points<=4
  { "Умысел", "player.combopoints <= 4", "target"},

  -- actions+=/ambush,if=combo_points<5|(talent.anticipation.enabled&anticipation_charges<3)
  { "8676", { "player.combopoints < 5", "player.buff(51713)" }},
  { "8676", { "player.buff(114015).count < 3", "player.buff(51713)" }},
  { "pause", { "player.combopoints <= 4", "player.buff(51713)"}},

  -- actions+=/shadow_dance,if=energy>=75&buff.stealth.down&buff.vanish.down&debuff.find_weakness.down
  { "pause" , {"player.spell(51713).cooldown <= 0", "player.energy <= 75", "!player.buff(1856)", "!target.debuff(91021)", "!player.buff(1784)"}},
  { "51713", { "!player.buff(51713)", "!target.debuff(91021)", "!player.buff(1784)"}},

  -- actions+=/vanish,if=energy>=45&energy<=75&combo_points<=3&buff.shadow_dance.down&buff.master_of_subtlety.down&debuff.find_weakness.down
  { "pause" , {"player.spell(1856).cooldown <= 0", "player.energy <= 45", "player.combopoints <= 3", "!player.buff(51713)", "!player.buff(31223)", "!target.debuff(91021)"}},
  { "1856", { "player.energy >= 45", "player.combopoints <= 3", "!player.buff(51713)", "!player.buff(31223)", "!target.debuff(91021)"}},
  
  -- actions+=/marked_for_death,if=combo_points=0
  {"Метка смерти", {"player.spell(Метка смерти).exists", "player.combopoints = 0"}},
  -- actions+=/shadow_reflection,if=buff.shadow_dance.up
  {"152151", {"player.spell(152151).exists", "player.buff(51713)"}},


  -- actions+=/run_action_list,name=generator,if=talent.anticipation.enabled&anticipation_charges<4&buff.slice_and_dice.up&dot.rupture.remains>2&(buff.slice_and_dice.remains<6|dot.rupture.remains<4)
  { generator, { "player.spell(114015).exists", "player.buff(114015).count < 4", "player.buff(5171)", "target.debuff(16511).duration > 2", "player.buff(5171).duration < 6"}},
  { generator, { "player.spell(114015).exists", "player.buff(114015).count < 4", "player.buff(5171)", "target.debuff(16511).duration > 2", "target.debuff(16511).duration < 4"}},
  -- actions+=/run_action_list,name=finisher,if=combo_points=5
  { finisher, "player.combopoints = 5"},
  -- actions+=/run_action_list,name=generator,if=combo_points<4|energy>80|talent.anticipation.enabled
  { generator, "player.combopoints < 4" },
  { generator, "player.energy > 80" },
  { generator, "player.spell(114015).exists" },
  -- actions+=/run_action_list,name=pool
  { preparation }


},{

  { "2823", { 
    "!player.buff(2823)", 
    "!player.moving",
  }},

  { "8676", { 
    "player.buff(1856)", 
    "target.spell(8676).range" 
  }, "target" },

  -- actions+=/premeditation,if=combo_points<=4
  { "Умысел", "player.combopoints <= 4", "target"},

  { "5171", { "player.buff(5171).duration < 4" }, "target"},
  
  { "8676", { 
    "player.buff(1784)", 
    "target.spell(8676).range" 
  }, "target" },
  
},
function()
ProbablyEngine.toggle.create('autotarget', 'Interface\\Icons\\Ability_hunter_mastermarksman','Auto Target','Enable or Disable the usage of Auto Target')
end)
