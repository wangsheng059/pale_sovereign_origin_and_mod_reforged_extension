// 死灵法师“死灵法术”复活出来的亡灵：受缚血肉魔像
// 父类：scripts/entity/tactical/enemies/lesser_flesh_golem（属性、技能、AI 都沿用父类）
// 改显示名：改下面的 BGP_MinionName；改模型 / 贴图：在 onInit 里 ::BGP.Necro.onMinionInit(this) 之后改各个 sprite 的 brush
this.bgp_undead_lesser_flesh_golem <- this.inherit("scripts/entity/tactical/enemies/lesser_flesh_golem", {
	m = {
		BGP_MinionName = "受缚血肉魔像"
	},
	function create()
	{
		this.lesser_flesh_golem.create();
		::BGP.Necro.onMinionCreate(this);
	}

	function onInit()
	{
		this.lesser_flesh_golem.onInit();
		::BGP.Necro.onMinionInit(this);
	}

	function onBeforeCombatResult()
	{
		// 复活时新生成的装备不放进战利品
	}
});
