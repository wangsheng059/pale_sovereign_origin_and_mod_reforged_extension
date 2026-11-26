// 1.5.2 亡灵特质（只在死灵宠物的特质池里）：死而复生 —— 每场一次，受到致命伤害时不死，生命回到上限的 30%
// 免死在 hooks.nut 的 MV_onBeforeDeathConfirmed 里调用 tryCheatDeath（同不灭圣徒）
this.bgp_quirk_unlife <- ::inherit("scripts/skills/skill", {
	m = {
		Pct = 0.3,
		IsSpent = false
	},
	function create()
	{
		this.m.ID = "quirk.bgp_unlife";
		this.m.Name = "死而复生";
		this.m.Description = "已经死过一次的东西，很难再死第二次。";
		this.m.Icon = "ui/perks/bgp_quirk_unlife.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.VeryLast;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = false;
	}

	function getTooltip()
	{
		local ret = [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() },
			{ id = 10, type = "text", icon = "ui/icons/health.png", text = "每场战斗一次：受到致命伤害时不死，生命回到上限的 " + ::MSU.Text.colorPositive("30%") + "，并清除所有持续伤害效果（如流血、中毒）" }
		];
		if (this.m.IsSpent)
			ret.push({ id = 11, type = "text", icon = "ui/icons/warning.png", text = ::MSU.Text.colorNegative("本场已经用过") });
		return ret;
	}

	function tryCheatDeath()
	{
		if (this.m.IsSpent)
			return false;
		local actor = this.getContainer().getActor();
		this.m.IsSpent = true;
		actor.setHitpoints(::Math.max(1, ::Math.floor(actor.getHitpointsMax() * this.m.Pct)));
		try { actor.getSkills().removeByType(::Const.SkillType.DamageOverTime); } catch (e) {}
		::BGP.log(actor, "从死亡中又爬了起来（死而复生）");
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
