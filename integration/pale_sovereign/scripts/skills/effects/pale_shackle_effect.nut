// 缚魂镣铐：常驻亡灵生命 +10、疲劳上限 +10；每场战斗首次被击倒时必定以 30% 生命站起（判定在 soulbound.nut 的 actor.kill 钩子里）
this.pale_shackle_effect <- ::inherit("scripts/skills/skill", {
    m = { Spent = false },
    function create()
    {
        this.m.ID = "effects.pale_shackle";
        this.m.Name = "缚魂镣铐";
        this.m.Description = "刻满符文的镣铐把魂火牢牢锁在这具躯壳里。";
        this.m.Icon = "skills/pale_shackle.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsStacking = false;
    }

    function isHidden()
    {
        local c = this.getContainer();
        if (c == null || ::MSU.isNull(c))
            return true;
        local actor = null;
        try { actor = c.getActor(); } catch (e) { return true; }
        return actor == null || ::MSU.isNull(actor) || !::PaleSovereign.isUndead(actor);
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/health.png", text = ::MSU.Text.colorPositive("+10") + " 生命" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/fatigue.png", text = ::MSU.Text.colorPositive("+10") + " 疲劳上限" });
        ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "每场战斗首次被击倒时，以 30% 生命站起" + (this.m.Spent ? "（本场已用过）" : "") });
        return ret;
    }

    function onUpdate( _properties )
    {
        local c = this.getContainer();
        if (c == null || ::MSU.isNull(c))
            return;
        local actor = null;
        try { actor = c.getActor(); } catch (e) { return; }
        if (actor == null || ::MSU.isNull(actor) || !::PaleSovereign.isUndead(actor))
            return;
        _properties.Hitpoints += 10;
        _properties.Stamina += 10;
    }

    function onCombatStarted()
    {
        this.m.Spent = false;
    }

    function onCombatFinished()
    {
        this.m.Spent = false;
    }
});
