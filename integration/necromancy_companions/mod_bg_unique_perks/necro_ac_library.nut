// 1.5.0 死灵宠物种类登记（AfterHooks：配件兄弟的宠物库已定义，兼容补丁的 20–22 号已追加）
// 种类编号 = 宠物库长度，按 necro_pets.nut 的顺序依次追加；已登记过的不重复加。

local C = ::Const.Companions;

local makeName = function( _n )
{
	return function() { return _n; };
}

foreach (d in ::BGP.NecroPet.Defs)
{
	local key = "BGP_" + d.Short;
	if (!(key in C.TypeList))
	{
		C.TypeList[key] <- C.Library.len();
		C.Library.push({
			ID = "accessory.bgp_pet_" + d.Short,
			Type = C.TypeList[key],
			Name = makeName(d.Display),
			NameUnleashed = "棺椁",
			Description = "一具以铜箍封紧的木棺，里面封着一个被死灵法术束缚的" + ::BGP.Necro.CategoryNames[d.Category] + "（" + d.Display + "）。可在战斗中放出，让它为你而战；它会像宠物一样积累经验、成长，并学会新的特质。只有亡灵法师能装备。",
			DescriptionUnleashed = "棺盖已启，棺中空空。原本受缚于此的亡灵正在战场上为你而战。",
			IconLeashed = function( variant ) { return "tools/bgp_necro_vessel_70x70.png"; },
			IconUnleashed = "tools/bgp_necro_vessel_empty_70x70.png",
			Value = ::BGP.NecroPet.Values[d.Category],
			PartyStrength = 20,
			MaxPerCompany = ::BGP.NecroPet.MaxPerCompany,
			Variant = function() { return 1; },
			BasicQuirks = [],
			BasicAttributes = { Hitpoints = 60, Stamina = 100, Bravery = 50, Initiative = 80, MeleeSkill = 55, RangedSkill = 0, MeleeDefense = 5, RangedDefense = 5 },
			PreferredAttribute = d.Preferred,
			Script = d.Pet,
			ArmorScript = null,
			UnleashSounds = ["sounds/enemies/necromancer_01.wav", "sounds/enemies/necromancer_02.wav", "sounds/enemies/necromancer_03.wav"],
			InventorySounds = ["sounds/combat/armor_leather_impact_03.wav"],
			Unleash = {	Script = "scripts/companions/onequip/companions_unleash",
						Icon = function( variant ) { return "skills/bgp_necro_unleash.png"; },
						IconDisabled = function( variant ) { return "skills/bgp_necro_unleash_sw.png"; },
						Overlay = "",
						onActorDied = true	},
			Leash = {	Script = "scripts/companions/onequip/companions_leash",
						Icon = function( variant ) { return "skills/bgp_necro_unleash.png"; },
						IconDisabled = function( variant ) { return "skills/bgp_necro_unleash_sw.png"; },
						Overlay = ""	}
		});
	}
	::BGP.NecroPet.Types[d.Wrapper] <- C.TypeList[key];
	::BGP.NecroPet.OwnTypes[C.TypeList[key]] <- true;
	::BGP.NecroPet.TypeDefs[C.TypeList[key]] <- d;
}

// 驯服：带“亡灵法术大师”的人驯服亡灵时，按亡灵的类路径给出对应的死灵宠物种类（配件兄弟和兼容补丁认得的仍按原样）
local originalResolve = C.resolveTameType;
C.resolveTameType = function( _entity )
{
	local ret = originalResolve.call(this, _entity);
	if (ret != null || _entity == null)
		return ret;
	try
	{
		local actor = ::BGP.NecroPet.TamingActor;
		if (actor == null || !actor.getSkills().hasSkill("perk.bgp_necro_grandmaster"))
			return null;
		if (!_entity.isAlive())
			return null;
		return ::BGP.NecroPet.getTypeForEntity(_entity, true);
	}
	catch (e)
	{
	}
	return null;
};

::logInfo("mod_bg_unique_perks: 死灵宠物种类 " + ::BGP.NecroPet.Defs.len() + " 个，编号 " + ::BGP.NecroPet.Types[::BGP.NecroPet.Defs[0].Wrapper] + " 起");
