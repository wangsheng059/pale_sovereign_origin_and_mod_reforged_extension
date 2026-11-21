this.pale_soul_chain <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "actives.pale_soul_chain";
        this.m.Name = "缚魂锁链";
        this.m.Description = "标记 6 格内生命不高于 35% 的亡灵精锐。战胜并保全遗骸后可注魂，每战限一名。";
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
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "战团持有 " + count + " 条锁链。需由首席放出冠军后使用。" });
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
        return ::PaleSovereign.markSoul(_tile.getEntity());
    }
});
