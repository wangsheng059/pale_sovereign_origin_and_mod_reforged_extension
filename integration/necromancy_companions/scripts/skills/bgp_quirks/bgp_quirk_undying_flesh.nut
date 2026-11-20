// 1.5.2 亡灵特质（只在死灵宠物的特质池里）：不朽之躯 —— 受到的伤害 -10%
this.bgp_quirk_undying_flesh <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "quirk.bgp_undying_flesh";
		this.m.Name = "不朽之躯";
		this.m.Description = "腐肉不会疼，也不会轻易散架。";
		this.m.Icon = "ui/perks/bgp_quirk_undying_flesh.png";
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
			{ id = 10, type = "text", icon = "ui/icons/special.png", text = "受到的伤害 " + ::MSU.Text.colorPositive("-10%") }
		];
	}

	function onUpdate( _properties )
	{
		_properties.DamageReceivedTotalMult *= 0.9;
	}
});
