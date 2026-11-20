// AfterHooks：此时配件兄弟的 Const.Companions（宠物库、特质序列化表）已经定义。

local C = ::Const.Companions;

// ---------- 冠军特质：登记到存档用的特质表末尾 ----------
foreach (key in ::AC_PH_Compat.ChampionOrder)
{
	local id = ::AC_PH_Compat.getChampionQuirkID(key);

	if (id in C.SerializeQuirksByID)
		continue;

	C.SerializeQuirks.push(id);
	C.DeserializeQuirks.push(::AC_PH_Compat.getChampionQuirkScript(key));
	C.SerializeQuirksByID[id] <- C.SerializeQuirks.len() - 1;
}

// ---------- 恐惧战狼：新增宠物种类 ----------
if (!("Dreadwolf" in C.TypeList))
{
	C.TypeList.Dreadwolf <- C.Library.len();

	local dw = ::Const.Tactical.Actor.DreadWarWolf;

	C.Library.push({
		ID = "accessory.ph_dreadwolf",
		Type = C.TypeList.Dreadwolf,
		Name = function() { return ::Const.Strings.DreadwolfNames[::Math.rand(0, ::Const.Strings.DreadwolfNames.len() - 1)] + "恐惧狼"; },
		NameUnleashed = "恐狼项圈",
		Description = "通过实验唤醒狼族祖传力量而制造的嗜血野兽。尤其擅长追杀溃逃的敌人。",
		DescriptionUnleashed = "释放到战场上的恐狼项圈。旧神会接纳它们。",
		IconLeashed = function(variant) { return "tools/ph_dreadwolf_0" + variant + "_70x70.png"; },
		IconUnleashed = "tools/hound_01_leash_70x70.png",
		Value = 1800,
		PartyStrength = 20,
		MaxPerCompany = 4,
		Variant = function() { return ::Math.rand(1, 3); },
		// 潘多拉恐惧战狼 onInit 自带的技能
		BasicQuirks = ["scripts/skills/perks/perk_fearsome", "scripts/skills/perks/perk_pathfinder", "scripts/skills/perks/perk_steel_brow", "scripts/skills/perks/perk_backstabber"],
		BasicAttributes = {
			Hitpoints = dw.Hitpoints,
			Stamina = dw.Stamina,
			Bravery = dw.Bravery,
			Initiative = dw.Initiative,
			MeleeSkill = dw.MeleeSkill,
			RangedSkill = dw.RangedSkill,
			MeleeDefense = dw.MeleeDefense,
			RangedDefense = dw.RangedDefense
		},
		PreferredAttribute = ::Const.Attributes.MeleeSkill,
		Script = "scripts/companions/types/companions_ph_dreadwolf",
		ArmorScript = null,
		UnleashSounds = ["sounds/enemies/werewolf_idle_01.wav", "sounds/enemies/werewolf_idle_02.wav", "sounds/enemies/werewolf_idle_03.wav", "sounds/enemies/werewolf_idle_04.wav", "sounds/enemies/werewolf_idle_05.wav", "sounds/enemies/werewolf_idle_06.wav", "sounds/enemies/werewolf_idle_07.wav", "sounds/enemies/werewolf_idle_08.wav"],
		InventorySounds = ["sounds/enemies/werewolf_idle_11.wav"],
		Unleash = {	Script = "scripts/companions/onequip/companions_unleash",
					Icon = function(variant) { return "skills/direwolf_0" + variant + "_ac.png"; },
					IconDisabled = function(variant) { return "skills/direwolf_0" + variant + "_sw_ac.png"; },
					Overlay = "",
					onActorDied = true	},
		Leash = {	Script = "scripts/companions/onequip/companions_leash",
					Icon = function(variant) { return "skills/direwolf_0" + variant + "_ac.png"; },
					IconDisabled = function(variant) { return "skills/direwolf_0" + variant + "_sw_ac.png"; },
					Overlay = ""	}
	});
}

