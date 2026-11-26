// 1.5.0 死灵精通 × 配件兄弟：驯服亡灵、把复活的单位装进配件（只在装了配件兄弟时加载）
//
// 每个复活类（scripts/entity/tactical/bgp_undead/）对应一个配件兄弟宠物种类，实体是 scripts/entity/tactical/bgp_pet/ 下的类。
// 宠物种类在 AfterHooks 阶段（necro_ac_library.nut）追加到配件兄弟宠物库末尾，排在兼容补丁之后。
// 宠物的基础属性取自被驯服 / 被装进配件的那个单位的基础属性（配件兄弟的升级是在绝对数值上加固定点数，
// 所以不能用 0 起步）；升级、特质池、存档都走配件兄弟自己的逻辑。

::BGP.NecroPet <- {
	Defs = [],
	// 复活类路径 -> 宠物种类编号
	Types = {},
	// 宠物种类编号 -> true
	OwnTypes = {},
	TamingActor = null,
	IsLoading = false,
	Values = {
		beast = 1500,
		undead = 1000,
		orc = 1500,
		goblin = 800
	},
	MaxPerCompany = 6,
	PetDir = "scripts/entity/tactical/bgp_pet/"
};

::BGP.NecroPet.addDef <- function( _short, _display, _category, _preferred )
{
	local wrapper = ::BGP.Necro.WrapperDir + "bgp_undead_" + _short;
	local pet = ::BGP.NecroPet.PetDir + "bgp_pet_" + _short;
	::BGP.NecroPet.Defs.push({
		Short = _short,
		Display = _display,
		Category = _category,
		Preferred = _preferred,
		Wrapper = wrapper,
		Pet = pet
	});
	// 宠物死后的尸体也能再复活成对应的复活类
	::BGP.Necro.RaiseMap[pet] <- wrapper;
}

::BGP.NecroPet.isOwnType <- function( _type )
{
	return _type != null && (_type in ::BGP.NecroPet.OwnTypes);
}

// 单位类路径 -> 宠物种类；_undeadOnly 时只认“亡灵”类别（驯服用）
::BGP.NecroPet.getTypeForScript <- function( _script, _undeadOnly )
{
	if (_script == null || !(_script in ::BGP.Necro.RaiseMap))
		return null;
	local wrapper = ::BGP.Necro.RaiseMap[_script];
	if (_undeadOnly && (!(wrapper in ::BGP.Necro.WrapperCategory) || ::BGP.Necro.WrapperCategory[wrapper] != "undead"))
		return null;
	if (!(wrapper in ::BGP.NecroPet.Types))
		return null;
	return ::BGP.NecroPet.Types[wrapper];
}

::BGP.NecroPet.getTypeForEntity <- function( _e, _undeadOnly )
{
	local script = null;
	try { script = ::IO.scriptFilenameByHash(_e.ClassNameHash); } catch (e) { script = null; }
	return ::BGP.NecroPet.getTypeForScript(script, _undeadOnly);
}

// 配件的属性、名字、伤势改成这个单位自己的
::BGP.NecroPet.fillFromEntity <- function( _item, _e )
{
	try
	{
		local b = _e.m.BaseProperties;
		local a = _item.m.Attributes;
		a.Hitpoints = b.Hitpoints;
		a.Stamina = b.Stamina;
		a.Bravery = b.Bravery;
		a.Initiative = b.Initiative;
		a.MeleeSkill = b.MeleeSkill;
		a.RangedSkill = b.RangedSkill;
		a.MeleeDefense = b.MeleeDefense;
		a.RangedDefense = b.RangedDefense;
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵宠物属性读取失败: " + e);
	}
	try { _item.m.Name = _e.getName(); } catch (e) {}
	try { _item.m.Wounds = ::Math.floor((1.0 - _e.getHitpointsPct()) * 100.0); } catch (e) {}
	try { _item.m.BGP_Gear = ::BGP.NecroPet.captureGear(_e); } catch (e) { ::logError("mod_bg_unique_perks: 死灵宠物装备记录失败: " + e); }
	try { _item.updateCompanion(); } catch (e) {}
}

