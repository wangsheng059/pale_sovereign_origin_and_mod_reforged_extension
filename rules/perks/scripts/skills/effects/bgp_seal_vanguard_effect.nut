// 先锋印·破阵者：移动疲劳 -50%；每回合首杀回复 4 行动点并让下一次移动免疫控制区；远程防御归零；持盾时失效
this.bgp_seal_vanguard_effect <- ::inherit("scripts/skills/skill", {
	m = {
		IsInactive = false,
		KillUsed = false,
		HasZOC = false
	},
	function create()
	{
		this.m.ID = "effects.bgp_seal_vanguard";
		this.m.Name = "先锋印";
		this.m.Icon = "skills/bgp_seal_vanguard_skill.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "破阵者：冲在最前，杀穿敌阵。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		if (this.m.IsInactive)
		{
			ret.push({ id = 10, type = "text", icon = "ui/tooltips/warning.png", text = ::MSU.Text.colorNegative("持盾时战印失效") });
			return ret;
		}
		ret.push({ id = 10, type = "text", icon = "ui/icons/fatigue.png", text = "移动消耗的疲劳 " + ::MSU.Text.colorPositive("-50%") });
		ret.push({ id = 11, type = "text", icon = "ui/icons/action_points.png", text = "每回合第一次击杀回复 " + ::MSU.Text.colorPositive("4") + " 行动点，下一次移动免疫控制区" + (this.m.KillUsed ? "（本回合已用）" : "") });
		if (this.m.HasZOC)
			ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = ::MSU.Text.colorPositive("破阵已激活：下一次移动免疫控制区") });
		ret.push({ id = 13, type = "text", icon = "ui/icons/ranged_defense.png", text = ::MSU.Text.colorNegative("远程防御归零") });
		return ret;
	}

	function onUpdate( _properties )
	{
		this.m.IsInactive = ::BGP.hasShield(this.getContainer().getActor());
		if (this.m.IsInactive)
			return;
		_properties.MovementFatigueCostMult *= 0.5;
		if (this.m.HasZOC)
			_properties.IsImmuneToZoneOfControl = true;
	}

	function onAfterUpdate( _properties )
	{
		if (this.m.IsInactive)
			return;
		_properties.RangedDefense = 0;
		_properties.RangedDefenseMult = 1.0;
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		if (this.m.IsInactive || this.m.KillUsed)
			return;
		local actor = this.getContainer().getActor();
		if (!::BGP.isActiveEntity(actor))
			return;
		this.m.KillUsed = true;
		this.m.HasZOC = true;
		::BGP.restoreAP(actor, 4);
		actor.setDirty(true);
		::BGP.log(actor, "破阵！回复 4 行动点");
	}

	function onMovementFinished( _tile )
	{
		if (this.m.HasZOC)
		{
			this.m.HasZOC = false;
			this.getContainer().getActor().setDirty(true);
		}
	}

	function onTurnStart()
	{
		this.m.KillUsed = false;
	}

	function onTurnEnd()
	{
		this.m.HasZOC = false;
	}
});
