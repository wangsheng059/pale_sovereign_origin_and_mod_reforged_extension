// 死灵法术：复活死者还能复活野兽、亡灵、兽人、地精的尸体（判断在 ::BGP.Necro.getRaisePlan）
this.perk_bgp_necro_arts <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_arts";
		this.m.Name = ::BGP.PerkNames.NecroArts;
		this.m.Description = ::BGP.PerkDescriptions.NecroArts;
		this.m.Icon = "ui/perks/perk_bgp_necro_arts.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}
});
