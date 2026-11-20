// ---------- 通用：按特质给 AI 加行为（照抄配件兄弟宠物 AI 的 addQuirkBehaviors） ----------
::AC_PH_Compat.QuirkBehaviors <- [
	{ Skill = "perk.adrenaline",       ID = "Adrenaline",  Script = "scripts/ai/tactical/behaviors/ai_adrenaline" },
	{ Skill = "perk.recover",          ID = "Recover",     Script = "scripts/companions/behaviors/companions_recover" },
	{ Skill = "perk.rotation",         ID = "Rotation",    Script = "scripts/ai/tactical/behaviors/ai_defend_rotation" },
	{ Skill = "perk.rally_the_troops", ID = "Rally",       Script = "scripts/ai/tactical/behaviors/ai_rally" },
	{ Skill = "perk.footwork",         ID = "Disengage",   Script = "scripts/ai/tactical/behaviors/ai_disengage" },
	{ Skill = "perk.indomitable",      ID = "Indomitable", Script = "scripts/ai/tactical/behaviors/ai_indomitable" },
	{ Skill = "actives.throw_dirt",    ID = "Distract",    Script = "scripts/ai/tactical/behaviors/ai_distract" }
];

::AC_PH_Compat.addQuirkBehaviors <- function( _actor )
{
	local agent = _actor.getAIAgent();
	if (agent == null)
		return;

	foreach (info in ::AC_PH_Compat.QuirkBehaviors)
	{
		try
		{
			local id = ::Const.AI.Behavior.ID[info.ID];
			if (_actor.getSkills().hasSkill(info.Skill) && agent.getBehavior(id) == null)
			{
				agent.addBehavior(::new(info.Script));
				agent.m.Properties.BehaviorMult[id] = 0.25;
			}
		}
		catch (e)
		{
			::logWarning("mod_ac_ph_compat: AI 行为 " + info.ID + " 添加失败: " + e);
		}
	}
}

// ---------- 北境扩张冰原狼白灵（原名 Ghost） ----------
// 配件兄弟的 accessory_foundation（树钩子）会整套替换物品方法，包括 onEquip，
// 北境扩张原本“只有驯狼者能装备”的限制因此丢失。这里用同样的树钩子在它之后补回。
::AC_PH_Compat.HooksMod.hook("scripts/items/accessory/direwolf_item", function(q)
{
	q.create = @(__original) function()
	{
		__original();

		if ("NE_Ghost" in ::Const.Companions.TypeList)
			this.setType(::Const.Companions.TypeList.NE_Ghost);
	}
});

::AC_PH_Compat.HooksMod.rawHookTree("scripts/items/accessory/accessory", function(p)
{
	if (::IO.scriptFilenameByHash(p.ClassNameHash) != "scripts/items/accessory/direwolf_item")
		return;

	if (!("onEquip" in p))
		return;

	local original = p.onEquip;
	p.onEquip <- function()
	{
		original.call(this);

		try
		{
			local actor = this.getContainer().getActor();
			if (actor != null && actor.getFlags().get("NorthExpansionWolfmaster") != true)
			{
				this.getContainer().unequip(this);
				::World.Assets.getStash().add(this);
			}
		}
		catch (e) {}
	}

	// 旧存档里保存的是英文原名，读档时换成中文名；玩家自己改过的名字不动。
	if ("onDeserialize" in p)
	{
		local originalDeserialize = p.onDeserialize;
		p.onDeserialize <- function( _in )
		{
			originalDeserialize.call(this, _in);

			if (this.m.Name == "Ghost")
				this.m.Name = "白灵";
		}
	}
});

// ---------- 野兽专属特质：11 级时一次性获得（1.2.1 起；1.2.0 是放进随机池） ----------
// 配件兄弟在 11 级给“好孩子”，这里同一等级把该种类的全部专属特质补齐。
// 每次 updateLevel 之后和读档之后都检查一次，所以已经 11 级以上的老宠物读档时就会补上。
::AC_PH_Compat.MasteryLevel <- 11;

::AC_PH_Compat.grantBeastQuirks <- function( _item )
{
	local added = 0;

	try
	{
		if (_item.m.Type == null || _item.m.Level < ::AC_PH_Compat.MasteryLevel)
			return 0;

		foreach (quirk in ::AC_PH_Compat.getBeastQuirks(_item.m.Type))
		{
			if (_item.m.Quirks.find(quirk) == null)
			{
				_item.m.Quirks.push(quirk);
				added++;
			}
		}
	}
	catch (e) {}

	return added;
}

