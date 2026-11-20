// 1.6.0 不灭冠军召唤的永恒禁卫：墓穴王禁卫
// 父类：本 mod 的复活类“受缚古代仪仗兵”（重铸 rf_skeleton_heavy_elite，古帝国荣誉卫队面板），召唤后武器换成双手巨斧
// 改显示名：改 ::BGP.Champion.GuardName（necro_champion.nut）；改模型 / 贴图：在 onInit 里父类 onInit 之后改 sprite
this.bgp_eternal_guard <- this.inherit("scripts/entity/tactical/bgp_undead/bgp_undead_rf_skeleton_heavy_elite", {
	m = {},
	function create()
	{
		this.bgp_undead_rf_skeleton_heavy_elite.create();
		this.m.BGP_MinionName = "墓穴王禁卫";
		this.m.Name = this.m.BGP_MinionName;
	}

	function onInit()
	{
		this.bgp_undead_rf_skeleton_heavy_elite.onInit();
		this.m.Name = this.m.BGP_MinionName;
	}
});
