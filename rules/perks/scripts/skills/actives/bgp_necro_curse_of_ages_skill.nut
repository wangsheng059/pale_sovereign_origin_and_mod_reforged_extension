// Curse of Ages (Scourge tier 6): 6 AP, 24 Fatigue, range 7 (no LOS), target tile + 6 adjacent enemies (friendly-safe), 3 turns:
//   -1 AP, -50 Initiative, -10 MAtk/RAtk, -20% Melee/Ranged damage;
//   each attack hit (including Corpse Explosion) decays the hit body part's armor by -(10 + W/4).
//   Recasting refreshes duration and updates decay value without stacking.
this.bgp_necro_curse_of_ages_skill <- ::inherit("scripts/skills/skill", {
	m = {
		BaseAP = 6,
		BaseFatigue = 24
	},
	function create()
	{
		this.m.ID = "actives.bgp_necro_curse_of_ages";
		this.m.Name = "岁月诅咒";
		this.m.Description = "让一片区域里的敌人在几个呼吸间老去几十年：手脚迟缓，刀剑生锈，甲胄朽坏。";
		this.m.Icon = "skills/bgp_necro_curse_of_ages_skill.png";
		this.m.IconDisabled = "skills/bgp_necro_curse_of_ages_skill_sw.png";
		this.m.Overlay = "";
		this.m.SoundOnUse = [
			"sounds/enemies/necromancer_01.wav",
			"sounds/enemies/necromancer_02.wav",
			"sounds/enemies/necromancer_03.wav"
		];
		this.m.SoundVolume = 1.2;
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
		this.m.MaxRange = 7;
		this.m.AIBehaviorID = null;
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		local w = ::BGP.Necro.getWill(this.getContainer().getActor());
		local turns = 3 + ::BGP.Necro.spellDurationBonus(this.getContainer().getActor());
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/vision.png", text = "技能范围为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格，不需要视野；作用于目标格及相邻 1 格内的敌人，不影响友军" },
			{ id = 11, type = "text", icon = "ui/icons/initiative.png", text = "持续 " + turns + " 回合：行动点 " + ::MSU.Text.colorNegative("-1") + "，主动值 " + ::MSU.Text.colorNegative("-50") + "，近战技能 / 远程技能 " + ::MSU.Text.colorNegative("-10") + "，近战 / 远程伤害 " + ::MSU.Text.colorNegative("-20%") },
			{ id = 12, type = "text", icon = "ui/icons/armor_body.png", text = "诅咒期间每受到一次攻击伤害（含尸爆，哪怕只伤到护甲），命中部位护甲当前耐久额外 " + ::MSU.Text.colorNegative("-" + ::BGP.Necro.WillScale.CurseDecay(w)) + ::BGP.Necro.willText(w) },
			{ id = 13, type = "text", icon = "ui/icons/special.png", text = "再次诅咒同一目标只刷新持续时间（护甲腐朽换成这次的数值），不叠加" }
		]);
		return ret;
	}

	function onAfterUpdate( _properties )
	{
		::BGP.Necro.applyCost(this, this.m.BaseAP, this.m.BaseFatigue);
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		return this.skill.onVerifyTarget(_originTile, _targetTile);
	}

	function onUse( _user, _targetTile )
	{
		local decay = ::BGP.Necro.WillScale.CurseDecay(::BGP.Necro.getWill(_user));
		local turns = 3 + ::BGP.Necro.spellDurationBonus(_user);
		local tiles = [_targetTile];
		for (local i = 0; i < 6; i++)
		{
			if (_targetTile.hasNextTile(i))
				tiles.push(_targetTile.getNextTile(i));
		}
		local hit = 0;
		foreach (tile in tiles)
		{
			if (!tile.IsOccupiedByActor)
				continue;
			local target = tile.getEntity();
			if (target == null || target.isAlliedWith(_user) || !target.isAlive() || target.isDying())
				continue;
			try
			{
				local fx = target.getSkills().getSkillByID("effects.bgp_curse_of_ages");
				if (fx != null)
					fx.refresh(decay, turns);
				else
				{
					fx = ::new("scripts/skills/effects/bgp_curse_of_ages_effect");
					fx.m.Decay = decay;
					fx.m.TurnsLeft = turns;
					target.getSkills().add(fx);
				}
				target.getSkills().update();
				target.setDirty(true);
				try { this.spawnIcon("status_effect_67", tile); } catch (e) {}
				hit++;
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 岁月诅咒施加失败: " + e);
			}
		}
		if (!_user.isHiddenToPlayer())
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "施放了岁月诅咒，" + hit + " 个敌人被诅咒");
		return true;
	}
});