// ---------------------------------------------------------------------------
// 1.5.1 死灵宠物的装备：被封入 / 驯服时记下各栏装备的类路径，放出时按记录生成满耐久的同款（不掉落）
// 记录格式："S:类路径;S:类路径;B:类路径"（S = 装备栏，B = 背包），没有装备是 ""；null 表示 1.5.0 的旧宠物（没记过）
// 存档：塞在配件兄弟名字串的 "\nmod_AC=" 前面（"\nbgp_gear=..."），读档时取出并从名字里去掉
// ---------------------------------------------------------------------------
::BGP.NecroPet.GearTag <- "\nbgp_gear=";
::BGP.NecroPet.GearSlots <- [
	::Const.ItemSlot.Mainhand,
	::Const.ItemSlot.Offhand,
	::Const.ItemSlot.Head,
	::Const.ItemSlot.Body,
	::Const.ItemSlot.Ammo
];

::BGP.NecroPet.captureGear <- function( _e )
{
	local parts = [];
	local items = _e.getItems();
	foreach (slot in ::BGP.NecroPet.GearSlots)
	{
		local it = null;
		try { it = items.getItemAtSlot(slot); } catch (e) { it = null; }
		if (it == null || typeof it == "integer")
			continue;
		try { parts.push("S:" + ::IO.scriptFilenameByHash(it.ClassNameHash)); } catch (e) {}
	}
	try
	{
		foreach (it in items.getAllItemsAtSlot(::Const.ItemSlot.Bag))
		{
			if (it == null || typeof it == "integer")
				continue;
			try { parts.push("B:" + ::IO.scriptFilenameByHash(it.ClassNameHash)); } catch (e) {}
		}
	}
	catch (e)
	{
	}
	local ret = "";
	foreach (i, p in parts)
		ret += (i == 0 ? "" : ";") + p;
	return ret;
}

// 按记录给放出的宠物穿装备；返回 false 表示没有记录（旧宠物）
::BGP.NecroPet.applyGear <- function( _e, _gear )
{
	if (_gear == null)
		return false;
	local items = _e.getItems();
	foreach (entry in split(_gear, ";"))
	{
		if (entry.len() < 3)
			continue;
		local kind = entry.slice(0, 2);
		local script = entry.slice(2);
		try
		{
			local it = ::new(script);
			if (kind == "B:")
				items.addToBag(it);
			else
				items.equip(it);
		}
		catch (e)
		{
			::logWarning("mod_bg_unique_perks: 死灵宠物装备生成失败（" + script + "）: " + e);
		}
	}
	return true;
}

// 满耐久 + 不掉落
::BGP.NecroPet.restoreGear <- function( _e )
{
	try
	{
		foreach (it in _e.getItems().getAllItems())
		{
			it.m.IsDroppedAsLoot = false;
			try
			{
				if (it.getArmorMax() > 0)
					it.setArmor(it.getArmorMax());
			}
			catch (e)
			{
			}
			try
			{
				if (it.getConditionMax() > 0)
					it.setCondition(it.getConditionMax());
			}
			catch (e)
			{
			}
		}
	}
	catch (e)
	{
	}
}

// 1.5.2 存档段：名字后面依次可能有 "\nbgp_gear=..."、"\nbgp_quirks=..."，再往后才是配件兄弟的 "\nmod_AC="。
// 本 mod 自己的特质（亡灵特质、死灵契约）不在配件兄弟的特质编号表里，存档时先从特质列表里拿出来写进 bgp_quirks 段，写完放回。
::BGP.NecroPet.QuirkTag <- "\nbgp_quirks=";

::BGP.NecroPet.isOwnQuirk <- function( _script )
{
	return _script == ::BGP.NecroPet.PactQuirk || ::BGP.NecroPet.OwnQuirks.find(_script) != null;
}

