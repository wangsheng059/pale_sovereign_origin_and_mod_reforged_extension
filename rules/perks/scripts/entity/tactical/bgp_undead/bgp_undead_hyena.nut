// 死灵法师“死灵法术”复活出来的野兽：亡灵鬣狗
// 父类：scripts/entity/tactical/enemies/hyena（属性、技能、AI 都沿用父类）
// 改显示名：改下面的 BGP_MinionName；改模型 / 贴图：在 onInit 里 ::BGP.Necro.onMinionInit(this) 之后改各个 sprite 的 brush
this.bgp_undead_hyena <- this.inherit("scripts/entity/tactical/enemies/hyena", {
	m = {
		BGP_MinionName = "亡灵鬣狗"
	},
	function create()
	{
		this.hyena.create();
		::BGP.Necro.onMinionCreate(this);
	}

	function onInit()
	{
		this.hyena.onInit();
		::BGP.Necro.onMinionInit(this);
	}

	function onBeforeCombatResult()
	{
		// 复活时新生成的装备不放进战利品
	}
});
