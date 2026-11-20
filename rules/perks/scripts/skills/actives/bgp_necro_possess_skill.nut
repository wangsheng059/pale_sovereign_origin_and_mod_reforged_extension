// 支配亡灵（死灵法师用）：沿用原版 / 重铸的“支配亡灵”（3 行动点、10 疲劳、99 格，效果和提示都是原版 + 重铸的），
// 只改目标判断：友方、带 undead 旗标的单位（原版亡灵，以及死灵法术复活的所有单位和死灵宠物；1.5.1 起不再限人形），
// 并接上死灵精通的减耗。
// 1.6.2 被支配者的近战技能 +W/5、受到伤害 -(W/4 - 5)%（0~30%），W = 施放时的决心（见 necro_hooks.nut）。
this.bgp_necro_possess_skill <- ::inherit("scripts/skills/actives/possess_undead_skill", {
	m = {
		BaseAP = 3,
		BaseFatigue = 10
	},
	function create()
	{
		this.possess_undead_skill.create();
		this.m.Icon = "ui/perks/perk_bgp_necro_possess.png";
		this.m.IconDisabled = "ui/perks/perk_bgp_necro_possess_sw.png";
		this.m.BaseAP = this.m.ActionPointCost;
		this.m.BaseFatigue = this.m.FatigueCost;
		this.m.IsSerialized = false;
		this.m.AIBehaviorID = null;
		this.m.Description = "把意志灌进一个友方亡灵，让它获得巨额加成！";
	}

	function getTooltip()
	{
		local ret = this.possess_undead_skill.getTooltip();
		local w = ::BGP.Necro.getWill(this.getContainer().getActor());
		ret.push({ id = 12, type = "text", icon = "ui/icons/bravery.png", text = "被支配者 近战技能 " + ::MSU.Text.colorPositive("+" + ::BGP.Necro.WillScale.PossessMeleeSkill(w)) + "、受到的伤害 " + ::MSU.Text.colorPositive("-" + ::Math.round(::BGP.Necro.WillScale.PossessReduction(w)) + "%") + ::BGP.Necro.willText(w) + "，代替原来的 +15 和 -25%" });
		return ret;
	}

	function onUse( _user, _targetTile )
	{
		local w = ::BGP.Necro.getWill(_user);
		local target = _targetTile.getEntity();
		local ret = this.possess_undead_skill.onUse(_user, _targetTile);
		try
		{
			local fx = target.getSkills().getSkillByID("effects.possessed_undead");
			if (fx != null)
			{
				fx.m.BGP_Will = w;
				target.getSkills().update();
				target.setDirty(true);
			}
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 支配亡灵决心加成失败: " + e);
		}
		return ret;
	}

	function onAfterUpdate( _properties )
	{
		::BGP.Necro.applyCost(this, this.m.BaseAP, this.m.BaseFatigue);
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!_targetTile.IsOccupiedByActor)
			return false;
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		local target = _targetTile.getEntity();
		local user = this.getContainer().getActor();
		if (target.getID() == user.getID() || !target.isAlliedWith(user))
			return false;
		if (!target.getFlags().has("undead"))
			return false;
		if (target.getSkills().hasSkill("effects.possessed_undead"))
			return false;
		return true;
	}
});