::BGP.NecroPet.serializeName <- function( _item, _original )
{
	local gear = null;
	try { gear = _item.m.BGP_Gear; } catch (e) { gear = null; }
	local quirks = null;
	local own = [];
	try
	{
		quirks = _item.m.Quirks;
		local rest = [];
		foreach (q in quirks)
		{
			if (::BGP.NecroPet.isOwnQuirk(q))
				own.push(q);
			else
				rest.push(q);
		}
		if (own.len() == 0)
			quirks = null;
		else
			_item.m.Quirks = rest;
	}
	catch (e)
	{
		quirks = null;
	}
	if (gear == null && own.len() == 0)
		return _original.call(_item);

	local name = _item.m.Name;
	local suffix = "";
	if (gear != null)
		suffix += ::BGP.NecroPet.GearTag + gear;
	if (own.len() > 0)
	{
		suffix += ::BGP.NecroPet.QuirkTag;
		foreach (i, q in own)
			suffix += (i == 0 ? "" : ";") + q;
	}
	_item.m.Name = name + suffix;
	local ret = null;
	try
	{
		ret = _original.call(_item);
	}
	catch (e)
	{
		_item.m.Name = name;
		if (quirks != null)
			_item.m.Quirks = quirks;
		throw e;
	}
	_item.m.Name = name;
	if (quirks != null)
		_item.m.Quirks = quirks;
	return ret;
}

::BGP.NecroPet.deserializeName <- function( _item, _original, _cn )
{
	_original.call(_item, _cn);
	try
	{
		local name = _item.m.Name;
		local found = [];
		foreach (t in [::BGP.NecroPet.GearTag, ::BGP.NecroPet.QuirkTag])
		{
			local idx = name.find(t);
			if (idx != null)
				found.push([idx, t]);
		}
		if (found.len() > 0)
		{
			found.sort(@(a, b) a[0] <=> b[0]);
			foreach (k, f in found)
			{
				local start = f[0] + f[1].len();
				local stop = k + 1 < found.len() ? found[k + 1][0] : name.len();
				local value = name.slice(start, stop);
				if (f[1] == ::BGP.NecroPet.GearTag)
				{
					_item.m.BGP_Gear = value;
				}
				else
				{
					foreach (q in split(value, ";"))
					{
						if (::BGP.NecroPet.isOwnQuirk(q) && _item.m.Quirks.find(q) == null)
							_item.m.Quirks.push(q);
					}
				}
			}
			_item.m.Name = name.slice(0, found[0][0]);
		}
		::BGP.NecroPet.replaceGoodBoy(_item);
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵宠物存档段读取失败: " + e);
	}
}

// ---------------------------------------------------------------------------
// 1.5.2 亡灵专属特质池（只对死灵宠物）
//   基础：配件兄弟 + 兼容补丁的通用池，去掉 韧性、狂怒、扔沙子
//   + 亡灵特质 5 个（不朽之躯、腐臭、死而复生、灵魂虹吸、中毒）
//   + 按记录的装备：主手武器对应的武器精通；有盾牌加盾牌专家
//   + 战斗锻造（1.5.3 起不设护甲门槛；1.6.0 起野兽除外，野兽保留轻灵；非野兽和轻灵互斥，所以池里去掉轻灵）
//   + 大体型（巨魔、树人、血肉魔像）加咄咄逼人、猛进疾退
//   11 级的“好孩子”换成“死灵契约”（效果相同）
// ---------------------------------------------------------------------------
::BGP.NecroPet.GoodBoy <- "scripts/companions/quirks/companions_good_boy";
::BGP.NecroPet.PactQuirk <- "scripts/skills/bgp_quirks/bgp_quirk_necro_pact";
::BGP.NecroPet.OwnQuirks <- [
	"scripts/skills/bgp_quirks/bgp_quirk_undying_flesh",
	"scripts/skills/bgp_quirks/bgp_quirk_rot_stench",
	"scripts/skills/bgp_quirks/bgp_quirk_unlife",
	"scripts/skills/bgp_quirks/bgp_quirk_soul_siphon",
	"scripts/skills/bgp_quirks/bgp_quirk_plague"
];
::BGP.NecroPet.ExcludedQuirks <- [
	"scripts/skills/perks/perk_hold_out",
	"scripts/companions/quirks/companions_berserker_rage",
	"scripts/skills/actives/throw_dirt_skill"
];
::BGP.NecroPet.BigShorts <- {
	unhold = true,
	unhold_armored = true,
	unhold_bog = true,
	unhold_frost = true,
	unhold_frost_armored = true,
	schrat = true,
	lesser_flesh_golem = true,
	lesser_flesh_golem_unarmed = true,
	greater_flesh_golem = true
};
::BGP.NecroPet.HeavyArmorMin <- 0;   // 1.5.3：原为 150，按用户要求取消门槛
// 宠物种类编号 -> necro_pets.nut 里的定义（necro_ac_library.nut 填）
::BGP.NecroPet.TypeDefs <- {};

