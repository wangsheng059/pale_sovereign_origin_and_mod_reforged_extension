// 尸爆：4 行动点、20 疲劳、6 格。摧毁目标格的一具尸体（之后不能再复活），对该格及相邻 1 格内的所有敌人（不伤友军）：
//   钝器伤害 = 尸体生前最大生命 × 35%（对护甲效率 100%）；
//   尸体死亡时头甲 + 身甲还有剩余耐久时，再加一次劈砍伤害 = 剩余耐久总和 × 25%（对护甲效率 150%）；
//   命中的敌人陷入“趔趄”（原版效果，下回合行动顺位延后）。
this.bgp_corpse_explosion_skill <- ::inherit("scripts/skills/skill", {
	m = {
		BaseAP = 4,
		BaseFatigue = 20,
		HitpointsPct = 0.35,
		ArmorPct = 0.25,
		ArmorEfficiency = 1.5
	},
	function create()
	{
		this.m.ID = "actives.bgp_corpse_explosion";
		this.m.Name = "尸爆";
		this.m.Description = "让一具尸体从内部炸开，血肉和残甲的碎片撕碎周围的敌人。";
		this.m.Icon = "skills/bgp_corpse_explosion_skill.png";
		this.m.IconDisabled = "skills/bgp_corpse_explosion_skill_sw.png";
		this.m.Overlay = "";
		this.m.SoundOnUse = [
			"sounds/enemies/gruesome_feast_01.wav",
			"sounds/enemies/gruesome_feast_02.wav",
			"sounds/enemies/gruesome_feast_03.wav"
		];
		this.m.SoundVolume = 1.3;
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.UtilityTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsTargetingActor = false;
		this.m.IsVisibleTileNeeded = false;
		this.m.IsStacking = false;
		this.m.IsAttack = false;
		this.m.IsIgnoredAsAOO = true;
		this.m.ActionPointCost = this.m.BaseAP;
		this.m.FatigueCost = this.m.BaseFatigue;
		this.m.MinRange = 1;
		this.m.MaxRange = 6;
		this.m.AIBehaviorID = null;
		this.m.DamageType.add(::Const.Damage.DamageType.Blunt);
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/vision.png", text = "技能范围为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格，不需要视野；目标为有尸体的格子（格子上可以有人）" },
			{ id = 11, type = "text", icon = "ui/icons/regular_damage.png", text = "对目标格和相邻 1 格内的所有敌人造成钝器伤害，等于尸体生前最大生命的 " + ::MSU.Text.colorPositive("35%") + "；不伤友军" },
			{ id = 12, type = "text", icon = "ui/icons/armor_damage.png", text = "尸体死亡时头甲、身甲还有剩余耐久的，额外造成劈砍伤害，等于剩余耐久总和的 " + ::MSU.Text.colorPositive("25%") + "（对护甲效率 " + ::MSU.Text.colorPositive("150%") + "）" },
			{ id = 13, type = "text", icon = "ui/icons/special.png", text = "被波及的敌人陷入“趔趄”；尸体被摧毁，不能再复活" }
		]);
		return ret;
	}

	function onAfterUpdate( _properties )
	{
		::BGP.Necro.applyCost(this, this.m.BaseAP, this.m.BaseFatigue);
	}

	function getBlast( _corpse )
	{
		local info = ::BGP.Necro.getInfo(_corpse);
		if (info == null || info.MaxHP <= 0)
			return null;
		return {
			Blunt = ::Math.floor(info.MaxHP * this.m.HitpointsPct),
			Cutting = ::Math.floor(info.Armor * this.m.ArmorPct)
		};
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		local corpse = ::BGP.Necro.getCorpse(_targetTile);
		if (corpse == null)
			return false;
		// 马上要自己爬起来的尸体不能炸（原版的复活计划已经排上了）
		if (::BGP.Necro.isPendingResurrection(corpse))
			return false;
		// 1.6.0 永恒禁卫的残骸不能炸
		if (::BGP.Necro.isGuardCorpse(corpse))
			return false;
		return this.getBlast(corpse) != null;
	}

	function onUse( _user, _targetTile )
	{
		local corpse = ::BGP.Necro.getCorpse(_targetTile);
		local blast = this.getBlast(corpse);
		if (blast == null)
			return false;

		::BGP.Necro.removeCorpse(_targetTile);
		try
		{
			foreach (p in ::Const.Tactical.KrakenDevourParticles)
				::Tactical.spawnParticleEffect(false, p.Brushes, _targetTile, p.Delay, p.Quantity, p.LifeTimeQuantity, p.SpawnRate, p.Stages);
			foreach (p in ::Const.Tactical.KrakenDevourVictimParticles)
				::Tactical.spawnParticleEffect(false, p.Brushes, _targetTile, p.Delay, p.Quantity, p.LifeTimeQuantity, p.SpawnRate, p.Stages);
		}
		catch (e)
		{
		}
		::BGP.Necro.spawnBloodbath(_targetTile);
		try { ::Tactical.getCamera().quake(::createVec(0, -1.0), 4.0, 0.16, 0.3); } catch (e) {}

		if (!_user.isHiddenToPlayer())
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "引爆了一具尸体（钝器 " + blast.Blunt + (blast.Cutting > 0 ? "，残甲劈砍 " + blast.Cutting : "") + "）");

		local tiles = [_targetTile];
		for (local i = 0; i < 6; i++)
		{
			if (_targetTile.hasNextTile(i))
				tiles.push(_targetTile.getNextTile(i));
		}

		foreach (tile in tiles)
		{
			if (!tile.IsOccupiedByActor)
				continue;
			local target = tile.getEntity();
			if (target == null || target.isAlliedWith(_user) || !target.isAlive() || target.isDying())
				continue;
			try
			{
				::BGP.Necro.applyBlast(_user, this, target, blast.Blunt, 1.0, ::Const.Injury.BluntBody, ::Const.Injury.BluntHead, ::Const.Damage.DamageType.Blunt);
				if (blast.Cutting > 0)
					::BGP.Necro.applyBlast(_user, this, target, blast.Cutting, this.m.ArmorEfficiency, ::Const.Injury.CuttingBody, ::Const.Injury.CuttingHead, ::Const.Damage.DamageType.Cutting);
				if (target.isAlive() && !target.isDying() && !target.getSkills().hasSkill("effects.staggered"))
					target.getSkills().add(::new("scripts/skills/effects/staggered_effect"));
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 尸爆伤害失败: " + e);
			}
		}
		return true;
	}
});
