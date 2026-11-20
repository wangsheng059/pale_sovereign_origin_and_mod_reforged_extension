// 1.6.0 不灭号令（不灭冠军附带）：6 行动点、20 疲劳、99 格、不需要视野、没有冷却。
// 目标为自己的永恒禁卫倒下后留下的残骸（格子上不能有人），让它原地以 50% 生命、50% 护甲复活。
this.bgp_necro_eternal_command_skill <- ::inherit("scripts/skills/skill", {
	m = {
		BaseAP = 6,
		BaseFatigue = 20
	},
	function create()
	{
		this.m.ID = "actives.bgp_necro_eternal_command";
		this.m.Name = "不灭号令";
		this.m.Description = "朝倒下的禁卫残骸厉声下令：起来，继续战斗。";
		this.m.Icon = "skills/bgp_necro_eternal_command_skill.png";
		this.m.IconDisabled = "skills/bgp_necro_eternal_command_skill_sw.png";
		this.m.Overlay = "";
		this.m.SoundOnUse = [
			"sounds/enemies/necromancer_01.wav",
			"sounds/enemies/necromancer_02.wav",
			"sounds/enemies/necromancer_03.wav"
		];
		this.m.SoundVolume = 1.3;
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.UtilityTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsTargetingActor = false;
		this.m.IsVisibleTileNeeded = false;
		this.m.IsStacking = false;
		this.m.IsAttack = false;
		this.m.IsIgnoredAsAOO = true;
		this.m.ActionPointCost = this.m.BaseAP;
		this.m.FatigueCost = this.m.BaseFatigue;
		this.m.MinRange = 1;
		this.m.MaxRange = 99;
		this.m.AIBehaviorID = null;
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/vision.png", text = "技能范围为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格，不需要视野；没有冷却" },
			{ id = 11, type = "text", icon = "ui/icons/special.png", text = "目标为你的永恒禁卫倒下后留下的残骸（格子上不能有人）" },
			{ id = 12, type = "text", icon = "ui/icons/health.png", text = "禁卫原地复活，生命 " + ::MSU.Text.colorPositive("50%") + "，头甲、身甲耐久 " + ::MSU.Text.colorPositive("50%") }
		]);
		return ret;
	}

	function onAfterUpdate( _properties )
	{
		::BGP.Necro.applyCost(this, this.m.BaseAP, this.m.BaseFatigue);
	}

	function onVerifyTarget( _originTile, _targetTile )
	{
		if (!this.skill.onVerifyTarget(_originTile, _targetTile))
			return false;
		return ::BGP.Champion.canRevive(this.getContainer().getActor(), _targetTile);
	}

	function onUse( _user, _targetTile )
	{
		if (_targetTile.IsVisibleForPlayer)
		{
			try
			{
				foreach (p in ::Const.Tactical.RaiseUndeadParticles)
					::Tactical.spawnParticleEffect(true, p.Brushes, _targetTile, p.Delay, p.Quantity, p.LifeTimeQuantity, p.SpawnRate, p.Stages);
			}
			catch (e)
			{
			}
		}
		local e = null;
		try
		{
			e = ::BGP.Champion.revive(_user, _targetTile);
		}
		catch (err)
		{
			::logError("mod_bg_unique_perks: 不灭号令失败: " + err);
			e = null;
		}
		if (e != null && !_user.isHiddenToPlayer())
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "一声号令，" + ::Const.UI.getColorizedEntityName(e) + "重新站了起来");
		return e != null;
	}
});
