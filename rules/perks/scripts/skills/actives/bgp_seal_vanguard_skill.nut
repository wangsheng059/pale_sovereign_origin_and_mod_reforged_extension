this.bgp_seal_vanguard_skill <- ::inherit("scripts/skills/actives/bgp_seal_skill", {
	m = {},
	function create()
	{
		this.bgp_seal_skill.create();
		this.m.ID = "actives.bgp_seal_vanguard";
		this.m.Name = "先锋印";
		this.m.Description = "授予破阵者的家族战印：冲在最前，杀穿敌阵。适合双手重武器。";
		this.m.Icon = "skills/bgp_seal_vanguard_skill.png";
		this.m.IconDisabled = "skills/bgp_seal_vanguard_skill_sw.png";
		this.m.EffectScript = "scripts/skills/effects/bgp_seal_vanguard_effect";
		this.m.Lines = [
			"移动消耗的疲劳 " + ::MSU.Text.colorPositive("-50%"),
			"每回合第一次击杀回复 " + ::MSU.Text.colorPositive("4") + " 行动点，且下一次移动免疫控制区",
			"代价：远程防御归零；持盾时战印失效"
		];
	}
});