// ---------- 地狱犬（重铸）：新增宠物种类，并允许驯服 ----------
if (!("Hollenhund" in C.TypeList) && ("RF_Hollenhund" in ::Const.EntityType) && ("RF_Hollenhund" in ::Const.Tactical.Actor))
{
	C.TypeList.Hollenhund <- C.Library.len();

	local hh = ::Const.Tactical.Actor.RF_Hollenhund;

	C.Library.push({
		ID = "accessory.rf_hollenhund",
		Type = C.TypeList.Hollenhund,
		Name = function() { return ::Const.Companions.CanineNames[::Math.rand(0, ::Const.Companions.CanineNames.len() - 1)]; },
		NameUnleashed = "地狱犬项圈",
		Description = "一只从古冢里爬出的幽魂猎犬，被驯服后为战团效力。它不知疲倦、不知恐惧。可在战斗中释放，用以侦查、追踪或猎杀逃跑的敌人。",
		DescriptionUnleashed = "一条项圈，它拴着的地狱犬已被放到了战场上。",
		IconLeashed = function(variant) { return "loot/rf_hollenhund_bones.png"; },
		IconUnleashed = "tools/hound_01_leash_70x70.png",
		Value = 1500,
		PartyStrength = 25,
		MaxPerCompany = 3,
		Variant = function() { return ::Math.rand(1, 3); },
		// 灵体啃咬、灵雾、幽灵/骷髅种族由地狱犬本体自带
		BasicQuirks = ["scripts/skills/perks/perk_fearsome"],
		BasicAttributes = {
			Hitpoints = hh.Hitpoints,
			Stamina = hh.Stamina,
			Bravery = hh.Bravery,
			Initiative = hh.Initiative,
			MeleeSkill = hh.MeleeSkill,
			RangedSkill = hh.RangedSkill,
			MeleeDefense = hh.MeleeDefense,
			RangedDefense = hh.RangedDefense
		},
		PreferredAttribute = ::Const.Attributes.MeleeSkill,
		Script = "scripts/companions/types/companions_rf_hollenhund",
		ArmorScript = null,
		UnleashSounds = ["sounds/enemies/rf_hollenhund_idle_01.wav", "sounds/enemies/rf_hollenhund_idle_02.wav"],
		InventorySounds = ["sounds/enemies/rf_hollenhund_idle_01.wav"],
		Unleash = {	Script = "scripts/companions/onequip/companions_unleash",
					Icon = function(variant) { return "skills/direwolf_0" + variant + "_ac.png"; },
					IconDisabled = function(variant) { return "skills/direwolf_0" + variant + "_sw_ac.png"; },
					Overlay = "",
					onActorDied = true	},
		Leash = {	Script = "scripts/companions/onequip/companions_leash",
					Icon = function(variant) { return "skills/direwolf_0" + variant + "_ac.png"; },
					IconDisabled = function(variant) { return "skills/direwolf_0" + variant + "_sw_ac.png"; },
					Overlay = ""	}
	});

	local originalResolve = C.resolveTameType;
	C.resolveTameType = function( _entity )
	{
		local ret = originalResolve.call(this, _entity);

		if (ret == null && _entity != null)
		{
			try
			{
				if (_entity.isAlive() && _entity.getType() == ::Const.EntityType.RF_Hollenhund)
					return ::Const.Companions.TypeList.Hollenhund;
			}
			catch (e) {}
		}

		return ret;
	};
}

// ---------- 北境扩张冰原狼 Ghost ----------
if (!("NE_Ghost" in C.TypeList))
{
	C.TypeList.NE_Ghost <- C.Library.len();

	local dw = ::Const.Tactical.Actor.Direwolf;

	C.Library.push({
		ID = "accessory.direwolf",   // 驯狼者特性按这个 ID 识别自己的狼，不能改
		Type = C.TypeList.NE_Ghost,
		Name = function() { return "白灵"; },
		NameUnleashed = "冰原狼项圈",
		Description = "这头巨大的冰原狼对它的人类朋友乌鸦琼恩忠心耿耿，除此之外谁的话都不听。",
		DescriptionUnleashed = "被释放到战场上的冰原狼的项圈。",
		IconLeashed = function(variant) { return "tools/direwolf_70x70.png"; },
		IconUnleashed = "tools/hound_01_leash_70x70.png",
		Value = 0,
		PartyStrength = 18,
		MaxPerCompany = 1,
		Variant = function() { return 1; },
		// 北境扩张原版 Ghost 自带的技能
		BasicQuirks = ["scripts/skills/perks/perk_coup_de_grace", "scripts/skills/perks/perk_berserk", "scripts/skills/perks/perk_pathfinder"],
		BasicAttributes = {
			Hitpoints = dw.Hitpoints,
			Stamina = dw.Stamina,
			Bravery = dw.Bravery,
			Initiative = dw.Initiative,
			MeleeSkill = dw.MeleeSkill,
			RangedSkill = dw.RangedSkill,
			MeleeDefense = dw.MeleeDefense,
			RangedDefense = dw.RangedDefense
		},
		PreferredAttribute = ::Const.Attributes.MeleeSkill,
		Script = "scripts/companions/types/companions_ne_ghost",
		ArmorScript = null,
		UnleashSounds = ["sounds/combat/unleash_wardog_01.wav", "sounds/combat/unleash_wardog_02.wav", "sounds/combat/unleash_wardog_03.wav", "sounds/combat/unleash_wardog_04.wav"],
		InventorySounds = ["sounds/inventory/wardog_inventory_01.wav", "sounds/inventory/wardog_inventory_02.wav", "sounds/inventory/wardog_inventory_03.wav"],
		Unleash = {	Script = "scripts/companions/onequip/companions_unleash",
					Icon = function(variant) { return "skills/direwolf_01_ac.png"; },
					IconDisabled = function(variant) { return "skills/direwolf_01_sw_ac.png"; },
					Overlay = "",
					onActorDied = true	},
		Leash = {	Script = "scripts/companions/onequip/companions_leash",
					Icon = function(variant) { return "skills/direwolf_01_ac.png"; },
					IconDisabled = function(variant) { return "skills/direwolf_01_sw_ac.png"; },
					Overlay = ""	}
	});
}

