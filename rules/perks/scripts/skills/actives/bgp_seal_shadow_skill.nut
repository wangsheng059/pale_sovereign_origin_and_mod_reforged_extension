this.bgp_seal_shadow_skill <- ::inherit("scripts/skills/actives/bgp_seal_skill", {
	m = {},
	function create()
	{
		this.bgp_seal_skill.create();
		this.m.ID = "actives.bgp_seal_shadow";
		this.m.Name = "奇兵印";
		this.m.Description = "授予暗影刺的家族战印：出其不意，一击即走。适合弓弩手、投掷手和刺客。";
		this.m.Icon = "skills/bgp_seal_shadow_skill.png";
		this.m.IconDisabled = "skills/bgp_seal_shadow_skill_sw.png";
		this.m.EffectScript = "scripts/skills/effects/bgp_seal_shadow_effect";
		this.m.Lines = [
			"攻击本场还没攻击过他的敌人时：穿甲伤害比例 " + ::MSU.Text.colorPositive("+20%") + "，近战攻击无视目标盾牌的近战防御",
			"击杀后直到他下一回合开始，敌人不太会把他当作目标（吸引敌方注意 ×0.3）"
		];
	}
});
