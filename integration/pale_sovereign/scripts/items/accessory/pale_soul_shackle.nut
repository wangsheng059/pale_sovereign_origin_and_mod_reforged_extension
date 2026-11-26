// 缚魂镣铐：两条路线在营地用 1 条缚魂锁链加一种贵重品打造
this.pale_soul_shackle <- ::inherit("scripts/items/accessory/accessory", {
    m = {},

    function create()
    {
        this.accessory.create();
        this.m.ID = "accessory.pale_soul_shackle";
        this.m.Name = "缚魂镣铐";
        this.m.Description = "以缚魂锁链锻成的符文镣铐。只对常驻亡灵生效：生命 +10、疲劳值上限 +10，每场战斗首次被击倒时以 30% 生命站起。锁魂者第一次戴上时额外获得 1 个特技点（每名锁魂者限 1 次）。";
        this.m.Icon = "pale/shackle.png";
        this.m.IconLarge = this.m.Icon;
        this.m.Value = 600;
    }

    function onEquip()
    {
        this.accessory.onEquip();
        this.addSkill(::new("scripts/skills/effects/pale_shackle_effect"));
        local container = this.getContainer();
        if (container == null || ::MSU.isNull(container))
            return;
        local actor = null;
        try { actor = container.getActor(); } catch (e) { return; }
        if (actor == null || ::MSU.isNull(actor) || !::PaleSovereign.isSoulbound(actor) || actor.getFlags().has("PaleShacklePoint"))
            return;
        actor.getFlags().add("PaleShacklePoint");
        actor.m.PerkPoints += 1;
    }
});
