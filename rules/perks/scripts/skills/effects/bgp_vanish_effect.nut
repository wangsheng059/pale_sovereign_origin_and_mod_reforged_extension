// 隐没：防御加成到下一回合开始；免疫控制区用一次（移动结束后消失）
this.bgp_vanish_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Defense = 15,
		HasDefense = true,
		HasZOC = true
	},
	function create()
	{
		this.m.ID = "effects.bgp_vanish";
		this.m.Name = ::BGP.PerkNames.Vanish;
		this.m.Icon = "ui/perks/perk_bgp_vanish.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "得手之后，人就不见了。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		if (this.m.HasDefense)
		{
			ret.push({ id = 10, type = "text", icon = "ui/icons/melee_defense.png", text = "近战防御 " + ::MSU.Text.colorPositive("+" + this.m.Defense) + "（到下一回合开始）" });
			ret.push({ id = 11, type = "text", icon = "ui/icons/ranged_defense.png", text = "远程防御 " + ::MSU.Text.colorPositive("+" + this.m.Defense) + "（到下一回合开始）" });
		}
		if (this.m.HasZOC)
			ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "下一次离开敌人控制区时不会受到借机攻击" });
		return ret;
	}

	function refresh()
	{
		this.m.HasDefense = true;
		this.m.HasZOC = true;
		this.getContainer().update();
	}

	function onRefresh()
	{
		this.m.HasDefense = true;
		this.m.HasZOC = true;
	}

	function onUpdate( _properties )
	{
		if (this.m.HasDefense)
		{
			_properties.MeleeDefense += this.m.Defense;
			_properties.RangedDefense += this.m.Defense;
		}
		if (this.m.HasZOC)
			_properties.IsImmuneToZoneOfControl = true;
	}

	function onMovementFinished( _tile )
	{
		if (this.m.HasZOC)
		{
			this.m.HasZOC = false;
			this.checkDone();
		}
	}

	function onTurnStart()
	{
		this.m.HasDefense = false;
		this.checkDone();
	}

	function checkDone()
	{
		if (!this.m.HasDefense && !this.m.HasZOC)
			this.removeSelf();
		else
			this.getContainer().update();
	}
});
