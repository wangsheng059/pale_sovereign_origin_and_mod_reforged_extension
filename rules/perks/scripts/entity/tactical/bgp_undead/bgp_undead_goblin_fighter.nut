// 死灵法师“死灵法术”复活出来的地精：地精散兵死灵
// 父类：scripts/entity/tactical/enemies/goblin_fighter（属性、技能、AI 都沿用父类）
// 改显示名：改下面的 BGP_MinionName；改模型 / 贴图：在 onInit 里 ::BGP.Necro.onMinionInit(this) 之后改各个 sprite 的 brush
this.bgp_undead_goblin_fighter <- this.inherit("scripts/entity/tactical/enemies/goblin_fighter", {
	m = {
		BGP_MinionName = "地精散兵死灵"
	},
	function create()
	{
		this.goblin_fighter.create();
		::BGP.Necro.onMinionCreate(this);
	}

	function onInit()
	{
		this.goblin_fighter.onInit();
		::BGP.Necro.onMinionInit(this);
	}

	function onBeforeCombatResult()
	{
		// 复活时新生成的装备不放进战利品
	}
});
