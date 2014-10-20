local UnitsAroundMe = function (distance)
  local total = 0
  if FireHack then
    local totalObjects = ObjectCount()
    for i = 1, totalObjects do
      local object = ObjectWithIndex(i)
      if bit.band(ObjectType(object), ObjectTypes.Unit) > 0 then
      	if UnitReaction("player", object) <= 4 and UnitAffectingCombat(object) then
      	  local ax, ay, az = ObjectPosition("player")
          local bx, by, bz = ObjectPosition(object)
          if abs(math.sqrt(((bx-ax)^2) + ((by-ay)^2) + ((bz-az)^2)) - (UnitCombatReach("player") + UnitCombatReach(object))) <= distance then
            total = total + 1
          end
      	end
      end
    end
  end
  return total
end

local VanishCheck = function ()
  -- energy+cooldown.shadow_dance.remains*energy.regen<80|energy+cooldown.vanish.remains*energy.regen<60
  local energy = UnitPower("player", SPELL_POWER_ENERGY)
  local energyRegen = GetPowerRegen(player)
  local start, duration = GetSpellCooldown("Исчезновение")
  local vanishCD = (start + duration - GetTime())
  local start, duration = GetSpellCooldown("Танец теней")
  local shadowDanceCD = (start + duration - GetTime())
  if (energy+shadowDanceCD*energyRegen) < 80 or (energy+vanishCD*energyRegen) < 60 then
    return true
  else
    return false
  end
end

local poolEnergy = {
  -- preparation,if=!buff.vanish.up&cooldown.vanish.remains>60
  { "Подготовка", { "!player.buff(Исчезновение)", "player.spell(Исчезновение).cooldown > 60" }},
}

local generator = {
  -- actions.generator=run_action_list,name=pool,if=buff.master_of_subtlety.down&buff.shadow_dance.down&debuff.find_weakness.down&(energy+cooldown.shadow_dance.remains*energy.regen<80|energy+cooldown.vanish.remains*energy.regen<60)
  { poolEnergy, { "!player.buff(Мастер скрытности)", "!player.buff(Танец теней)", "!target.debuff(Поиск слабости)", (VanishCheck()) }},
  -- actions.generator+=/fan_of_knives,if=active_enemies>6
  { "Веер клинков", (UnitsAroundMe(10) >= 7) },
  -- actions.generator+=/hemorrhage,if=(remains<8&target.time_to_die>10)|position_front
  { "Кровоизлияние", "target.debuff(Кровоизлияние).duration < 8" },
  { "Кровоизлияние", "!player.behind"},
  -- actions.generator+=/shuriken_toss,if=energy<65&energy.regen<16
  { "Бросок сюрикена", { "player.spell(Бросок сюрикена).exists", "player.energy < 65", (GetPowerRegen(player) < 16) }},
  -- actions.generator+=/backstab
  { "Удар в спину" },
  -- actions.generator+=/run_action_list,name=pool
  { poolEnergy },
}

