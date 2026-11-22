// 1.4.0 死灵法师：尸体记录、复活、仆从、尸爆的公用逻辑
//
// 尸体记录：每个单位死亡时（actor.kill 前后 + 所有类的 generateCorpse），在尸体表里记下
//   BGP_Necro = { Script = 死者类路径, IsHuman = 是否人类（含战团成员）, MaxHP = 生前最大生命, Armor = 死亡瞬间头甲 + 身甲剩余耐久 }
// 复活：
//   人类尸体：沿用原版复活（尸体本身可复活时），变成原版僵尸。
//   野兽 / 亡灵 / 兽人 / 哥布林尸体：要有“死灵法术”，按 RaiseMap 在尸体格生成本 mod 单独的类
//   （scripts/entity/tactical/bgp_undead/），装备新生成且不进战利品。原尸体身上掉落的战利品留在地上（格子的 Items），
//   复活不碰它们；击杀经验在死亡时就已经给过，复活也不收回。
// 复活出来的单位都是战团的野兽阵营（PlayerAnimals，AI 控制），带 undead 旗标和“死灵仆从”效果。

::BGP.Necro <- {
	MinionEffect = "effects.bgp_necro_minion",
	WrapperDir = "scripts/entity/tactical/bgp_undead/",
	// 死者类路径 -> 复活后的类路径（由 1.4.0 生成的类文件对应，见 necro_raise_map.nut）
	RaiseMap = {},
	// 复活后的类路径 -> 类别（beast / undead / orc / goblin）
	WrapperCategory = {},
	DeathStash = {},
	CategoryNames = {
		beast = "野兽",
		undead = "亡灵",
		orc = "兽人",
		goblin = "哥布林"
	},
	// 心灵交融：只复制这些被动的防御 / 属性类特技
	MindMeldPerks = [
		"perk.colossus",
		"perk.steel_brow",
		"perk.nimble",
		"perk.rf_poise",
		"perk.hold_out",
		"perk.underdog",
		"perk.dodge",
		"perk.anticipation",
		"perk.nine_lives",
		"perk.stalwart",
		"perk.rf_survival_instinct"
	],
	ActiveIDs = [
		"actives.bgp_necro_raise",
		"actives.possess_undead",
		"actives.bgp_necro_infusion",
		"actives.bgp_corpse_explosion",
		"actives.bgp_necro_flesh_reforge",
		"actives.bgp_necro_eternal_command",
		"actives.bgp_necro_curse_of_ages"
	],
	// 1.6.0 两个互斥的特技组：学了一组的独有特技后，另一组的独有特技锁定（死灵精通两组共用，不参与互斥）
	ChampionPerks = [
		"perk.bgp_necro_possess",
		"perk.bgp_necro_flesh_reforge",
		"perk.bgp_necro_mind_meld",
		"perk.bgp_necro_infusion",
		"perk.bgp_necro_undying_champion"
	],
	ScourgePerks = [
		"perk.bgp_necro_flesh_of_iron",
		"perk.bgp_necro_regeneration",
		"perk.bgp_necro_blood_sucking",	// 1.6.1 起不在天灾组里，留着让学过它的老角色仍算“天灾”
		"perk.bgp_necro_fly_swarm",
		"perk.bgp_necro_curse_of_ages",
		"perk.bgp_corpse_explosion"
	]
};

::BGP.Necro.addRaise <- function( _deadClass, _wrapperName, _category )
{
	local wrapper = ::BGP.Necro.WrapperDir + _wrapperName;
	::BGP.Necro.RaiseMap["scripts/entity/tactical/" + _deadClass] <- wrapper;
	// 复活出来的单位死后可以再复活成同一个类
	::BGP.Necro.RaiseMap[wrapper] <- wrapper;
	::BGP.Necro.WrapperCategory[wrapper] <- _category;
}

// ---------------------------------------------------------------------------
// 死灵精通：本组主动技能 -1 行动点、疲劳 -25%（四舍五入）
// ---------------------------------------------------------------------------
::BGP.Necro.hasMastery <- function( _skill )
{
	try { return _skill.getContainer().hasSkill("perk.bgp_necro_mastery"); } catch (e) { return false; }
	return false;
}

::BGP.Necro.applyCost <- function( _skill, _baseAP, _baseFatigue )
{
	if (::BGP.Necro.hasMastery(_skill))
	{
		_skill.m.ActionPointCost = ::Math.max(0, _baseAP - 1);
		_skill.m.FatigueCost = ::Math.floor(_baseFatigue * 0.75 + 0.5);
	}
	else
	{
		_skill.m.ActionPointCost = _baseAP;
		_skill.m.FatigueCost = _baseFatigue;
	}
}

