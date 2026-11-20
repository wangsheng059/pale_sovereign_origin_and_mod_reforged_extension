this.perk_bgp_iron_orders <- ::inherit("scripts/skills/skill", {
	m = {
		Radius = 4,
		IsPending = false
	},
	function create()
	{
		this.m.ID = "perk.bgp_iron_orders";
		this.m.Name = ::BGP.PerkNames.IronOrders;
		this.m.Description = ::BGP.PerkDescriptions.IronOrders;
		this.m.Icon = "ui/perks/perk_bgp_iron_orders.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function issueOrders()
	{
		local actor = this.getContainer().getActor();
		if (!::BGP.isValid(actor))
			return false;

		foreach (a in ::BGP.getAllActors())
		{
			if (!::BGP.isValid(a))
				continue;
			try
			{
				if (a.getFaction() != ::Const.Faction.Player || ::BGP.distance(a, actor) > this.m.Radius)
					continue;
				a.getSkills().add(::new("scripts/skills/effects/bgp_iron_orders_effect"));
			}
			catch (e)
			{
			}
		}
		::BGP.log(actor, "下达了军令");
		return true;
	}

	function onCombatStarted()
	{
		// 部署完成前可能还没上地图，那就等到第一回合开始
		this.m.IsPending = !this.issueOrders();
	}

	function onNewRound()
	{
		if (this.m.IsPending)
			this.m.IsPending = !this.issueOrders();
	}

	function onTurnStart()
	{
		if (this.m.IsPending)
			this.m.IsPending = !this.issueOrders();
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.IsPending = false;
	}
});
