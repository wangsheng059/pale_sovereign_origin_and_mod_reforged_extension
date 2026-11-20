// 复活死者：死灵法师背景自带（数值照 Nectomancy：3 行动点、10 疲劳、99 格，同时存在数量不限）
// 基础只能复活人类尸体（原版规则，变成僵尸，可以复活阵亡的战团成员）；
// 死灵法师背景（1.6.0 起，原“死灵法术”特技）还能复活野兽、亡灵、兽人、哥布林（生成本 mod 单独的类）。
// 复活出来的单位是战团的野兽阵营（AI 控制，不能操作）。
this.bgp_necro_raise_skill <- ::inherit("scripts/skills/skill", {
	m = {
		BaseAP = 3,
		BaseFatigue = 10
	},
	function create()
	{
		this.m.ID = "actives.bgp_necro_raise";
		this.m.Name = "复活死者";
		this.m.Description = "以死灵法术唤起一具尸体，让它为你而战。复活的单位听从自己的本能行动，不能直接操控。";
		this.m.Icon = "skills/bgp_necro_raise_skill.png";
		this.m.IconDisabled = "skills/bgp_necro_raise_skill_sw.png";
		this.m.Overlay = "";
		this.m.SoundOnUse = [
			"sounds/enemies/necromancer_01.wav",
			"sounds/enemies/necromancer_02.wav",
			"sounds/enemies/necromancer_03.wav"
		];
		this.m.SoundVolume = 1.2;
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
		ret.push({ id = 10, type = "text", icon = "ui/icons/vision.png", text = "技能范围为 " + ::MSU.Text.colorPositive(this.getMaxRange()) + " 格，不需要视野" });
		ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "目标为空地上的一具尸体；人类尸体变成僵尸（包括阵亡的战团成员；斩首、砸碎头部的尸体不行）" });
		if (::BGP.Necro.canRaiseAll(this.getContainer().getActor()))
			ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "还能复活野兽、亡灵、兽人、地精的尸体" });
		else
			ret.push({ id = 12, type = "text", icon = "ui/icons/warning.png", text = "野兽、亡灵、兽人、地精的尸体只有死灵法师能复活" });
		ret.push({ id = 13, type = "text", icon = "ui/icons/special.png", text = "复活的单位是友军，但由 AI 控制，不能直接操控；同时存在的数量没有上限" });
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
		if (!_targetTile.IsEmpty)
			return false;
		local corpse = ::BGP.Necro.getCorpse(_targetTile);
		if (corpse == null)
			return false;
		return ::BGP.Necro.getRaisePlan(this.getContainer().getActor(), corpse) != null;
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
			e = ::BGP.Necro.raise(_user, _targetTile);
		}
		catch (err)
		{
			::logError("mod_bg_unique_perks: 复活死者失败: " + err);
			e = null;
		}

		if (e != null && !_user.isHiddenToPlayer())
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + "复活了" + ::Const.UI.getColorizedEntityName(e));
		return e != null;
	}
});