// ---------------------------------------------------------------------------
// 尸体记录
// ---------------------------------------------------------------------------
::BGP.Necro.getArmorRemaining <- function( _actor )
{
	local total = 0;
	foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
	{
		try
		{
			local piece = _actor.getItems().getItemAtSlot(slot);
			if (piece != null)
				total += ::Math.max(0, piece.getArmor());
		}
		catch (e)
		{
		}
	}
	return total;
}

::BGP.Necro.makeDeathInfo <- function( _actor )
{
	local info = {
		Script = "",
		IsHuman = false,
		MaxHP = 0,
		Armor = 0
	};
	try { info.Script = ::IO.scriptFilenameByHash(_actor.ClassNameHash); } catch (e) {}
	try { info.IsHuman = ::isKindOf(_actor, "human"); } catch (e) {}
	try { info.MaxHP = _actor.getHitpointsMax(); } catch (e) {}
	info.Armor = ::BGP.Necro.getArmorRemaining(_actor);
	return info;
}

// actor.kill 之前：记下生前最大生命和护甲（死亡流程里装备可能先掉落）
::BGP.Necro.beforeKill <- function( _actor )
{
	if (!::BGP.isInBattle())
		return null;
	local info = ::BGP.Necro.makeDeathInfo(_actor);
	try { ::BGP.Necro.DeathStash[_actor.getID()] <- info; } catch (e) {}
	return info;
}

::BGP.Necro.annotate <- function( _corpse, _info )
{
	if (_corpse == null || _info == null)
		return;
	if ("BGP_Necro" in _corpse)
		return;
	_corpse.BGP_Necro <- _info;
}

// actor.kill 之后：尸体所在格（死者原来的格）还没记的话补上
::BGP.Necro.afterKill <- function( _actor, _tile, _info )
{
	try { delete ::BGP.Necro.DeathStash[_actor.getID()]; } catch (e) {}
	if (_tile == null || _info == null)
		return;
	try
	{
		if (_tile.IsCorpseSpawned)
			::BGP.Necro.annotate(_tile.Properties.get("Corpse"), _info);
	}
	catch (e)
	{
	}
}

// generateCorpse：优先用 kill 之前记下的数据
::BGP.Necro.onGenerateCorpse <- function( _actor, _corpse )
{
	if (_corpse == null || ("BGP_Necro" in _corpse))
		return;
	local info = null;
	try
	{
		local id = _actor.getID();
		if (id in ::BGP.Necro.DeathStash)
			info = ::BGP.Necro.DeathStash[id];
	}
	catch (e)
	{
	}
	if (info == null)
		info = ::BGP.Necro.makeDeathInfo(_actor);
	::BGP.Necro.annotate(_corpse, info);
	// 1.6.0 永恒禁卫倒下时在残骸上记下主人和复活需要的东西（necro_champion.nut）
	try { ::BGP.Champion.tagGuardCorpse(_actor, _corpse); } catch (e) { ::logError("mod_bg_unique_perks: 永恒禁卫残骸记录失败: " + e); }
}

::BGP.Necro.getInfo <- function( _corpse )
{
	if (_corpse == null)
		return null;
	if ("BGP_Necro" in _corpse)
		return _corpse.BGP_Necro;
	return null;
}

::BGP.Necro.getCorpse <- function( _tile )
{
	try
	{
		if (_tile.IsCorpseSpawned)
			return _tile.Properties.get("Corpse");
	}
	catch (e)
	{
	}
	return null;
}

// 1.6.0 死灵法术并入背景：死灵法师背景（或旧角色身上的“死灵法术”特技）能复活野兽 / 亡灵 / 兽人 / 地精
::BGP.Necro.canRaiseAll <- function( _user )
{
	try
	{
		if (_user.getSkills().hasSkill("background.bgp_necromancer") || _user.getSkills().hasSkill("perk.bgp_necro_arts"))
			return true;
	}
	catch (e)
	{
	}
	return false;
}

::BGP.Necro.isGuardCorpse <- function( _corpse )
{
	try { return _corpse != null && ("BGP_Guard" in _corpse); } catch (e) {}
	return false;
}