::BGP.NecroPet.getMasteryFor <- function( _weapon )
{
	local P = "scripts/skills/perks/perk_mastery_";
	local W = ::Const.Items.WeaponType;
	foreach (pair in [
		["Axe", "axe"], ["Cleaver", "cleaver"], ["Dagger", "dagger"], ["Flail", "flail"], ["Hammer", "hammer"],
		["Mace", "mace"], ["Polearm", "polearm"], ["Spear", "spear"], ["Sword", "sword"],
		["Bow", "bow"], ["Crossbow", "crossbow"], ["Firearm", "crossbow"], ["Throwing", "throwing"]
	])
	{
		try
		{
			if ((pair[0] in W) && _weapon.isWeaponType(W[pair[0]]))
				return P + pair[1];
		}
		catch (e)
		{
		}
	}
	return null;
}

::BGP.NecroPet.getQuirkPool <- function( _item )
{
	local C = ::Const.Companions;
	local pool = [];
	local lists = [C.AttainableQuirks, C.AttainableQuirksBeasts];
	if (::Const.DLC.Unhold) lists.push(C.AttainableQuirksDLCUnhold);
	if (::Const.DLC.Wildmen) lists.push(C.AttainableQuirksDLCWildmen);
	if (::Const.DLC.Desert) lists.push(C.AttainableQuirksDLCDesert);
	foreach (list in lists)
	{
		foreach (q in list)
		{
			if (::BGP.NecroPet.ExcludedQuirks.find(q) == null && pool.find(q) == null)
				pool.push(q);
		}
	}
	local extra = clone ::BGP.NecroPet.OwnQuirks;

	local gear = null;
	try { gear = _item.m.BGP_Gear; } catch (e) { gear = null; }
	local armor = 0;
	if (gear != null)
	{
		foreach (entry in split(gear, ";"))
		{
			if (entry.len() < 3 || entry.slice(0, 2) != "S:")
				continue;
			local it = null;
			try { it = ::new(entry.slice(2)); } catch (e) { it = null; }
			if (it == null)
				continue;
			try
			{
				if (it.isItemType(::Const.Items.ItemType.Shield))
				{
					extra.push("scripts/skills/perks/perk_shield_expert");
				}
				else if (it.isItemType(::Const.Items.ItemType.Weapon) && it.getSlotType() == ::Const.ItemSlot.Mainhand)
				{
					local mastery = ::BGP.NecroPet.getMasteryFor(it);
					if (mastery != null)
						extra.push(mastery);
				}
			}
			catch (e)
			{
			}
			try
			{
				local slot = it.getSlotType();
				if (slot == ::Const.ItemSlot.Head || slot == ::Const.ItemSlot.Body)
					armor += it.getArmorMax();
			}
			catch (e)
			{
			}
		}
	}
	// 1.6.0 野兽保留轻灵、不加战斗锻造
	local isBeast = true;
	try { isBeast = ::BGP.NecroPet.TypeDefs[_item.m.Type].Category == "beast"; } catch (e) { isBeast = true; }
	if (!isBeast && armor >= ::BGP.NecroPet.HeavyArmorMin)
	{
		local idx = pool.find("scripts/skills/perks/perk_nimble");
		if (idx != null)
			pool.remove(idx);
		extra.push("scripts/skills/perks/perk_battle_forged");
	}

	try
	{
		local def = ::BGP.NecroPet.TypeDefs[_item.m.Type];
		if (def.Short in ::BGP.NecroPet.BigShorts)
		{
			extra.push("scripts/skills/perks/perk_rf_menacing");
			extra.push("scripts/skills/perks/perk_rf_formidable_approach");
		}
	}
	catch (e)
	{
	}

	foreach (q in extra)
	{
		if (pool.find(q) == null)
			pool.push(q);
	}
	return pool;
}

