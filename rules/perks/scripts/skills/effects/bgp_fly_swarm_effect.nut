// 1.6.1 腐毒蝇群（亡灵天灾 5 层）挂在活体敌人身上的效果：
//   每有 1 只相邻的“召唤亡灵”（主人有腐毒蝇群的死灵仆从，含死灵宠物和永恒禁卫），近战技能、近战防御、决心各 -3；
//   处在召唤亡灵的控制区内（相邻且它没被击晕）时，每次攻击、每次开始移动额外 +4 疲劳。
// 没有相邻的召唤亡灵时效果隐藏、不生效。效果由特技在开战 / 每轮 / 死灵法师回合开始时挂到敌人身上（::BGP.Necro.spreadFlySwarm）。
this.bgp_fly_swarm_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Count = 0,
		PerMinion = 3,
		Fatigue = 4
	},
	function create()
	{
		this.m.ID = "effects.bgp_fly_swarm";
		this.m.Name = "腐毒蝇群";
		this.m.Description = "成群的腐蝇从亡灵身上涌出，钻进眼睛、口鼻和甲缝。";
		this.m.Icon = "ui/perks/perk_bgp_necro_fly_swarm.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = true;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		local d = this.m.Count * this.m.PerMinion;
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/special.png", text = "相邻的召唤亡灵：" + this.m.Count + " 只" },
			{ id = 11, type = "text", icon = "ui/icons/melee_skill.png", text = ::MSU.Text.colorNegative("-" + d) + " 近战技能" },
			{ id = 12, type = "text", icon = "ui/icons/melee_defense.png", text = ::MSU.Text.colorNegative("-" + d) + " 近战防御" },
			{ id = 13, type = "text", icon = "ui/icons/bravery.png", text = ::MSU.Text.colorNegative("-" + d) + " 决心" },
			{ id = 14, type = "text", icon = "ui/icons/fatigue.png", text = "每次攻击、每次移动额外 " + ::MSU.Text.colorNegative("+" + this.m.Fatigue) + " 疲劳" }
		]);
		return ret;
	}

	// _zocOnly：只算施加控制区的（没被击晕）
	function countMinions( _zocOnly )
	{
		local n = 0;
		try
		{
			local actor = this.getContainer().getActor();
			if (!actor.isPlacedOnMap() || !actor.isAlive())
				return 0;
			local tile = actor.getTile();
			for (local i = 0; i < 6; i++)
			{
				if (!tile.hasNextTile(i))
					continue;
				local t = tile.getNextTile(i);
				if (!t.IsOccupiedByActor)
					continue;
				local e = t.getEntity();
				if (e == null || !::BGP.Necro.isFlySwarmMinion(e) || e.isAlliedWith(actor))
					continue;
				if (_zocOnly)
				{
					try
					{
						if (e.getCurrentProperties().IsStunned)
							continue;
					}
					catch (err)
					{
					}
				}
				n++;
			}
		}
		catch (e)
		{
		}
		return n;
	}

	function addFatigue()
	{
		local actor = this.getContainer().getActor();
		try
		{
			actor.setFatigue(::Math.min(actor.getFatigueMax(), actor.getFatigue() + this.m.Fatigue));
			actor.setDirty(true);
		}
		catch (e)
		{
		}
	}

	function onUpdate( _properties )
	{
		this.m.Count = this.countMinions(false);
		this.m.IsHidden = this.m.Count == 0;
		if (this.m.Count == 0)
			return;
		local d = this.m.Count * this.m.PerMinion;
		_properties.MeleeSkill -= d;
		_properties.MeleeDefense -= d;
		_properties.Bravery -= d;
	}

	function onBeforeAnySkillExecuted( _skill, _targetTile, _targetEntity, _forFree )
	{
		if (_skill == null || !_skill.isAttack())
			return;
		if (this.countMinions(true) > 0)
			this.addFatigue();
	}

	function onMovementStarted( _tile, _numTiles )
	{
		if (this.countMinions(true) > 0)
			this.addFatigue();
	}
});