::AC_PH_Compat.HooksMod.rawHookTree("scripts/items/accessory/accessory", function(p)
{
	if (!("mod_AC_FoundationApplied" in p.m))
		return;

	if ("updateLevel" in p)
	{
		local original = p.updateLevel;
		p.updateLevel <- function()
		{
			original.call(this);
			::AC_PH_Compat.grantBeastQuirks(this);
		}
	}

	if ("onDeserialize" in p)
	{
		local originalDeserialize = p.onDeserialize;
		p.onDeserialize <- function( _in )
		{
			originalDeserialize.call(this, _in);
			::AC_PH_Compat.grantBeastQuirks(this);
		}
	}
});

// ---------- 1.2.2：战狼（原版 / 重铸 / 潘多拉的 wolf_item）接入配件兄弟 ----------
// 配件兄弟 2.1.14 在有重铸时故意跳过战狼：树钩子里若物品的 m.Script 是
// "scripts/entity/tactical/warwolf" 就不套宠物逻辑，create 里也不设种类。
// 普通 hook 先于树钩子执行，这里先把类默认的 m.Script 换掉，让配件兄弟照常接管，
// 再在 create 里补上“狼”种类。配件兄弟随后会用宠物库里的脚本覆盖 m.Script。
::AC_PH_Compat.HooksMod.hook("scripts/items/accessory/wolf_item", function(q)
{
	q.m.Script = "scripts/companions/types/companions_warwolf";

	q.create = @(__original) function()
	{
		__original();

		if ("setType" in this && this.getType() == null)
			this.setType(::Const.Companions.TypeList.Warwolf);
	}
});

// 配件兄弟的狼宠物是自定义实体，吃不到重铸和潘多拉对 warwolf 的改动，这里补回：
// 重铸：胆识 +10，近战技能、近战防御、远程防御各 +5，伤害 ×1.15；潘多拉：护甲 30/30。
::AC_PH_Compat.HooksMod.hook("scripts/companions/types/companions_warwolf", function(q)
{
	q.applyCompanionScaling = @(__original) function()
	{
		__original();

		local b = this.m.BaseProperties;

		if (::Hooks.hasMod("mod_reforged"))
		{
			b.Bravery += 10;
			b.MeleeSkill += 5;
			b.MeleeDefense += 5;
			b.RangedDefense += 5;
			b.DamageTotalMult *= 1.15;
		}

		try
		{
			local armor = ::Const.Tactical.Actor.WarWolf.Armor;
			b.Armor[0] = armor[0];
			b.Armor[1] = armor[1];
			b.ArmorMax[0] = armor[0];
			b.ArmorMax[1] = armor[1];
		}
		catch (e) {}

		this.m.Hitpoints = b.Hitpoints;
	}
});

// ---------- 德鲁伊召唤兽：按德鲁伊等级成长 + 随机宠物特质 ----------
::AC_PH_Compat.DruidAttrKeys <- ["Hitpoints", "Bravery", "Stamina", "Initiative", "MeleeSkill", "RangedSkill", "MeleeDefense", "RangedDefense"];
::AC_PH_Compat.QuirkIDCache <- {};

::AC_PH_Compat.getQuirkSkillID <- function( _script )
{
	if (!(_script in ::AC_PH_Compat.QuirkIDCache))
	{
		local id = null;
		try { id = ::new(_script).getID(); } catch (e) { id = null; }
		::AC_PH_Compat.QuirkIDCache[_script] <- id;
	}

	return ::AC_PH_Compat.QuirkIDCache[_script];
}

// 与配件兄弟宠物升级相同的可学特质池（good_boy 依赖宠物物品，召唤兽没有，改由召唤效果按同样公式给伤害）。
::AC_PH_Compat.getBeastQuirks <- function( _type )
{
	if (_type != null && ("BeastQuirks" in ::AC_PH_Compat) && (_type in ::AC_PH_Compat.BeastQuirks))
		return ::AC_PH_Compat.BeastQuirks[_type];

	return [];
}

::AC_PH_Compat.getAttainableQuirks <- function( _type = null )
{
	local C = ::Const.Companions;
	// 专属特质不进随机池，11 级时另外给（见 grantBeastQuirks / levelDruidBeast）
	local lists = [C.AttainableQuirks, C.AttainableQuirksBeasts];
	if (::Const.DLC.Unhold) lists.push(C.AttainableQuirksDLCUnhold);
	if (::Const.DLC.Wildmen) lists.push(C.AttainableQuirksDLCWildmen);
	if (::Const.DLC.Desert) lists.push(C.AttainableQuirksDLCDesert);

	local ret = [];
	foreach (list in lists)
	{
		foreach (quirk in list)
		{
			if (ret.find(quirk) == null)
				ret.push(quirk);
		}
	}
	return ret;
}

