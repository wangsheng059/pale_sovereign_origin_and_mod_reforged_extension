// 1.6.0 血肉重铸第 2 次嫁接：畸变肌腱 —— 行动点上限 +2，每格移动 -1 行动点（最少 1），所有攻击命中头部几率 +15%
// 移动消耗直接改单位的 ActionPointCosts（同探路者的做法），只减大于 1 的项，效果移除时还原
this.bgp_graft_tendon_effect <- ::inherit("scripts/skills/skill", {
	m = {
		SavedCosts = null
	},
	function create()
	{
		this.m.ID = "effects.bgp_graft_tendon";
		this.m.Name = "畸变肌腱";
		this.m.Description = "多出来的肌腱缠在关节上，让这具躯体快得不自然。";
		this.m.Icon = "skills/bgp_necro_flesh_reforge_skill.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/action_points.png", text = "行动点上限 " + ::MSU.Text.colorPositive("+2") },
			{ id = 11, type = "text", icon = "ui/icons/action_points.png", text = "每格移动行动点 " + ::MSU.Text.colorPositive("-1") + "（最少 1）" },
			{ id = 12, type = "text", icon = "ui/icons/chance_to_hit_head.png", text = "所有攻击命中头部几率 " + ::MSU.Text.colorPositive("+15%") }
		]);
		return ret;
	}

	function onAdded()
	{
		try
		{
			local actor = this.getContainer().getActor();
			this.m.SavedCosts = clone actor.m.ActionPointCosts;
			local costs = clone actor.m.ActionPointCosts;
			foreach (i, c in costs)
			{
				if (c > 1)
					costs[i] = c - 1;
			}
			actor.m.ActionPointCosts = costs;
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 畸变肌腱移动消耗修改失败: " + e);
		}
	}

	function onRemoved()
	{
		try
		{
			if (this.m.SavedCosts != null)
				this.getContainer().getActor().m.ActionPointCosts = this.m.SavedCosts;
		}
		catch (e)
		{
		}
	}

	function onUpdate( _properties )
	{
		_properties.ActionPoints += 2;
		_properties.HitChance[::Const.BodyPart.Head] += 15;
	}
});
