// 死灵法师“死灵法术”复活出来的亡灵：受缚古代资深老兵
// 父类：scripts/entity/tactical/enemies/rf_skeleton_medium_elite（属性、技能、AI 都沿用父类）
// 改显示名：改下面的 BGP_MinionName；改模型 / 贴图：在 onInit 里 ::BGP.Necro.onMinionInit(this) 之后改各个 sprite 的 brush
this.bgp_undead_rf_skeleton_medium_elite <- this.inherit("scripts/entity/tactical/enemies/rf_skeleton_medium_elite", {
	m = {
		BGP_MinionName = "受缚古代资深老兵"
	},
	function create()
	{
		this.rf_skeleton_medium_elite.create();
		::BGP.Necro.onMinionCreate(this);
	}

	function onInit()
	{
		this.rf_skeleton_medium_elite.onInit();
		::BGP.Necro.onMinionInit(this);
	}

	function onBeforeCombatResult()
	{
		// 复活时新生成的装备不放进战利品
	}
});
