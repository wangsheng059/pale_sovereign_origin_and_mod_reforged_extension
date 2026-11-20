// 1.5.2 亡灵特质（只在死灵宠物的特质池里）：腐臭 —— 自己回合开始时，相邻的每个敌人疲劳 +5
this.bgp_quirk_rot_stench <- ::inherit("scripts/skills/skill", {
	m = {
		Fatigue = 5
	},
	function create()
	{
		this.m.ID = "quirk.bgp_rot_stench";
		this.m.Name = "腐臭";
		this.m.Description = "靠近它的人都忍不住干呕。";
		this.m.Icon = "ui/perks/bgp_quirk_rot_stench.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.VeryLast;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = false;
	}

	function getTooltip()
	{
		return [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() },
			{ id = 10, type = "text", icon = "ui/icons/fatigue.png", text = "自己回合开始时，相邻的每个敌人疲劳 " + ::MSU.Text.colorPositive("+" + this.m.Fatigue) }
		];
	}

	function onTurnStart()
	{
		local actor = this.getContainer().getActor();
		if (!actor.isPlacedOnMap())
			return;
		local tile = actor.getTile();
		for (local i = 0; i < 6; i++)
		{
			if (!tile.hasNextTile(i))
				continue;
			local next = tile.getNextTile(i);
			if (!next.IsOccupiedByActor)
				continue;
			local e = next.getEntity();
			if (e == null || !e.isAlive() || e.isAlliedWith(actor))
				continue;
			try
			{
				local f = ::Math.min(e.getFatigueMax(), e.getFatigue() + this.m.Fatigue);
				e.setFatigue(f);
				e.setDirty(true);
			}
			catch (err)
			{
			}
		}
	}
});
