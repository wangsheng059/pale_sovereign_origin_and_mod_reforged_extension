// 毁灭横扫：毁灭一击的扇形版本（目标 + 两侧与你相邻的敌人），和单体版本共用冷却
this.bgp_devastating_sweep_skill <- ::inherit("scripts/skills/actives/bgp_devastating_blow_skill", {
	m = {},
	function create()
	{
		this.bgp_devastating_blow_skill.create();
		this.m.ID = "actives.bgp_devastating_sweep";
		this.m.Name = "毁灭横扫";
		this.m.Description = "举起双手武器蓄力横扫，同时劈向目标和两侧与你相邻的敌人，并用震荡波把主目标和它身后的敌人震退。";
		this.m.Icon = "skills/bgp_devastating_sweep_skill.png";
		this.m.IconDisabled = "skills/bgp_devastating_sweep_skill_sw.png";
		this.m.IsSweep = true;
		this.m.IsAOE = true;
	}
});