::BGP.NecroPet.replaceGoodBoy <- function( _item )
{
	try
	{
		if (!::BGP.NecroPet.isOwnType(_item.m.Type))
			return;
		local idx = _item.m.Quirks.find(::BGP.NecroPet.GoodBoy);
		if (idx == null)
			return;
		if (_item.m.Quirks.find(::BGP.NecroPet.PactQuirk) == null)
			_item.m.Quirks[idx] = ::BGP.NecroPet.PactQuirk;
		else
			_item.m.Quirks.remove(idx);
	}
	catch (e)
	{
	}
}

// 包住配件兄弟的 updateLevel：死灵宠物升级期间把配件兄弟的几个特质池换成亡灵池，结束后换回来
::BGP.NecroPet.updateLevel <- function( _item, _original )
{
	local own = false;
	try { own = ::BGP.NecroPet.isOwnType(_item.m.Type); } catch (e) { own = false; }
	if (!own)
		return _original.call(_item);

	local C = ::Const.Companions;
	local saved = [C.AttainableQuirks, C.AttainableQuirksBeasts, C.AttainableQuirksDLCUnhold, C.AttainableQuirksDLCWildmen, C.AttainableQuirksDLCDesert];
	local pool = null;
	try
	{
		pool = ::BGP.NecroPet.getQuirkPool(_item);
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 亡灵特质池生成失败: " + e);
		pool = null;
	}
	if (pool != null)
	{
		C.AttainableQuirks = pool;
		C.AttainableQuirksBeasts = [];
		C.AttainableQuirksDLCUnhold = [];
		C.AttainableQuirksDLCWildmen = [];
		C.AttainableQuirksDLCDesert = [];
	}
	local ok = true;
	local err = null;
	try
	{
		_original.call(_item);
	}
	catch (e)
	{
		ok = false;
		err = e;
	}
	C.AttainableQuirks = saved[0];
	C.AttainableQuirksBeasts = saved[1];
	C.AttainableQuirksDLCUnhold = saved[2];
	C.AttainableQuirksDLCWildmen = saved[3];
	C.AttainableQuirksDLCDesert = saved[4];
	if (!ok)
		throw err;
	::BGP.NecroPet.replaceGoodBoy(_item);
}

// 1.5.1 只有死灵法师能装备死灵宠物
::BGP.NecroPet.isOwnItem <- function( _item )
{
	try
	{
		if (_item == null || !("getType" in _item) || !("setType" in _item))
			return false;
		return ::BGP.NecroPet.isOwnType(_item.getType());
	}
	catch (e)
	{
	}
	return false;
}

::BGP.NecroPet.canEquip <- function( _actor, _item )
{
	// All company members (living brothers, permanent undead, and soulbound) can equip undead pet coffins.
	return true;
}

