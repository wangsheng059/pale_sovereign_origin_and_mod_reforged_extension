// 1.5.2 亡灵特质（只在死灵宠物的特质池里）：灵魂虹吸 —— 击杀敌人时回复 20 点生命；1.5.3 起另外回复 20 点疲劳
this.bgp_quirk_soul_siphon <- ::inherit("scripts/skills/skill", {
	m = {
		Heal = 20,
		Fatigue = 20
	},
	function create()
	{
		this.m.ID = "quirk.bgp_soul_siphon";
		this.m.Name = "灵魂虹吸";
		this.m.Description = "每夺走一条命，它就更结实一分。";
		this.m.Icon = "ui/perks/bgp_quirk_soul_siphon.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.VeryLast;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = false;
	}

	function getTooltip()
	{
		return [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() },
			{ id = 10, type = "text", icon = "ui/icons/health.png", text = "击杀敌人时回复 " + ::MSU.Text.colorPositive(this.m.Heal) + " 点生命" },
			{ id = 11, type = "text", icon = "ui/icons/fatigue.png", text = "击杀敌人时回复 " + ::MSU.Text.colorPositive(this.m.Fatigue) + " 点疲劳" }
		];
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		local actor = this.getContainer().getActor();
		if (!actor.isAlive() || _targetEntity == null || _targetEntity.isAlliedWith(actor))
			return;
		local parts = [];
		local heal = ::Math.min(this.m.Heal, actor.getHitpointsMax() - actor.getHitpoints());
		if (heal > 0)
		{
			::BGP.heal(actor, heal);
			parts.push(heal + " 点生命");
		}
		try
		{
			local fat = ::Math.min(this.m.Fatigue, actor.getFatigue());
			if (fat > 0)
			{
				actor.setFatigue(actor.getFatigue() - fat);
				actor.setDirty(true);
				parts.push(fat + " 点疲劳");
			}
		}
		catch (e)
		{
		}
		if (parts.len() == 0)
			return;
		local text = "回复了 ";
		foreach (i, p in parts)
			text += (i == 0 ? "" : "、") + p;
		::BGP.log(actor, text + "（灵魂虹吸）");
	}
});