// 原版 / 重铸“过几回合自己爬起来”的尸体：IsResurrectable 和 IsConsumable 同时被设为 false
::BGP.Necro.isPendingResurrection <- function( _corpse )
{
	try { return !_corpse.IsResurrectable && !_corpse.IsConsumable && _corpse.Type != null && _corpse.Type != ""; } catch (e) { return false; }
	return false;
}

// 返回 null 表示不能复活；否则 { Mode = "vanilla" / "spawn", Script, Category }
::BGP.Necro.getRaisePlan <- function( _user, _corpse )
{
	if (_corpse == null)
		return null;
	// 1.6.5 即将自行爬起的尸体（僵尸等）也能复活：复活时取消它原本排好的自行复活（见 raise 和 necro_hooks.nut）
	// 1.6.0 永恒禁卫的残骸只能用“不灭号令”唤回
	if (::BGP.Necro.isGuardCorpse(_corpse))
		return null;

	local info = ::BGP.Necro.getInfo(_corpse);
	local isHuman = info != null ? info.IsHuman : false;

	if (info == null)
	{
		// 没有记录的尸体（例如本 mod 装上之前的）：只按原版规则当人类尸体处理
		try { isHuman = (_corpse.IsResurrectable || ::BGP.Necro.isPendingResurrection(_corpse)) && _corpse.Type != null && _corpse.Type.find("orc") == null; } catch (e) { isHuman = false; }
	}

	if (isHuman)
	{
		try
		{
			// 1.6.6 被僵尸感染、即将化为行尸爬起的人类尸体（IsResurrectable 被置为 false）也能复活
			if ((_corpse.IsResurrectable || ::BGP.Necro.isPendingResurrection(_corpse)) && _corpse.Type != null && _corpse.Type != "")
				return { Mode = "vanilla", Script = _corpse.Type, Category = "human" };
		}
		catch (e)
		{
		}
		return null;
	}

	if (info == null || !(info.Script in ::BGP.Necro.RaiseMap))
		return null;
	if (!::BGP.Necro.canRaiseAll(_user))
		return null;

	local wrapper = ::BGP.Necro.RaiseMap[info.Script];
	return { Mode = "spawn", Script = wrapper, Category = ::BGP.Necro.WrapperCategory[wrapper] };
}

// 1.6.5 尸体被复活后，取消它排好的自行复活（本 mod 的 resurrect 钩子；亡灵诅咒认 UC_Consumed）
::BGP.Necro.consumeCorpse <- function( _corpse )
{
	if (_corpse == null || !::BGP.Necro.isPendingResurrection(_corpse))
		return;
	try { _corpse.BGP_Consumed <- true; } catch (e) {}
	try { if ("UC_Consumed" in _corpse) _corpse.UC_Consumed = true; else _corpse.UC_Consumed <- true; } catch (e) {}
}

::BGP.Necro.removeCorpse <- function( _tile )
{
	try { ::Tactical.Entities.removeCorpse(_tile); } catch (e) {}
	try { _tile.clear(::Const.Tactical.DetailFlag.Corpse); } catch (e) {}
	try { _tile.Properties.remove("Corpse"); } catch (e) {}
	try { _tile.Properties.remove("IsSpawningFlies"); } catch (e) {}
}

::BGP.Necro.copySocket <- function( _user, _e )
{
	try { _e.getSprite("socket").setBrush(_user.getSprite("socket").getBrush().Name); } catch (e) {}
}

// 复活一具尸体，成功返回新单位
::BGP.Necro.raise <- function( _user, _tile )
{
	local corpse = ::BGP.Necro.getCorpse(_tile);
	local plan = ::BGP.Necro.getRaisePlan(_user, corpse);
	if (plan == null)
		return null;

	local e = null;
	if (plan.Mode == "vanilla")
	{
		corpse.Faction = ::Const.Faction.PlayerAnimals;
		e = ::Tactical.Entities.onResurrect(corpse, true);
		if (e == null)
			return null;
		::BGP.Necro.consumeCorpse(corpse);
		try { e.setFaction(::Const.Faction.PlayerAnimals); } catch (err) {}
	}
	else
	{
		local x = _tile.Coords.X;
		local y = _tile.Coords.Y;
		::BGP.Necro.consumeCorpse(corpse);
		::BGP.Necro.removeCorpse(_tile);
		e = ::Tactical.spawnEntity(plan.Script, x, y);
		if (e == null)
			return null;
		try { e.setFaction(::Const.Faction.PlayerAnimals); } catch (err) {}
		// 1.5.1 起野兽也调用（装甲巨魔的甲在这里生成；其他野兽父类没有装备，调用不生成东西）
		try { e.assignRandomEquipment(); } catch (err) {}
		// 新生成的装备不掉落（死亡时不进战利品，战斗结束时复活类的 onBeforeCombatResult 也不放出来）
		::BGP.Necro.markGearNoLoot(e);
		try { e.m.Name = e.m.BGP_MinionName; } catch (err) {}
		try { e.riseFromGround(); } catch (err) {}
		try { e.getSkills().update(); } catch (err) {}
	}

	::BGP.Necro.copySocket(_user, e);
	::BGP.Necro.markMinion(_user, e);
	return e;
}

