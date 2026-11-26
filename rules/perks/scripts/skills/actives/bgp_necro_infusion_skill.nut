// 死灵灌注：4 行动点、12 疲劳，8 格内一名友方亡灵立刻回复生命、减少疲劳，行动点数 +4 持续 2 回合
// 1.6.2 起回复量按施放时的决心 W：生命 10 + W/4、疲劳 10 + W/6（1.4.0~1.6.1 固定 20 / 15）
this.bgp_necro_infusion_skill <- ::inherit("scripts/skills/skill", {
	m = {
		BaseAP = 4,
		BaseFatigue = 12,
		Heal = 10,
		FatigueRestore = 10
	},
	function create()
	{
		this.m.ID = "actives.bgp_necro_infusion";
		this.m.Name = "冥府活力";
		this.m.Description = "把冥府的阴冷死气灌进一具亡灵的躯体，修补伤势、驱散僵硬，大幅提升它的行动能力与机动性。";
		this.m.Icon = "skills/bgp_necro_infusion_skill.png";
		this.m.IconDisabled = "skills/bgp_necro_infusion_skill_sw.png";
		this.m.Overlay = "";
		this.m.SoundOnUse = [
			"sounds/enemies/necromancer_01.wav",
			"sounds/enemies/necromancer_02.wav",
			"sounds/enemies/necromancer_03.wav"
		];
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.UtilityTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsVisibleTileNeeded = false;
		this.m.IsStacking = false;
		this.m.IsAttack = false;
		this.m.IsIgnoredAsAOO = true;
		this.m.ActionPointCost = this.m.BaseAP;
		this.m.FatigueCost = this.m.BaseFatigue;
		this.m.MinRange = 1;
		this.m.MaxRange = 8;
		this.m.AIBehaviorID = null;
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		local w = ::BGP.Necro.getWill(this.getContainer().getActor());
		local turns = 2 + ::BGP.Necro.spellDurationBonus(this.getContainer().getActor());
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/vision.png", text = "目标为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格内的一名友方亡灵（不需要视野）" },
			{ id = 11, type = "text", icon = "ui/icons/health.png", text = "立刻回复 " + ::MSU.Text.colorPositive(::BGP.Necro.WillScale.InfusionHeal(w)) + " 点生命" + ::BGP.Necro.willText(w) },
			{ id = 12, type = "text", icon = "ui/icons/fatigue.png", text = "立刻减少 " + ::MSU.Text.colorPositive(::BGP.Necro.WillScale.InfusionFatigue(w)) + " 点疲劳" + ::BGP.Necro.willText(w) },
			{ id = 13, type = "text", icon = "ui/icons/action_points.png", text = "在接下来的 " + ::MSU.Text.colorPositive(turns) + " 个回合里，行动点数 " + ::MSU.Text.colorPositive("+4") + "、主动值 " + ::MSU.Text.colorPositive("+75") + "、移动时行动点消耗 " + ::MSU.Text.colorPositive("-1") + "（最少 1；再次施放会刷新持续时间，不叠加）" }
		]);
		return ret;
	}

	function onAfterUpdate( _properties )
	{
		::BGP.Necro.applyCost(this, this.m.BaseAP, this.m.BaseFatigue);
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!_targetTile.IsOccupiedByActor)
			return false;
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		local target = _targetTile.getEntity();
		local user = this.getContainer().getActor();
		if (target.getID() == user.getID() || !target.isAlliedWith(user))
			return false;
		return target.getFlags().has("undead");
	}

	function onUse( _user, _targetTile )
	{
		local target = _targetTile.getEntity();
		try
		{
			local w = ::BGP.Necro.getWill(_user);
			local turns = 2 + ::BGP.Necro.spellDurationBonus(_user);
			::BGP.heal(target, ::BGP.Necro.WillScale.InfusionHeal(w));
			::BGP.reduceFatigue(target, ::BGP.Necro.WillScale.InfusionFatigue(w));
			local fx = target.getSkills().getSkillByID("effects.bgp_necro_infusion");
			if (fx != null)
				fx.refresh(turns);
			else
			{
				fx = ::new("scripts/skills/effects/bgp_necro_infusion_effect");
				fx.m.TurnsLeft = turns;
				target.getSkills().add(fx);
			}
			target.getSkills().update();
			target.setDirty(true);
			if (!_user.isHiddenToPlayer())
				::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "对" + ::Const.UI.getColorizedEntityName(target) + "施放了冥府活力");
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 冥府活力失败: " + e);
		}
		return true;
	}
});
