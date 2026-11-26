// 千面归一·苦痛转嫁：狂热。每层伤害 +10%（最多 2 层，本场有效）；获得新层后的下一个回合行动点 +2
this.bgp_frenzy_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Stacks = 0,
		MaxStacks = 2,
		DamagePerStack = 0.1,
		BonusAP = 2,
		PendingAP = false,
		ApplyNow = false
	},
	function create()
	{
		this.m.ID = "effects.bgp_frenzy";
		this.m.Name = "狂热";
		this.m.Icon = "ui/perks/perk_bgp_one_flesh.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getDescription()
	{
		return "同伴的流血点燃了他的狂热。";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "伤害 " + ::MSU.Text.colorPositive("+" + ::Math.round(this.m.Stacks * this.m.DamagePerStack * 100) + "%") + "（" + this.m.Stacks + " / " + this.m.MaxStacks + " 层）" });
		if (this.m.PendingAP)
			ret.push({ id = 11, type = "text", icon = "ui/icons/action_points.png", text = "下一个回合行动点 " + ::MSU.Text.colorPositive("+" + this.m.BonusAP) });
		if (this.m.ApplyNow)
			ret.push({ id = 12, type = "text", icon = "ui/icons/action_points.png", text = "本回合行动点 " + ::MSU.Text.colorPositive("+" + this.m.BonusAP) });
		return ret;
	}

	function addStack()
	{
		this.m.Stacks = ::Math.min(this.m.MaxStacks, this.m.Stacks + 1);
		this.m.PendingAP = true;
		try { this.getContainer().getActor().setDirty(true); } catch (e) {}
	}

	function onUpdate( _properties )
	{
		_properties.DamageTotalMult *= 1.0 + this.m.DamagePerStack * this.m.Stacks;
		if (this.m.ApplyNow)
			_properties.ActionPoints += this.m.BonusAP;
	}

	function onTurnStart()
	{
		if (!this.m.PendingAP)
			return;
		this.m.PendingAP = false;
		this.m.ApplyNow = true;
		local actor = this.getContainer().getActor();
		try
		{
			this.getContainer().update();
			::BGP.restoreAP(actor, this.m.BonusAP);
		}
		catch (e)
		{
		}
	}

	function onTurnEnd()
	{
		if (this.m.ApplyNow)
		{
			this.m.ApplyNow = false;
			try { this.getContainer().getActor().setDirty(true); } catch (e) {}
		}
	}
});