// ---------------------------------------------------------------------------
// 1.6.1 腐毒蝇群
// ---------------------------------------------------------------------------
::BGP.Necro.FlySwarmPerk <- "perk.bgp_necro_fly_swarm";
::BGP.Necro.FlySwarmEffect <- "effects.bgp_fly_swarm";

// 召唤亡灵 = 主人有腐毒蝇群的死灵仆从（含死灵宠物、永恒禁卫）
::BGP.Necro.isFlySwarmMinion <- function( _e )
{
	try
	{
		if (!_e.isAlive() || _e.isDying())
			return false;
		local m = ::BGP.Necro.getMaster(_e);
		return m != null && m.isAlive() && m.getSkills().hasSkill(::BGP.Necro.FlySwarmPerk);
	}
	catch (e)
	{
	}
	return false;
}

::BGP.Necro.forEachActor <- function( _f )
{
	foreach (faction in ::Tactical.Entities.getAllInstances())
	{
		foreach (a in faction)
		{
			if (a != null && a.isAlive())
				_f(a);
		}
	}
}

// 给场上所有和死灵法师敌对的活体（没有 undead 旗标）单位挂上效果
::BGP.Necro.spreadFlySwarm <- function( _necro )
{
	::BGP.Necro.forEachActor(function( _a )
	{
		try
		{
			if (_a.isAlliedWith(_necro) || _a.getFlags().has("undead"))
				return;
			if (!_a.getSkills().hasSkill(::BGP.Necro.FlySwarmEffect))
				_a.getSkills().add(::new("scripts/skills/effects/bgp_fly_swarm_effect"));
		}
		catch (e)
		{
		}
	});
}

// 召唤亡灵移动 / 倒下后，让带效果的单位重新计算相邻数量
::BGP.Necro.refreshFlySwarm <- function()
{
	::BGP.Necro.forEachActor(function( _a )
	{
		try
		{
			if (_a.getSkills().hasSkill(::BGP.Necro.FlySwarmEffect))
				_a.getSkills().update();
		}
		catch (e)
		{
		}
	});
}

::BGP.Necro.markGearNoLoot <- function( _e )
{
	try
	{
		foreach (item in _e.getItems().getAllItems())
			item.m.IsDroppedAsLoot = false;
	}
	catch (err)
	{
	}
}

// 给复活的单位挂上“死灵仆从”效果；不死再生、钢铁之躯、嗜血者、心灵交融按复活时主人的特技生效
::BGP.Necro.markMinion <- function( _user, _e )
{
	try
	{
		if (!_e.getFlags().has("undead"))
			_e.getFlags().add("undead");
		if (!_e.getFlags().has("bgp_necro_minion"))
			_e.getFlags().add("bgp_necro_minion");
		local fx = _e.getSkills().getSkillByID(::BGP.Necro.MinionEffect);
		if (fx == null)
		{
			fx = ::new("scripts/skills/effects/bgp_necro_minion_effect");
			_e.getSkills().add(fx);
		}
		fx.setMaster(_user);
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵仆从标记失败: " + e);
	}
}

::BGP.Necro.getMaster <- function( _e )
{
	try
	{
		local fx = _e.getSkills().getSkillByID(::BGP.Necro.MinionEffect);
		if (fx != null)
			return fx.getMaster();
	}
	catch (e)
	{
	}
	return null;
}

// 护甲恢复：头甲、身甲各按自身上限的比例恢复
::BGP.Necro.restoreArmorPct <- function( _actor, _pct )
{
	local restored = false;
	foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
	{
		try
		{
			local piece = _actor.getItems().getItemAtSlot(slot);
			if (piece == null)
				continue;
			local armor = piece.getArmor();
			local armorMax = piece.getArmorMax();
			if (armor >= armorMax)
				continue;
			piece.setArmor(::Math.min(armorMax, armor + armorMax * _pct));
			restored = true;
		}
		catch (e)
		{
		}
	}
	if (restored)
	{
		try { _actor.getSkills().update(); } catch (e) {}
		try { _actor.setDirty(true); } catch (e) {}
	}
	return restored;
}

