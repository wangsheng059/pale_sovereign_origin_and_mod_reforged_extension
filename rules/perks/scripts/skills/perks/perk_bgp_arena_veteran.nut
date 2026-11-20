this.perk_bgp_arena_veteran <- ::inherit("scripts/skills/skill", {
	m = {
		DefensePerEnemy = 4
	},
	function create()
	{
		this.m.ID = "perk.bgp_arena_veteran";
		this.m.Name = ::BGP.PerkNames.ArenaVeteran;
		this.m.Description = ::BGP.PerkDescriptions.ArenaVeteran;
		this.m.Icon = "ui/perks/perk_bgp_arena_veteran.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function countAdjacentEnemies()
	{
		local actor = this.getContainer().getActor();
		if (!::BGP.isValid(actor))
			return 0;
		local n = 0;
		local tile = actor.getTile();
		for (local i = 0; i < 6; i++)
		{
			if (!tile.hasNextTile(i))
				continue;
			local t = tile.getNextTile(i);
			if (!t.IsOccupiedByActor)
				continue;
			local e = t.getEntity();
			if (e != null && e.isAlive() && !e.isAlliedWith(actor))
				n++;
		}
		return n;
	}

	function onUpdate( _properties )
	{
		_properties.IsImmuneToSurrounding = true;
	}

	// 被攻击的那一刻按接邻敌人数量加近战防御（站位随时在变，不放在 onUpdate 里）
	function onBeingAttacked( _attacker, _skill, _properties )
	{
		_properties.MeleeDefense += this.m.DefensePerEnemy * this.countAdjacentEnemies();
	}
});
