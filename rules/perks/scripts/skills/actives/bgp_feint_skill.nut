// 声东击西：在原版“换位”的基础上改成可以和 2 格内的友方野兽交换位置
this.bgp_feint_skill <- ::inherit("scripts/skills/actives/rotation", {
	m = {},
	function create()
	{
		this.rotation.create();
		this.m.ID = "actives.bgp_feint";
		this.m.Name = ::BGP.PerkNames.Feint;
		this.m.Description = "与 2 格内的友方野兽瞬间换位，趁敌人失神抢占先机。";
		this.m.Icon = "skills/bgp_feint_skill.png";
		this.m.IconDisabled = "skills/bgp_feint_skill_sw.png";
		this.m.IsSerialized = false;
		this.m.ActionPointCost = 3;
		this.m.FatigueCost = 15;
		this.m.MinRange = 1;
		this.m.MaxRange = 2;
		this.m.AIBehaviorID = null;   // 只给玩家手动用，避免 AI 当作普通换位乱用
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/vision.png", text = "与 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格内的一只友方野兽交换位置" },
			{ id = 11, type = "text", icon = "ui/icons/melee_defense.png", text = "该野兽获得防御姿态：近战防御 " + ::MSU.Text.colorPositive("+15") + "，持续到它下一次回合结束" },
			{ id = 12, type = "text", icon = "ui/icons/initiative.png", text = "你的主动值 " + ::MSU.Text.colorPositive("+30") + "，持续到你下一回合结束" }
		]);
		return ret;
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!_targetTile.IsOccupiedByActor)
			return false;
		local target = _targetTile.getEntity();
		if (!::BGP.isFriendlyBeast(target))
			return false;
		return this.rotation.onVerifyTarget(_originTile, _targetTile);
	}

	function onUse( _user, _targetTile )
	{
		local target = _targetTile.getEntity();
		local ret = this.rotation.onUse(_user, _targetTile);

		if (ret)
		{
			try
			{
				// switchEntities temporarily detaches target from its tile during the swap animation,
				// so check liveness directly instead of ::BGP.isValid (which requires isPlacedOnMap).
				if (target != null && target.isAlive() && !target.isDying())
					target.getSkills().add(::new("scripts/skills/effects/bgp_guard_stance_effect"));
				_user.getSkills().add(::new("scripts/skills/effects/bgp_feint_haste_effect"));
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 声东击西附加效果失败: " + e);
			}
		}

		return ret;
	}
});
