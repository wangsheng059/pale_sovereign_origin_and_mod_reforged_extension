// ---------------------------------------------------------------------------
// 背景特技树：在重铸的特技树蓝图基础上，把“专属”集合换成本 mod 的特技组
// ---------------------------------------------------------------------------
::BGP.setExclusive <- function( _tree, _groups )
{
	try
	{
		if (_tree.m.DynamicMap == null)
			_tree.m.DynamicMap = {};
		_tree.m.DynamicMap["pgc.rf_exclusive_1"] <- _groups;
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 修改特技树蓝图失败: " + e);
	}
	return _tree;
}

// 通用：把某个背景的专属集合换成指定特技组（每个背景单独一个函数，避免在循环里用闭包捕获变量）
::BGP.ExclusiveMap <- {};
::BGP.hookExclusive <- function( _script, _group )
{
	::BGP.ExclusiveMap[_script] <- _group;
	::BGP.HooksMod.hook(_script, function(q)
	{
		q.createPerkTreeBlueprint = @(__original) function()
		{
			local tree = __original();
			local key = ::IO.scriptFilenameByHash(this.ClassNameHash);
			if (key in ::BGP.ExclusiveMap)
				{
				local groups = ::BGP.ExclusiveMap[key];
				::BGP.setExclusive(tree, typeof groups == "array" ? clone groups : [groups]);
			}
			return tree;
		}
	});
}

// 冒险贵族：1.2.0 起不再改，保持重铸原版的“贵族”组；“统帅”组改由本 mod 新背景“统帅”（bgp_commander_background）使用

// 成名剑师：重铸“士兵”组 → 成名剑师，保留“剑术大师”组
::BGP.HooksMod.hook("scripts/skills/backgrounds/rf_renowned_swordmaster_background", function(q)
{
	q.createPerkTreeBlueprint = @(__original) function()
	{
		return ::BGP.setExclusive(__original(), ["pg.bgp_renowned", "pg.rf_swordmaster"]);
	}
});

// ---------------------------------------------------------------------------
// 士气：兽群领袖（受伤不溃逃）
// 1.1.1：不再包装 checkMorale（和别的 mod 的可变参数包装叠在一起时会在实战中报
// wrong number of parameters，打断攻击和死亡流程）。狩猎时刻改为在效果的 onUpdate
// 里加决心；这里只包装 MV 提取出来的“受伤士气检定”，它是固定 3 个参数的 MV 自有函数。
// ---------------------------------------------------------------------------
::BGP.HooksMod.hook("scripts/entity/tactical/actor", function(q)
{
	q.MV_checkMoraleOnDamageReceived = @(__original) function( _skill, _attacker, _hitInfo )
	{
		local skip = false;
		try
		{
			// 再降一级就溃逃（当前为崩溃）时，有兽群领袖照看的野兽跳过这次受伤检定
			if (this.getMoraleState() - 1 <= ::Const.MoraleState.Fleeing)
			{
				local link = this.getSkills().getSkillByID("effects.bgp_beast_link");
				if (link != null && link.getPackLeader() != null)
					skip = true;
			}
		}
		catch (e)
		{
			skip = false;
		}

		if (skip)
			return;
		return __original(_skill, _attacker, _hitInfo);
	}
});

// ---------------------------------------------------------------------------
// 战争艺术：薪水、经验、扎营
// ---------------------------------------------------------------------------
::BGP.HooksMod.hook("scripts/entity/tactical/player", function(q)
{
	q.getDailyCost = @(__original) function()
	{
		local cost = __original();
		try
		{
			if (cost > 0 && ::BGP.companyHasPerk("perk.bgp_art_of_war") && ::BGP.isInRoster(this))
				cost = ::Math.round(cost * 0.9);
		}
		catch (e)
		{
		}
		return cost;
	}

	q.addXP = @(__original) function( _xp, _scale = true )
	{
		try
		{
			if (_scale && _xp > 0 && ::BGP.isInBattle() && ::BGP.companyHasPerk("perk.bgp_art_of_war"))
				_xp = _xp * 1.1;
		}
		catch (e)
		{
		}
		return __original(_xp, _scale);
	}
});

::BGP.HooksMod.hook("scripts/states/world/asset_manager", function(q)
{
	q.update = @(__original) function( _worldState )
	{
		local boosted = false;
		local oldRepair = null;
		local oldHeal = null;

		try
		{
			if (this.isCamping() && ::BGP.companyHasPerk("perk.bgp_art_of_war"))
			{
				boosted = true;
				if ("RepairSpeedMult" in this.m)
				{
					oldRepair = this.m.RepairSpeedMult;
					this.m.RepairSpeedMult = oldRepair * 1.2;
				}
				if ("HitpointsPerHourMult" in this.m)
				{
					oldHeal = this.m.HitpointsPerHourMult;
					this.m.HitpointsPerHourMult = oldHeal * 1.2;
				}
			}
		}
		catch (e)
		{
			boosted = false;
		}

		local ret = __original(_worldState);

		if (boosted)
		{
			// 原函数如果自己重置了倍率就不再改回
			if (oldRepair != null && this.m.RepairSpeedMult == oldRepair * 1.2)
				this.m.RepairSpeedMult = oldRepair;
			if (oldHeal != null && this.m.HitpointsPerHourMult == oldHeal * 1.2)
				this.m.HitpointsPerHourMult = oldHeal;
		}

		return ret;
	}
});