// 复活类（bgp_undead_*）的 create / onInit 里调用
::BGP.Necro.onMinionCreate <- function( _e )
{
	try
	{
		if (!_e.getFlags().has("undead"))
			_e.getFlags().add("undead");
		if (!_e.getFlags().has("bgp_necro_minion"))
			_e.getFlags().add("bgp_necro_minion");
	}
	catch (e)
	{
	}
	try { _e.m.Name = _e.m.BGP_MinionName; } catch (e) {}
}

::BGP.Necro.onMinionInit <- function( _e )
{
	::BGP.Necro.applyBoundArt(_e);
	try { _e.m.Name = _e.m.BGP_MinionName; } catch (e) {}
	try
	{
		local b = _e.m.BaseProperties;
		b.IsImmuneToBleeding = true;
		b.IsImmuneToPoison = true;
		b.IsAffectedByNight = false;
		b.IsAffectedByInjuries = false;
		_e.m.CurrentProperties = clone b;
	}
	catch (e)
	{
	}
	try { _e.m.MoraleState = ::Const.MoraleState.Ignore; } catch (e) {}
	try { _e.m.XP = 0; } catch (e) {}
}

// ---------------------------------------------------------------------------
// 仆从击杀：经验和击杀数算给死灵法师（只给击杀者那一份，不触发他的击杀类特技）
// ---------------------------------------------------------------------------
::BGP.Necro.onMinionKill <- function( _master, _killer, _victim )
{
	try
	{
		if (_killer == null || _victim == null || _master == null)
			return;
		if (!_master.isAlive() || _master.isDying())
			return;
		local m = ::BGP.Necro.getMaster(_killer);
		if (m == null || m.getID() != _master.getID())
			return;
		// 1.6.0 死灵宠物也挂仆从效果，但它们的击杀经验按配件兄弟宠物的方式分（NecroPet.onKill），这里不再给
		local isPet = false;
		try { isPet = _killer.m.Item != null; } catch (e) { isPet = false; }
		if (isPet)
			return;
		if (_victim.isAlliedWith(_master))
			return;
		local xp = ::Math.floor(_victim.getXPValue() * ::Const.XP.XPForKillerPct);
		if (xp > 0)
			_master.addXP(xp);
		try { _master.m.LifetimeStats.Kills += 1; } catch (e) {}
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 死灵仆从击杀经验失败: " + e);
	}
}

// ---------------------------------------------------------------------------
// 尸爆
// ---------------------------------------------------------------------------
::BGP.Necro.spawnBloodbath <- function( _tile )
{
	try
	{
		for (local i = 0; i != ::Const.CorpsePart.len(); i++)
			_tile.spawnDetail(::Const.CorpsePart[i]);
	}
	catch (e)
	{
	}
	try
	{
		local decals = ::Const.BloodDecals[::Const.BloodType.Red];
		for (local i = 0; i != 6; i++)
		{
			if (!_tile.hasNextTile(i))
				continue;
			local next = _tile.getNextTile(i);
			for (local n = ::Math.rand(0, 2); n != 0; n--)
				next.spawnDetail(decals[::Math.rand(0, decals.len() - 1)]);
		}
	}
	catch (e)
	{
	}
}

::BGP.Necro.applyBlast <- function( _user, _skill, _target, _damage, _armorMult, _injuriesBody, _injuriesHead, _damageType )
{
	if (_damage <= 0)
		return;
	if (!_target.isAlive() || _target.isDying())
		return;
	local hitInfo = clone ::Const.Tactical.HitInfo;
	local head = ::Math.rand(1, 100) <= 25;
	hitInfo.DamageRegular = _damage;
	hitInfo.DamageArmor = _damage * _armorMult;
	hitInfo.DamageDirect = 0.0;
	hitInfo.BodyPart = head ? ::Const.BodyPart.Head : ::Const.BodyPart.Body;
	hitInfo.BodyDamageMult = 1.0;
	hitInfo.FatalityChanceMult = 1.0;
	hitInfo.Injuries = head ? _injuriesHead : _injuriesBody;
	try { hitInfo.DamageType = _damageType; } catch (e) {}
	try { hitInfo.Tile = _target.getTile(); } catch (e) {}
	_target.onDamageReceived(_user, _skill, hitInfo);
}

