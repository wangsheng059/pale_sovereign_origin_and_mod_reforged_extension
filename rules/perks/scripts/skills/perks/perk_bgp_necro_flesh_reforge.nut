// 1.6.0 亡灵冠军 3 层：血肉重铸 —— 解锁“血肉重铸”主动技能
this.perk_bgp_necro_flesh_reforge <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_flesh_reforge";
		this.m.Name = ::BGP.PerkNames.NecroFleshReforge;
		this.m.Description = ::BGP.PerkDescriptions.NecroFleshReforge;
		this.m.Icon = "ui/perks/perk_bgp_necro_flesh_reforge.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_necro_flesh_reforge"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_necro_flesh_reforge_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_necro_flesh_reforge");
	}
});
