this.pale_soul_chain <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "actives.pale_soul_chain";
        this.m.Name = "缚魂锁链";
        this.m.Description = "甩出黑铁锁链缠住垂死的强敌，锁住它不散的魂火。只要战后遗骸尚存，便可把它的力量灌入勇士体内。";
        this.m.Icon = "skills/pale_chain.png";
        this.m.IconDisabled = "skills/pale_chain_sw.png";
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.UtilityTargeted;
        this.m.IsActive = true;
        this.m.IsTargeted = true;
        this.m.IsIgnoredAsAOO = true;
        this.m.IsSerialized = false;
        this.m.ActionPointCost = 4;
        this.m.FatigueCost = 16;
        this.m.MinRange = 1;
        this.m.MaxRange = 6;
        this.m.MaxLevelDifference = 8;
        this.m.IsVisibleTileNeeded = false;
    }

    function getTooltip()
    {
        local ret = this.getDefaultUtilityTooltip();
        local count = ::PaleSovereign.countItems("misc.pale_chain");
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "无需视野。标记 6 格内生命不高于 " + ::PaleSovereign.markThreshold() + "% 的强敌（敌阵中带有【可缚之魂】提示的目标），同时附加【锁链牵制】（无法溃逃、近战防御 −10、对导师伤害 −20%）。战胜并保全遗骸（头颅完整）后可注魂，每战限一名。" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "战团持有 " + count + " 条锁链。需由导师放出勇士后使用，完成注魂时才消耗。" });
        return ret;
    }

    function isHidden()
    {
        local s = ::PaleSovereign;
        return !s.isActive() || s.oath() != s.Oath.Champion;
    }

    function isUsable()
    {
        local s = ::PaleSovereign;
        return !this.isHidden() && this.skill.isUsable() && s.canMarkSoul();
    }

    function onVerifyTarget( _origin, _tile )
    {
        local user = this.getContainer().getActor();
        return this.skill.onVerifyTarget(_origin, _tile) && ::PaleSovereign.isEnemy(user, _tile) && ::PaleSovereign.canMarkEnemy(_tile.getEntity());
    }

    function onUse( _user, _tile )
    {
        if (!this.onVerifyTarget(_user.getTile(), _tile) || !this.isUsable())
            return false;
        local marked = ::PaleSovereign.markSoul(_tile.getEntity());
        if (marked)
            ::PaleSovereign.playBattleArt("chain", _tile, 30);
        return marked;
    }
});