// 1.6.2 决心加成：W = 死灵法师当前决心 − WillOffset（1.6.3 起 20；1.6.2 不减）。决心含装备、光环，取整；W 最低 0
//   主动技能在施放时取值；不死再生每回合取主人当前值（主人不在场时用复活时记下的值）；
//   钢铁之躯在复活时取值；岁月诅咒在施放时记进效果。
::BGP.Necro.WillOffset <- 20;

// 当前决心（含装备、光环，取整）
::BGP.Necro.getResolve <- function( _actor )
{
	if (_actor == null)
		return 0;
	local w = 0;
	try
	{
		w = _actor.getCurrentProperties().getBravery();
	}
	catch (e)
	{
		try
		{
			local p = _actor.getCurrentProperties();
			w = p.Bravery * p.BraveryMult;
		}
		catch (e2)
		{
			w = 0;
		}
	}
	return ::Math.max(0, ::Math.floor(w));
}

::BGP.Necro.getWill <- function( _actor )
{
	return ::Math.max(0, ::BGP.Necro.getResolve(_actor) - ::BGP.Necro.WillOffset);
}

::BGP.Necro.WillScale <- {
	// 支配亡灵：受到伤害 -(W/4 - 5)%，0~30%（返回百分数）；近战技能 +W/5
	PossessReduction = function( _w ) { return ::Math.minf(30.0, ::Math.maxf(0.0, _w / 4.0 - 5.0)); },
	PossessMeleeSkill = function( _w ) { return ::Math.floor(_w / 5.0); },
	// 血肉重铸 骨刺外甲：骨甲 40 + W/2，反伤 5 + W/4
	BoneArmor = function( _w ) { return 40 + ::Math.floor(_w / 2.0); },
	BoneThorns = function( _w ) { return 5 + ::Math.floor(_w / 4.0); },
	// 死灵灌注：回 10 + W/4 生命、减 10 + W/6 疲劳
	InfusionHeal = function( _w ) { return 10 + ::Math.floor(_w / 4.0); },
	InfusionFatigue = function( _w ) { return 10 + ::Math.floor(_w / 6.0); },
	// 不灭号令：复活后生命、头甲、身甲 15% + W/3 %，最多 80%（返回比例；1.6.4 前为 20% + W/2 %）
	RevivePct = function( _w ) { return ::Math.minf(0.8, 0.15 + _w / 300.0); },
	// 不死再生：每回合 5 + W/5 生命
	Regen = function( _w ) { return 5 + ::Math.floor(_w / 5.0); },
	// 钢铁之躯：复活时头甲、身甲各恢复上限的 10% + W/4 %（返回比例；恢复量本身不超过上限）
	IronPct = function( _w ) { return 0.1 + _w / 400.0; },
	// 岁月诅咒：每次挨打头甲、身甲各 -(10 + W/4)
	CurseDecay = function( _w ) { return 10 + ::Math.floor(_w / 4.0); },
	// 尸爆：钝器伤害 = 生前最大生命 ×(20% + W/4 %)；被炸到的敌人士气检定难度 -W/4
	BlastPct = function( _w ) { return 0.2 + _w / 400.0; },
	BlastMorale = function( _w ) { return ::Math.floor(_w / 4.0); }
};

::BGP.Necro.pctText <- function( _ratio )
{
	return ::Math.round(_ratio * 100) + "%";
}

::BGP.Necro.willText <- function( _w )
{
	return "（W = 当前决心 − " + ::BGP.Necro.WillOffset + " = " + _w + "）";
}

// 支配亡灵按决心替换原版的近战技能和受伤减免：先记下改动前的值，原函数跑完后把改了的项换成新倍率
::BGP.Necro.DamageMultKeys <- [
	"DamageReceivedTotalMult",
	"DamageReceivedRegularMult",
	"DamageReceivedArmorMult",
	"DamageReceivedDirectMult",
	"DamageReceivedMeleeMult",
	"DamageReceivedRangedMult"
];

::BGP.Necro.snapKeys <- function( _t, _keys )
{
	local s = {};
	foreach (k in _keys)
	{
		try
		{
			if (k in _t)
				s[k] <- _t[k];
		}
		catch (e)
		{
		}
	}
	return s;
}

::BGP.Necro.rescaleKeys <- function( _t, _snap, _mult )
{
	local changed = 0;
	foreach (k, v in _snap)
	{
		if (_t[k] != v)
		{
			_t[k] = v * _mult;
			changed++;
		}
	}
	return changed;
}
