// 兽群领袖：加成和士气保护都在野兽身上的 effects.bgp_beast_link 里计算，这里只负责给野兽挂上联动效果
this.perk_bgp_pack_leader <- ::inherit("scripts/skills/skill", {
	m = {
		Radius = 4,
		Ratio = 0.1
	},
	function create()
	{
		this.m.ID = "perk.bgp_pack_leader";
		this.m.Name = ::BGP.PerkNames.PackLeader;
		this.m.Description = ::BGP.PerkDescriptions.PackLeader;
		this.m.Icon = "ui/perks/perk_bgp_pack_leader.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onCombatStarted()
	{
		::BGP.ensureBeastLinks();
	}

	function onNewRound()
	{
		::BGP.ensureBeastLinks();
	}

	function onTurnStart()
	{
		::BGP.ensureBeastLinks();
	}

	function onAnySkillExecuted( _skill, _targetTile, _targetEntity, _forFree )
	{
		// 放出宠物之后马上挂上
		::BGP.ensureBeastLinks();
	}

	function onMovementFinished( _tile )
	{
		// 驯兽师移动后让周围野兽重新计算加成
		foreach (b in ::BGP.getFriendlyBeasts())
		{
			try { b.getSkills().update(); } catch (e) {}
		}
	}
});