// ---------- 1.2.0：新增特质（重铸特技） ----------
// 存档按序列化表下标保存，只能在末尾追加，顺序不能改。
::AC_PH_Compat.ExtraQuirks <- [
	["perk.rf_menacing",            "scripts/skills/perks/perk_rf_menacing"],
	["perk.rf_formidable_approach", "scripts/skills/perks/perk_rf_formidable_approach"],
	["perk.rf_strength_in_numbers", "scripts/skills/perks/perk_rf_strength_in_numbers"],
	["perk.rf_bully",               "scripts/skills/perks/perk_rf_bully"],
	["perk.rf_feral_rage",          "scripts/skills/perks/perk_rf_feral_rage"],
	["perk.rf_battle_fervor",       "scripts/skills/perks/perk_rf_battle_fervor"],
	["perk.rf_calculated_strikes",  "scripts/skills/perks/perk_rf_calculated_strikes"],
	["perk.rf_unstoppable",         "scripts/skills/perks/perk_rf_unstoppable"],
	["perk.rf_survival_instinct",   "scripts/skills/perks/perk_rf_survival_instinct"],
	["perk.rf_the_rush_of_battle",  "scripts/skills/perks/perk_rf_the_rush_of_battle"],
	["perk.rf_retribution",         "scripts/skills/perks/perk_rf_retribution"],
	["perk.rf_vengeful_spite",      "scripts/skills/perks/perk_rf_vengeful_spite"],
	["perk.rf_fresh_and_furious",   "scripts/skills/perks/perk_rf_fresh_and_furious"]
];

foreach (pair in ::AC_PH_Compat.ExtraQuirks)
{
	if (pair[0] in C.SerializeQuirksByID)
		continue;

	C.SerializeQuirks.push(pair[0]);
	C.DeserializeQuirks.push(pair[1]);
	C.SerializeQuirksByID[pair[0]] <- C.SerializeQuirks.len() - 1;
}

// 通用特质池：所有宠物（和德鲁伊召唤兽）升级时都可能学到
foreach (script in [
	"scripts/skills/perks/perk_rf_survival_instinct",
	"scripts/skills/perks/perk_rf_the_rush_of_battle",
	"scripts/skills/perks/perk_rf_retribution",
	"scripts/skills/perks/perk_rf_vengeful_spite",
	"scripts/skills/perks/perk_rf_fresh_and_furious"
])
{
	if (C.AttainableQuirks.find(script) == null)
		C.AttainableQuirks.push(script);
}

// 野兽专属特质：对应种类的宠物升到 11 级时一次性全部获得（hooks_more.nut 的 grantBeastQuirks）
local P = "scripts/skills/perks/";
local TL = C.TypeList;
::AC_PH_Compat.BeastQuirks <- {};
::AC_PH_Compat.BeastQuirks[TL.Direwolf] <- [P + "perk_battle_flow"];
::AC_PH_Compat.BeastQuirks[TL.DirewolfFrenzied] <- [P + "perk_battle_flow"];
::AC_PH_Compat.BeastQuirks[TL.Dreadwolf] <- [P + "perk_battle_flow"];
::AC_PH_Compat.BeastQuirks[TL.NE_Ghost] <- [P + "perk_battle_flow"];
::AC_PH_Compat.BeastQuirks[TL.Spider] <- [P + "perk_rf_strength_in_numbers"];
::AC_PH_Compat.BeastQuirks[TL.Snake] <- [P + "perk_rf_calculated_strikes"];
::AC_PH_Compat.BeastQuirks[TL.Nacho] <- [P + "perk_rf_menacing", P + "perk_rf_battle_fervor"];
::AC_PH_Compat.BeastQuirks[TL.Noodle] <- [P + "perk_rf_menacing", P + "perk_rf_formidable_approach", P + "perk_rf_calculated_strikes"];
::AC_PH_Compat.BeastQuirks[TL.Unhold] <- [P + "perk_rf_menacing", P + "perk_rf_formidable_approach", P + "perk_rf_bully", P + "perk_rf_feral_rage"];
::AC_PH_Compat.BeastQuirks[TL.UnholdArmor] <- [P + "perk_rf_menacing", P + "perk_rf_formidable_approach", P + "perk_rf_bully", P + "perk_rf_feral_rage"];
::AC_PH_Compat.BeastQuirks[TL.Schrat] <- [P + "perk_rf_unstoppable"];