// ---------------------------------------------------------------------------
// 1.1.0：刺客、流浪骑士、角斗士的专属组（老执誓者是本 mod 的新背景，自己在背景文件里换）
// ---------------------------------------------------------------------------
foreach (entry in [
	["scripts/skills/backgrounds/assassin_background", "pg.bgp_assassin"],
	["scripts/skills/backgrounds/assassin_southern_background", "pg.bgp_assassin"],
	["scripts/skills/backgrounds/hedge_knight_background", "pg.bgp_knight"],
	["scripts/skills/backgrounds/gladiator_background", "pg.bgp_gladiator"]
])
{
	::BGP.hookExclusive(entry[0], entry[1]);
}

// 不灭圣徒：MV 把原版“九命猫 / 博学者药水”的免死判断提取成了 MV_onBeforeDeathConfirmed，接在它后面
::BGP.HooksMod.hook("scripts/entity/tactical/actor", function(q)
{
	q.MV_onBeforeDeathConfirmed = @(__original) function( _attacker, _skill, _hitInfo )
	{
		__original(_attacker, _skill, _hitInfo);
		if (this.getHitpoints() > 0)
			return;
		try
		{
			local perk = this.getSkills().getSkillByID("perk.bgp_undying_saint");
			if (perk != null)
				perk.tryCheatDeath();
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 不灭圣徒免死失败: " + e);
		}
		if (this.getHitpoints() > 0)
			return;

		// 1.5.2 死灵宠物特质“死而复生”
		try
		{
			local quirk = this.getSkills().getSkillByID("quirk.bgp_unlife");
			if (quirk != null)
				quirk.tryCheatDeath();
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 死而复生免死失败: " + e);
		}
		if (this.getHitpoints() > 0)
			return;

		// 1.3.0 千面归一：深渊同体（相邻队友分担一半伤害免死）；没救下来时触发苦痛转嫁
		try
		{
			local link = this.getSkills().getSkillByID("effects.bgp_command_link");
			if (link != null && !link.tryShareDeath(_hitInfo))
				link.onLethal();
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 千面归一致命伤处理失败: " + e);
		}
	}
});

// ---------------------------------------------------------------------------
// 1.3.0 统帅：神选者且等级 ≥ 11 时自动升为达库尔先知（不受“只能有一个先知”影响，不依赖原版事件）
// 在大地图上检查（战斗结束回到大地图后生效），每 2 秒（真实时间）检查一次名册
// ---------------------------------------------------------------------------
::BGP.ProphetCheckTime <- 0.0;
::BGP.checkCommanderProphet <- function()
{
	foreach (bro in ::World.getPlayerRoster().getAll())
	{
		try
		{
			if (!::BGP.isCommander(bro) || bro.getLevel() < 11)
				continue;
			local skills = bro.getSkills();
			if (!skills.hasSkill("trait.cultist_chosen") || skills.hasSkill("trait.cultist_prophet"))
				continue;
			skills.removeByID("trait.cultist_chosen");
			skills.add(::new("scripts/skills/traits/cultist_prophet_trait"));
			::logInfo("mod_bg_unique_perks: 统帅 " + bro.getName() + " 升为达库尔先知");
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 统帅升先知失败: " + e);
		}
	}
}

::BGP.HooksMod.hook("scripts/states/world/asset_manager", function(q)
{
	q.update = @(__original) function( _worldState )
	{
		local ret = __original(_worldState);
		try
		{
			local now = ::Time.getRealTimeF();
			if (now - ::BGP.ProphetCheckTime >= 2.0 || now < ::BGP.ProphetCheckTime)
			{
				::BGP.ProphetCheckTime = now;
				::BGP.checkCommanderProphet();
				::BGP.Necro.ensureGrandmasterInPerkTrees();
			}
		}
		catch (e)
		{
		}
		return ret;
	}
});

// ---------------------------------------------------------------------------
// 1.3.1 驯兽组：任何单位放上地图时（队友放出宠物、召唤等），场上有驯兽组特技就马上给友方野兽挂联动效果。
// 之前只在驯兽师自己用技能、回合开始等时机补挂，队友放出的野兽要等到野兽或驯兽师行动才生效。
// 放出的野兽可能在放上地图之后才设置阵营，所以 1 毫秒后再补一次。
// ---------------------------------------------------------------------------
::BGP.BeastPerkIDs <- ["perk.bgp_pack_leader", "perk.bgp_hunting_fever", "perk.bgp_shared_hatred"];
::BGP.onActorPlaced <- function()
{
	if (!::BGP.isInBattle())
		return;
	foreach (id in ::BGP.BeastPerkIDs)
	{
		if (::BGP.getBrosWithSkill(id).len() > 0)
		{
			::BGP.ensureBeastLinks();
			return;
		}
	}
}

::BGP.HooksMod.hook("scripts/entity/tactical/actor", function(q)
{
	q.onPlacedOnMap = @(__original) function()
	{
		__original();
		try
		{
			if (!::BGP.isInBattle())
				return;
			::BGP.onActorPlaced();
			::BGP.Necro.ensureHunger();
			::Time.scheduleEvent(::TimeUnit.Virtual, 1, function( _data )
			{
				try { ::BGP.onActorPlaced(); } catch (e) {}
				try { ::BGP.Necro.ensureHunger(); } catch (e) {}
			}, null);
		}
		catch (e)
		{
		}
	}
});
