// 1.6.0 血肉重铸（亡灵冠军 3 层）：4 行动点、15 疲劳、5 格（不需要视野）。
// 目标：你的亡灵（你复活的仆从、你的死灵宠物、永恒禁卫）。摧毁它所在格或相邻 1 格内的一具尸体，嫁接到它身上：
//   第 1 次：骨刺外甲（+80 点独立骨甲，吸收伤害；骨甲没碎时，每次被近战攻击对攻击者造成 15 点穿刺伤害）
//   第 2 次：畸变肌腱（行动点上限 +2，每格移动 -1 行动点（最少 1），所有攻击命中头部几率 +15%）
//   1.6.2 起骨刺外甲按施放时的决心 W：骨甲 40 + W/2，反伤 5 + W/4
// 每个单位每场最多嫁接 2 次。等待自行复活的尸体、永恒禁卫的残骸不能用。
this.bgp_necro_flesh_reforge_skill <- ::inherit("scripts/skills/skill", {
	m = {
		BaseAP = 4,
		BaseFatigue = 15
	},
	function create()
	{
		this.m.ID = "actives.bgp_necro_flesh_reforge";
		this.m.Name = "血肉重铸";
		this.m.Description = "撕开一具尸体，把它的骨骼和肌腱嫁接到你的亡灵身上。";
		this.m.Icon = "skills/bgp_necro_flesh_reforge_skill.png";
		this.m.IconDisabled = "skills/bgp_necro_flesh_reforge_skill_sw.png";
		this.m.Overlay = "";
		this.m.SoundOnUse = [
			"sounds/enemies/gruesome_feast_01.wav",
			"sounds/enemies/gruesome_feast_02.wav",
			"sounds/enemies/gruesome_feast_03.wav"
		];
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.UtilityTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsTargetingActor = true;
		this.m.IsVisibleTileNeeded = false;
		this.m.IsStacking = false;
		this.m.IsAttack = false;
		this.m.IsIgnoredAsAOO = true;
		this.m.ActionPointCost = this.m.BaseAP;
		this.m.FatigueCost = this.m.BaseFatigue;
		this.m.MinRange = 1;
		this.m.MaxRange = 5;
		this.m.AIBehaviorID = null;
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		local w = ::BGP.Necro.getWill(this.getContainer().getActor());
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/vision.png", text = "目标为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格内你的亡灵（复活的单位、亡灵宠物、永恒禁卫），不需要视野；它所在格或相邻 1 格内要有一具尸体，尸体被摧毁（含即将自行爬起的尸体，不消耗待复活的永恒禁卫残骸）" },
			{ id = 11, type = "text", icon = "ui/icons/armor_body.png", text = "第 1 次嫁接 骨刺外甲：" + ::MSU.Text.colorPositive("+" + ::BGP.Necro.WillScale.BoneArmor(w)) + " 点独立骨甲（先于护甲吸收伤害）；骨甲没碎时，每次被近战攻击对攻击者造成 " + ::MSU.Text.colorPositive(::BGP.Necro.WillScale.BoneThorns(w)) + " 点穿刺伤害（无视护甲）" + ::BGP.Necro.willText(w) },
			{ id = 12, type = "text", icon = "ui/icons/action_points.png", text = "第 2 次嫁接 畸变肌腱：行动点上限 " + ::MSU.Text.colorPositive("+2") + "，每格移动行动点 " + ::MSU.Text.colorPositive("-1") + "（最少 1），所有攻击命中头部几率 " + ::MSU.Text.colorPositive("+15%") },
			{ id = 13, type = "text", icon = "ui/icons/special.png", text = "每个单位每场战斗最多嫁接 2 次" }
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
		if (!::BGP.Champion.isMyUndead(user, target))
			return false;
		if (::BGP.Champion.getNextGraft(target) == null)
			return false;
		return ::BGP.Champion.findGraftTile(_targetTile) != null;
	}

	function onUse( _user, _targetTile )
	{
		local target = _targetTile.getEntity();
		local graft = ::BGP.Champion.getNextGraft(target);
		local corpseTile = ::BGP.Champion.findGraftTile(_targetTile);
		if (graft == null || corpseTile == null)
			return false;
		try
		{
			::BGP.Necro.consumeCorpse(::BGP.Necro.getCorpse(corpseTile));
			::BGP.Necro.removeCorpse(corpseTile);
			::BGP.Necro.spawnBloodbath(corpseTile);
			local fx = ::new(graft);
			if (fx.getID() == "effects.bgp_graft_bone")
				fx.setWill(::BGP.Necro.getWill(_user));
			target.getSkills().add(fx);
			target.getSkills().update();
			target.setDirty(true);
			if (!_user.isHiddenToPlayer())
				::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "把一具尸体嫁接到" + ::Const.UI.getColorizedEntityName(target) + "身上（" + fx.getName() + "）");
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 血肉重铸失败: " + e);
			return false;
		}
		return true;
	}
});
