// 授印封将：三枚战印的公用基类。0 行动点、0 疲劳，只能在第 1 回合使用，每枚每场 1 次；
// 目标为 8 格内的一名战团成员（不能选自己，每人只能持一枚印）。效果持续整场战斗。
this.bgp_seal_skill <- ::inherit("scripts/skills/skill", {
	m = {
		EffectID = "",
		EffectScript = "",
		Lines = [],
		IsSpent = false
	},
	function create()
	{
		this.m.ID = "actives.bgp_seal_base";
		this.m.Name = "战印";
		this.m.Overlay = "";
		this.m.SoundOnUse = [];
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.UtilityTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsStacking = false;
		this.m.IsAttack = false;
		this.m.IsIgnoredAsAOO = true;
		this.m.ActionPointCost = 0;
		this.m.FatigueCost = 0;
		this.m.MinRange = 1;
		this.m.MaxRange = 8;
		this.m.AIBehaviorID = null;
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/vision.png", text = "目标为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格内的一名战团成员（不能选自己，每人只能持一枚印），持续整场战斗" });
		foreach (i, l in this.m.Lines)
			ret.push({ id = 11 + i, type = "text", icon = "ui/icons/special.png", text = l });
		ret.push({ id = 20, type = "text", icon = "ui/icons/special.png", text = "只能在第 1 回合使用，每场 1 次" + (this.m.IsSpent ? "（本场已用）" : "") });
		return ret;
	}

	function isUsable()
	{
		return !this.m.IsSpent && ::BGP.getRound() <= 1 && this.skill.isUsable();
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!_targetTile.IsOccupiedByActor)
			return false;
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		local target = _targetTile.getEntity();
		if (target.getID() == this.getContainer().getActor().getID())
			return false;
		if (target.getFaction() != ::Const.Faction.Player)
			return false;
		local s = target.getSkills();
		if (s.hasSkill("effects.bgp_seal_vanguard") || s.hasSkill("effects.bgp_seal_center") || s.hasSkill("effects.bgp_seal_shadow"))
			return false;
		return true;
	}

	function onUse( _user, _targetTile )
	{
		local target = _targetTile.getEntity();
		try
		{
			target.getSkills().add(::new(this.m.EffectScript));
			this.m.IsSpent = true;
			if (!_user.isHiddenToPlayer())
				::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "将" + this.getName() + "授予" + ::Const.UI.getColorizedEntityName(target));
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 授印失败: " + e);
		}
		return true;
	}

	function onCombatStarted()
	{
		this.m.IsSpent = false;
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.IsSpent = false;
	}
});