local finisher = {
  -- actions.finisher=slice_and_dice,if=buff.slice_and_dice.remains<4
  { "Мясорубка", "player.buff(Мясорубка).duration < 4" },
  -- actions.finisher+=/death_from_above
  { "Смерть с небес", "player.spell(Смерть с небес).exists"},
  -- actions.finisher+=/rupture,cycle_targets=1,if=(!ticking|remains<duration*0.3)&active_enemies<=3&(cooldown.death_from_above.remains>0|!talent.death_from_above.enabled)
  { "Рваная рана", { "!target.debuff(Рваная рана)", (UnitsAroundMe(1.2) <= 3), "player.spell(Смерть с небес).cooldown > 0" }},
  { "Рваная рана", { "!target.debuff(Рваная рана)", (function () return UnitsAroundMe(1.2) <= 3 end), "!player.spell(Смерть с небес).exists" }},
  { "Рваная рана", { "target.debuff(Рваная рана).duration <= 7.2", (UnitsAroundMe(1.2) <= 3), "player.spell(Смерть с небес).cooldown > 0" }},
  { "Рваная рана", { "target.debuff(Рваная рана).duration <= 7.2", (UnitsAroundMe(1.2) <= 3), "!player.spell(Смерть с небес).exists" }},
  -- actions.finisher+=/crimson_tempest,if=(active_enemies>3&dot.crimson_tempest_dot.ticks_remain<=2&combo_points=5)|active_enemies>=5&(cooldown.death_from_above.remains>0|!talent.death_from_above.enabled)
  { "Кровавый вихрь", { (UnitsAroundMe(10) > 3), "target.debuff(Кровавый вихрь).duration <= 5.9", "player.combopoints = 5"}},
  { "Кровавый вихрь", { (UnitsAroundMe(10) >= 5), "player.spell(Смерть с небес).cooldown > 0"}},
  { "Кровавый вихрь", { (UnitsAroundMe(10) >= 5), "!player.spell(Смерть с небес).exists"}},
  -- actions.finisher+=/eviscerate,if=active_enemies<4|(active_enemies>3&dot.crimson_tempest_dot.ticks_remain>=2)&(cooldown.death_from_above.remains>0|!talent.death_from_above.enabled)
  { "Потрошение", { (UnitsAroundMe(10) < 4) }},
  { "Потрошение", { (UnitsAroundMe(10) > 3), "target.debuff(Кровавый вихрь).duration < 5.9", "player.spell(Смерть с небес).cooldown > 0"}},
  { "Потрошение", { (UnitsAroundMe(10) > 3), "target.debuff(Кровавый вихрь).duration < 5.9", "!player.spell(Смерть с небес).exists"}},
  -- actions.finisher+=/run_action_list,name=pool
  { poolEnergy },
}
-- SPEC ID 261
ProbablyEngine.rotation.register_custom(261, "biGGerSub", {

  { "Смертоносный яд", { "!player.buff(Смертоносный яд)", "!player.moving" }},
  
  -- actions+=/premeditation,if=combo_points<=4
  { "Умысел", "player.combopoints <= 4", "target"},

  -- actions+=/ambush,if=combo_points<5|(talent.anticipation.enabled&anticipation_charges<3)
  { "Внезапный удар", { "player.combopoints < 5", "player.buff(Танец теней)" }},
  { "Внезапный удар", { "player.buff(Предчувствие).count < 3", "player.buff(Танец теней)" }},
  { "pause", { "player.combopoints <= 4", "player.buff(Танец теней)"}},

  -- actions+=/shadow_dance,if=energy>=75&buff.stealth.down&buff.vanish.down&debuff.find_weakness.down
  { "pause" , {"player.spell(Танец теней).cooldown <= 0", "player.energy <= 75", "!player.buff(Исчезновение)", "!target.debuff(Поиск слабости)", "!player.buff(Незаметность)"}},
  { "Танец теней", { "!player.buff(Исчезновение)", "!target.debuff(Поиск слабости)", "!player.buff(Незаметность)"}},

  -- actions+=/vanish,if=energy>=45&energy<=75&combo_points<=3&buff.shadow_dance.down&buff.master_of_subtlety.down&debuff.find_weakness.down
  { "pause" , {"player.spell(Исчезновение).cooldown <= 0", "player.energy <= 45", "player.energy <= 75", "player.combopoints <= 3", "!player.buff(Танец теней)", "!player.buff(Мастер скрытности)", "!target.debuff(Поиск слабости)"}},
  { "Исчезновение", { "player.energy >= 45", "player.energy <= 75", "player.combopoints <= 3", "!player.buff(Танец теней)", "!player.buff(Мастер скрытности)", "!target.debuff(Поиск слабости)"}},
  
  -- actions+=/marked_for_death,if=combo_points=0
  {"Метка смерти", {"player.spell(Метка смерти).exists", "player.combopoints = 0"}},
  -- actions+=/shadow_reflection,if=buff.shadow_dance.up
  {"Теневое отражение", {"player.spell(Теневое отражение).exists", "player.buff(Танец теней)"}},


  -- actions+=/run_action_list,name=generator,if=talent.anticipation.enabled&anticipation_charges<4&buff.slice_and_dice.up&dot.rupture.remains>2&(buff.slice_and_dice.remains<6|dot.rupture.remains<4)
  { generator, { "player.spell(Предчувствие).exists", "player.buff(Предчувствие).count < 4", "player.buff(Мясорубка)", "target.debuff(Кровоизлияние).duration > 2", "player.buff(Мясорубка).duration < 6"}},
  { generator, { "player.spell(Предчувствие).exists", "player.buff(Предчувствие).count < 4", "player.buff(Мясорубка)", "target.debuff(Кровоизлияние).duration > 2", "target.debuff(Кровоизлияние).duration < 4"}},
  -- actions+=/run_action_list,name=finisher,if=combo_points=5
  { finisher, "player.combopoints = 5"},
  -- actions+=/run_action_list,name=generator,if=combo_points<4|energy>80|talent.anticipation.enabled
  { generator, "player.combopoints < 4" },
  { generator, "player.energy > 80" },
  { generator, "player.spell(Предчувствие).exists" },
  -- actions+=/run_action_list,name=pool
  { poolEnergy }


},{

  { "Смертоносный яд", { 
    "!player.buff(Смертоносный яд)", 
    "!player.moving",
  }},

  { "Внезапный удар", { 
    "player.buff(Исчезновение)", 
    "target.spell(Внезапный удар).range" 
  }, "target" },

  -- actions+=/premeditation,if=combo_points<=4
  { "Умысел", "player.combopoints <= 4", "target"},

  { "Мясорубка", {}, "target"},
  
  { "Внезапный удар", { 
    "player.buff(Незаметность)", 
    "target.spell(Внезапный удар).range" 
  }, "target" },
  
})
