this.bgp_seal_center_skill <- ::inherit("scripts/skills/actives/bgp_seal_skill", {
	m = {},
	function create()
	{
		this.bgp_seal_skill.create();
		this.m.ID = "actives.bgp_seal_center";
		this.m.Name = "中军印";
		this.m.Description = "授予磐石卫的家族战印：立于阵中，护住两翼。适合持盾抗线的前排。";
		this.m.Icon = "skills/bgp_seal_center_skill.png";
		this.m.IconDisabled = "skills/bgp_seal_center_skill_sw.png";
		this.m.EffectScript = "scripts/skills/effects/bgp_seal_center_effect";
		this.m.Lines = [
			"相邻其他战团成员（不含另一枚中军印与野兽/召唤物）受到伤害 " + ::MSU.Text.colorPositive("-20%"),
			"自身受到伤害 " + ::MSU.Text.colorPositive("-10%"),
			"敌人更倾向于攻击他（吸引敌方注意 ×2）"
		];
	}
});
