// 死灵法师“死灵法术”复活出来的亡灵：受缚僵尸
// 父类：scripts/entity/tactical/enemies/zombie_player（属性、技能、AI 都沿用父类）
// 改显示名：改下面的 BGP_MinionName；改模型 / 贴图：在 onInit 里 ::BGP.Necro.onMinionInit(this) 之后改各个 sprite 的 brush
this.bgp_undead_zombie_player <- this.inherit("scripts/entity/tactical/enemies/zombie_player", {
	m = {
		BGP_MinionName = "受缚僵尸"
	},
	function create()
	{
		this.zombie_player.create();
		::BGP.Necro.onMinionCreate(this);
	}

	function onInit()
	{
		this.zombie_player.onInit();
		::BGP.Necro.onMinionInit(this);
	}

	function onBeforeCombatResult()
	{
		// 复活时新生成的装备不放进战利品
	}
});