// Enable temporary combat injuries for undead pets (using Reforged's undead exclusion lists).
// Post-combat AC only persists item.m.Wounds (% HP), so temporary injuries naturally vanish after battle.
::BGP.NecroPet.ensureInjurySupport <- function( _e )
{
	try
	{
		local b = _e.getBaseProperties();
		b.IsAffectedByInjuries = true;
		b.IsAffectedByFreshInjuries = true;
		local skills = _e.getSkills();
		local receiver = skills.getSkillByID("special.rf_undead_injury_receiver");
		if (receiver == null)
		{
			receiver = ::new("scripts/skills/special/rf_undead_injury_receiver");
			skills.add(receiver);
		}
		receiver.m.ThresholdToReceiveInjuryMult = 1.0;

		if ("ExcludedInjuries" in ::Const.Injury && "RF_Undead" in ::Const.Injury.ExcludedInjuries)
		{
			local listId = _e.getFlags().has("skeleton") ? ::Const.Injury.ExcludedInjuries.RF_Skeleton : ::Const.Injury.ExcludedInjuries.RF_Undead;
			foreach (inj in ::Const.Injury.ExcludedInjuries.get(listId))
			{
				if (_e.m.ExcludedInjuries.find(inj) == null)
					_e.m.ExcludedInjuries.push(inj);
			}
		}
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵宠物临时伤支持初始化失败: " + e);
	}
}

// 把场上的单位直接移出地图（配件兄弟驯服成功时也是这样处理，不走死亡流程、不留尸体）
::BGP.NecroPet.removeEntity <- function( _e )
{
	try
	{
		if (_e.m.WorldTroop != null && ("Party" in _e.m.WorldTroop) && _e.m.WorldTroop.Party != null && !_e.m.WorldTroop.Party.isNull())
			_e.m.WorldTroop.Party.removeTroop(_e.m.WorldTroop);
	}
	catch (e)
	{
	}
	_e.m.IsDying = true;
	_e.m.IsAlive = false;
	_e.removeFromMap();
}

// ---------------------------------------------------------------------------
// 宠物实体（bgp_pet_*）的配件兄弟接口
// ---------------------------------------------------------------------------
::BGP.NecroPet.setItem <- function( _e, _i )
{
	if (typeof _i == "instance")
		_e.m.Item = _i;
	else
		_e.m.Item = ::WeakTableRef(_i);
}

::BGP.NecroPet.releaseItem <- function( _e )
{
	// 1.6.0 永恒禁卫：主人活着时阵亡不收回配件，配件仍指向它（等“不灭号令”唤回）
	try
	{
		if (::BGP.Champion.shouldKeepPet(_e))
		{
			_e.m.Item.m.BGP_GuardDown = true;
			return;
		}
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 永恒禁卫阵亡处理失败: " + e);
	}
	try
	{
		if (_e.m.Item != null && !_e.m.Item.isNull())
		{
			_e.m.Item.setEntity(null);
			if (_e.m.Item.getContainer() != null)
			{
				if (_e.m.Item.getCurrentSlotType() == ::Const.ItemSlot.Bag)
					_e.m.Item.getContainer().removeFromBag(_e.m.Item.get());
				else
					_e.m.Item.getContainer().unequip(_e.m.Item.get());
			}
		}
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵宠物阵亡收回配件失败: " + e);
	}
	_e.m.Item = null;
}

// 宠物击杀：照配件兄弟宠物的做法给在场兄弟和他们的宠物配件分经验。
// 继承原版僵尸 / 骷髅的宠物已经由配件兄弟自己的钩子（zombie.nut / skeleton.nut）给过，这里跳过。
::BGP.NecroPet.onKill <- function( _e, _victim )
{
	try
	{
		if (::isKindOf(_e, "zombie") || ::isKindOf(_e, "skeleton"))
			return;
		if (_e.getFaction() != ::Const.Faction.Player && _e.getFaction() != ::Const.Faction.PlayerAnimals)
			return;
		local xp = _victim.getXPValue();
		local brothers = ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.Player);
		if (brothers.len() == 0)
			return;
		local share = ::Math.max(1, ::Math.floor(xp / brothers.len()));
		foreach (bro in brothers)
		{
			bro.addXP(share);
			local acc = bro.getItems().getItemAtSlot(::Const.ItemSlot.Accessory);
			if (acc != null && "setType" in acc && acc.getType() != null)
				acc.addXP(share);
		}
	}
	catch (e)
	{
	}
}

