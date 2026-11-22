// 缚魂镣铐：天灾在营地用 1 条缚魂锁链打造
this.pale_soul_shackle <- ::inherit("scripts/items/accessory/accessory", {
    m = {},

    function create()
    {
        this.accessory.create();
        this.m.ID = "accessory.pale_soul_shackle";
        this.m.Name = "缚魂镣铐";
        this.m.Description = "以缚魂锁链锻成的符文镣铐。只对常驻亡灵生效：生命 +10、决心 +10，每场战斗首次被击倒时有 50% 概率以 30% 生命站起。锁魂者第一次戴上时额外获得 1 个特技点（每名锁魂者限 1 次）。";
        this.m.Icon = "pale/chain_item.png";
        this.m.IconLarge = "pale/chain_item.png";
        this.m.Value = 600;
    }

    function onEquip()
    {
        this.accessory.onEquip();
        this.addSkill(::new("scripts/skills/effects/pale_shackle_effect"));
        local actor = this.getContainer().getActor();
        if (actor == null || ::MSU.isNull(actor) || !::PaleSovereign.isSoulbound(actor) || actor.getFlags().has("PaleShacklePoint"))
            return;
        actor.getFlags().add("PaleShacklePoint");
        actor.m.PerkPoints += 1;
    }
});
