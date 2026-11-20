// 1.5.2 亡灵特质（只在死灵宠物的特质池里）：中毒 —— 攻击命中敌人后，敌人行动点 -2、造成的伤害 -15%，持续 2 回合。
// 敌人身上已经有这个效果时再命中不叠加、也不刷新时间；免疫中毒的敌人（亡灵等）不受影响。
this.bgp_quirk_plague <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "quirk.bgp_plague";
		this.m.Name = "中毒";
		this.m.Description = "它的爪牙和兵刃上都带着尸毒。";
		this.m.Icon = "ui/perks/bgp_quirk_plague.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.VeryLast;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = false;
		this.m.SoundOnUse = [
			"sounds/combat/poison_applied_01.wav",
			"sounds/combat/poison_applied_02.wav"
		];
	}

	function getTooltip()
	{
		return [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() },
			{ id = 10, type = "text", icon = "ui/icons/special.png", text = "攻击命中敌人后，敌人陷入“尸毒”：行动点 " + ::MSU.Text.colorNegative("-2") + "、造成的伤害 " + ::MSU.Text.colorNegative("-15%") + "，持续 " + ::MSU.Text.colorNegative("2") + " 回合" },
			{ id = 11, type = "text", icon = "ui/icons/special.png", text = "已中尸毒的敌人再被命中不叠加、不刷新；免疫中毒的敌人不受影响" }
		];
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (_targetEntity == null || !_targetEntity.isAlive() || _targetEntity.isDying() || _targetEntity.getHitpoints() <= 0)
			return;
		local actor = this.getContainer().getActor();
		if (_targetEntity.isAlliedWith(actor))
			return;
		if (_targetEntity.getCurrentProperties().IsImmuneToPoison)
			return;
		if (_targetEntity.getSkills().hasSkill("effects.bgp_undead_poison"))
			return;

		_targetEntity.getSkills().add(::new("scripts/skills/effects/bgp_undead_poison_effect"));
		if (!_targetEntity.isHiddenToPlayer())
		{
			::Sound.play(this.m.SoundOnUse[::Math.rand(0, this.m.SoundOnUse.len() - 1)], ::Const.Sound.Volume.RacialEffect * 1.5, _targetEntity.getPos());
			::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_targetEntity) + " 中了尸毒");
		}
		try { this.spawnIcon("status_effect_54", _targetEntity.getTile()); } catch (e) {}
	}
});