::BGP.NecroPet.getCategory <- function( _e )
{
	try
	{
		local script = ::IO.scriptFilenameByHash(_e.ClassNameHash);
		local wrapper = ::BGP.Necro.RaiseMap[script];
		return ::BGP.Necro.WrapperCategory[wrapper];
	}
	catch (e)
	{
	}
	return "beast";
}

// 放出时：基础属性换成配件里的（含升级成长），加特质和特质对应的 AI 行为；
// 装备按配件里的记录生成（满耐久、不掉落）；1.5.0 的旧宠物没有记录，就随机生成一次并记下来，之后固定
::BGP.NecroPet.applyScaling <- function( _e )
{
	local item = _e.m.Item;
	// The release skill passes the inventory label to the actor before scaling.
	_e.setName(item.m.Name);
	try
	{
		local a = item.m.Attributes;
		local b = _e.m.BaseProperties;
		b.Hitpoints = a.Hitpoints;
		b.Stamina = a.Stamina;
		b.Bravery = a.Bravery;
		b.Initiative = a.Initiative;
		b.MeleeSkill = a.MeleeSkill;
		b.RangedSkill = a.RangedSkill;
		b.MeleeDefense = a.MeleeDefense;
		b.RangedDefense = a.RangedDefense;
		b.IsAffectedByInjuries = true;
		b.IsAffectedByFreshInjuries = true;
		_e.m.CurrentProperties = clone b;
		_e.m.Hitpoints = b.Hitpoints;
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵宠物属性缩放失败: " + e);
	}

	::BGP.NecroPet.ensureInjurySupport(_e);

	try
	{
		foreach (quirk in item.m.Quirks)
			_e.getSkills().add(::new(quirk));
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵宠物特质添加失败: " + e);
	}

	if ("AC_PH_Compat" in ::getroottable() && "addQuirkBehaviors" in ::AC_PH_Compat)
	{
		try { ::AC_PH_Compat.addQuirkBehaviors(_e); } catch (e) {}
	}

	local gear = null;
	try { gear = item.m.BGP_Gear; } catch (e) { gear = null; }
	// 1.6.0 修正：1.5.1–1.5.3 的装备记录有 bug（所有装备都被跳过，记成空的），非野兽的空记录当作没记过，随机生成一次重新记下
	if (gear == "" && ::BGP.NecroPet.getCategory(_e) != "beast")
		gear = null;
	if (!::BGP.NecroPet.applyGear(_e, gear))
	{
		try { _e.assignRandomEquipment(); } catch (e) {}
		try { item.m.BGP_Gear = ::BGP.NecroPet.captureGear(_e); } catch (e) {}
	}
	::BGP.NecroPet.restoreGear(_e);

	// 1.6.0 死灵宠物也挂“死灵仆从”效果（不死再生、钢铁之躯、嗜血者、心灵交融按主人的特技生效）；
	// 主人有“不灭冠军”时晋升为永恒禁卫（全属性 +10%）
	local owner = ::BGP.Champion.getPetOwner(_e);
	if (owner != null)
	{
		try
		{
			if (owner.getSkills().hasSkill("background.bgp_necromancer"))
			{
				::BGP.Champion.promotePet(_e, owner);
				::BGP.Necro.copySocket(owner, _e);
				::BGP.Necro.markMinion(owner, _e);
			}
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 死灵宠物挂仆从效果失败: " + e);
		}
	}
	if ("syncGrandmasterHunger" in ::BGP.Necro)
	{
		try { ::BGP.Necro.syncGrandmasterHunger(); } catch (e) {}
	}
	try { _e.getSkills().update(); } catch (e) {}
}