::AC_PH_Compat.rollAttribute <- function( _gains, _attr, _level )
{
	if (_level <= 11)
		_gains[_attr] += ::Math.rand(::Const.AttributesLevelUp[_attr].Min, ::Const.AttributesLevelUp[_attr].Max);
	else
		_gains[_attr] += 1;
}

// 模拟配件兄弟宠物从 1 级升到 _level 级：每级主属性 + 2 个随机属性（11 级前按升级范围随机，之后各 +1），
// 11 级前每级随机学一个特质。返回 { Gains = [...8 项], Quirks = [脚本路径...] }。
::AC_PH_Compat.rollCompanionLevels <- function( _level, _preferred, _ownedIDs, _type = null )
{
	local gains = [0, 0, 0, 0, 0, 0, 0, 0];
	local quirks = [];
	local pool = [];

	foreach (quirk in ::AC_PH_Compat.getAttainableQuirks(_type))
	{
		local id = ::AC_PH_Compat.getQuirkSkillID(quirk);
		if (id != null && _ownedIDs.find(id) == null)
			pool.push(quirk);
	}

	local maxLevel = ::Math.min(_level, ::Const.LevelXP.len());

	for (local lv = 2; lv <= maxLevel; lv = ++lv)
	{
		::AC_PH_Compat.rollAttribute(gains, _preferred, lv);
		local others = [0, 1, 2, 3, 4, 5, 6, 7];
		others.remove(others.find(_preferred));
		for (local i = 0; i < 2; i = ++i)
		{
			local r = ::Math.rand(0, others.len() - 1);
			::AC_PH_Compat.rollAttribute(gains, others[r], lv);
			others.remove(r);
		}

		if (lv <= 11 && pool.len() != 0)
		{
			local r = ::Math.rand(0, pool.len() - 1);
			quirks.push(pool[r]);
			pool.remove(r);
		}
	}

	return { Gains = gains, Quirks = quirks };
}

::AC_PH_Compat.levelDruidBeast <- function( _beast, _level )
{
	local preferred = ::Const.Attributes.MeleeSkill;
	local tameType = null;
	try
	{
		tameType = ::Const.Companions.resolveTameType(_beast);
		if (tameType != null)
			preferred = ::Const.Companions.Library[tameType].PreferredAttribute;
	}
	catch (e) { tameType = null; }

	local skills = _beast.getSkills();
	local owned = [];
	foreach (s in skills.m.Skills)
	{
		try { owned.push(s.getID()); } catch (e) {}
	}

	local result = ::AC_PH_Compat.rollCompanionLevels(_level, preferred, owned, tameType);

	// 德鲁伊 11 级起，召唤兽和同种宠物一样带上全部专属特质
	if (_level >= ::AC_PH_Compat.MasteryLevel)
	{
		foreach (quirk in ::AC_PH_Compat.getBeastQuirks(tameType))
		{
			if (result.Quirks.find(quirk) == null)
				result.Quirks.push(quirk);
		}
	}
	local b = _beast.getBaseProperties();

	foreach (i, key in ::AC_PH_Compat.DruidAttrKeys)
		b[key] += result.Gains[i];

	local names = [];
	foreach (quirk in result.Quirks)
	{
		try
		{
			local s = ::new(quirk);
			if (!skills.hasSkill(s.getID()))
			{
				skills.add(s);
				names.push(s.getName());
			}
		}
		catch (e)
		{
			::logWarning("mod_ac_ph_compat: 召唤兽特质 " + quirk + " 添加失败: " + e);
		}
	}

	local bond = ::new("scripts/skills/effects/ac_ph_druid_bond_effect");
	bond.setData(_level, result.Gains, names);
	skills.add(bond);

	::AC_PH_Compat.addQuirkBehaviors(_beast);

	skills.update();
	_beast.setHitpoints(_beast.getHitpointsMax());
	_beast.setDirty(true);

	return result;
}

::AC_PH_Compat.HooksMod.hook("scripts/skills/actives/druid_summon_beast", function(q)
{
	q.onUse = @(__original) function( _user, _targetTile )
	{
		local ret = __original(_user, _targetTile);

		if (!ret)
			return ret;

		try
		{
			local beast = _targetTile.getEntity();
			if (beast != null && ::isKindOf(beast, "actor") && beast.getFaction() == ::Const.Faction.PlayerAnimals)
			{
				beast.getFlags().set("AC_PH_OwnerID", _user.getID());
				::AC_PH_Compat.levelDruidBeast(beast, _user.getLevel());
			}
		}
		catch (e)
		{
			::logError("mod_ac_ph_compat: 德鲁伊召唤兽成长失败: " + e);
		}

		return ret;
	}
});
