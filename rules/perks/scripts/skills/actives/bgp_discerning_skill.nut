// 识骨相人：审视 4 格内一名战团成员，按其天赋星级最高的属性给予整场战斗的战术指令
// 每场最多 3 人、每人 1 次；3 行动点、8 疲劳
this.bgp_discerning_skill <- ::inherit("scripts/skills/skill", {
	m = {
		MaxTargets = 3,
		Used = []
	},
	function create()
	{
		this.m.ID = "actives.bgp_discerning";
		this.m.Name = ::BGP.PerkNames.Discerning;
		this.m.Description = "审视一名战团成员的骨相与禀赋，按他天赋星级最高的属性下达专属战术指令，持续整场战斗。";
		this.m.Icon = "skills/bgp_discerning_skill.png";
		this.m.IconDisabled = "skills/bgp_discerning_skill_sw.png";
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
		this.m.ActionPointCost = 3;
		this.m.FatigueCost = 8;
		this.m.MinRange = 1;
		this.m.MaxRange = 4;
		this.m.AIBehaviorID = null;
		this.m.Used = [];
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/vision.png", text = "目标为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格内的一名战团成员（不能选自己）" },
			{ id = 11, type = "text", icon = "ui/icons/special.png", text = "生命 / 疲劳星级最高：" + ::MSU.Text.colorPositive("苦行之躯") + "，技能疲劳消耗 -30%；达库尔信徒每阶受到伤害 -2%（最多 -12%）" },
			{ id = 12, type = "text", icon = "ui/icons/special.png", text = "主动 / 远程技能 / 远程防御星级最高：" + ::MSU.Text.colorPositive("无声巡猎") + "，免疫控制区，穿甲伤害比例 +15%" },
			{ id = 13, type = "text", icon = "ui/icons/special.png", text = "近战技能 / 近战防御 / 决心星级最高：" + ::MSU.Text.colorPositive("血祭处决") + "，攻击时相邻敌人每比相邻友军多 1 名伤害 +8%（最多 +24%）；达库尔信徒造成生命伤害的 15% 回复自身生命" },
			{ id = 14, type = "text", icon = "ui/icons/special.png", text = "星级并列时取基础数值相对更突出的一项。效果持续整场战斗。本场已用 " + this.m.Used.len() + " / " + this.m.MaxTargets + " 次，每人只能被审视一次" }
		]);
		return ret;
	}

	function isUsable()
	{
		return this.m.Used.len() < this.m.MaxTargets && this.skill.isUsable();
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!_targetTile.IsOccupiedByActor)
			return false;
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		local target = _targetTile.getEntity();
		local user = this.getContainer().getActor();
		if (target.getID() == user.getID())
			return false;
		if (target.getFaction() != ::Const.Faction.Player)
			return false;
		if (this.m.Used.find(target.getID()) != null || target.getSkills().hasSkill("effects.bgp_vessel"))
			return false;
		if (::BGP.getTopTalent(target) == null)
			return false;
		return true;
	}

	function onUse( _user, _targetTile )
	{
		local target = _targetTile.getEntity();
		try
		{
			local top = ::BGP.getTopTalent(target);
			local kind = top == null ? 2 : ::BGP.AttrInfo[top.Attr].Kind;
			local fx = ::new("scripts/skills/effects/bgp_vessel_effect");
			fx.setKind(kind);
			target.getSkills().add(fx);
			this.m.Used.push(target.getID());
			if (!_user.isHiddenToPlayer())
				::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "审视了" + ::Const.UI.getColorizedEntityName(target) + "：" + fx.getKindName());
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 识骨相人失败: " + e);
		}
		return true;
	}

	function onCombatStarted()
	{
		this.m.Used = [];
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.Used = [];
	}
});
