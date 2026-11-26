// 1.7.4 冠军路线：敌阵里可被缚魂锁链标记的强敌带这个提示状态（纯提示，不改属性）；被锚定后移除
this.pale_soul_elite_effect <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "effects.pale_soul_elite";
        this.m.Name = "可缚之魂";
        this.m.Icon = "skills/pale_mark_bound.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getDescription()
    {
        local S = ::PaleSovereign;
        local text = "这名强敌的魂火足够炽烈，可以被黑铁缚魂锁链锚定。等它的生命不高于 " + S.markThreshold()
            + "% 时，让导师对它使用「缚魂锁链」（需已放出勇士并持有锁链，每场限锚定一名）。战胜并保全遗骸（头颅完整）后，可以把它的灵魂注入勇士。";
        local actor = this.getContainer().getActor();
        local species = S.soulSpecies(::IO.scriptFilenameByHash(actor.ClassNameHash));
        if (species > 0 && species < S.Souls.len())
            text += "\n\n吞魂可得：【" + S.Souls[species].Name + "】" + S.Souls[species].Desc;
        local inherit = S.inheritPreview(actor);
        text += "\n承誓可得：" + (inherit == "" ? "无（没有可继承的冠军加成或具名武器，战后不会出现承誓选项）" : inherit);
        if (S.Battle != null && S.Battle.Mark != null)
            text += "\n\n本场已经锚定了另一名强敌。";
        else if (S.countItems("misc.pale_chain") == 0)
            text += "\n\n战团现在没有缚魂锁链。";
        return text;
    }
});
