// 1.7.0 急救骨髓膏的使用技能（音效沿用“包扎队友”）
this.pale_marrow_paste_skill <- ::inherit("scripts/skills/actives/bandage_ally_skill", {
    m = { HealPct = 0.25 },
    function create()
    {
        this.bandage_ally_skill.create();
        this.m.ID = "actives.pale_marrow_paste";
        this.m.Name = "敷骨髓膏";
        this.m.Icon = "skills/pale_marrow_paste.png";
        this.m.IconDisabled = "skills/pale_marrow_paste_sw.png";
        this.m.Overlay = "";
        this.m.Description = "把急救骨髓膏抹进相邻常驻亡灵或勇士的裂口，恢复它的躯体。";
        this.m.ActionPointCost = 4;
        this.m.FatigueCost = 10;
        this.m.MinRange = 1;
        this.m.MaxRange = 1;
        this.m.IsSerialized = false;
    }

    function getTooltip()
    {
        local ret = this.getDefaultUtilityTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/health.png", text = "相邻的常驻亡灵或勇士恢复 " + ::Math.floor(this.getHealPct() * 100) + "% 最大生命，并清除流血、酸液、燃烧" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "使用后消耗这罐骨髓膏" });
        return ret;
    }

    function getHealPct()
    {
        local actor = this.getContainer().getActor();
        return this.m.HealPct * (::PaleSovereign.isNecroHandler(actor) ? 1.25 : 1.0);
    }

    function onAfterUpdate( _properties )
    {
        this.m.ActionPointCost = ::PaleSovereign.isNecroHandler(this.getContainer().getActor()) ? 3 : 4;
    }

    function isPaleTarget( _actor )
    {
        local S = ::PaleSovereign;
        return _actor != null && _actor.isAlive() && (S.isUndead(_actor) || S.isChampionActor(_actor));
    }

    function onVerifyTarget( _originTile, _targetTile )
    {
        if (!_targetTile.IsOccupiedByActor)
            return false;
        local target = _targetTile.getEntity();
        return target.isAlliedWith(this.getContainer().getActor()) && this.isPaleTarget(target);
    }

    function onUse( _user, _targetTile )
    {
        local target = _targetTile.getEntity();
        if (!this.isPaleTarget(target))
            return false;
        local heal = ::Math.max(1, ::Math.floor(target.getHitpointsMax() * this.getHealPct()));
        target.setHitpoints(::Math.min(target.getHitpointsMax(), target.getHitpoints() + heal));
        foreach (skill in clone target.getSkills().m.Skills)
        {
            if (skill.isGarbage())
                continue;
            local id = skill.getID();
            if (id.find("effects.") == 0 && (id.find("bleed") != null || id.find("acid") != null || id.find("burn") != null))
                skill.removeSelf();
        }
        target.getSkills().update();
        target.setDirty(true);
        ::PaleSovereign.playActorArt("marrow", target, 24, 0.95);
        if (!_user.isHiddenToPlayer())
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " 给 " + ::Const.UI.getColorizedEntityName(target) + " 敷上骨髓膏，恢复 " + heal + " 点生命");
        local item = this.m.Item;
        if (!::MSU.isNull(item))
        {
            if (typeof item == "instance")
                item = item.get();
            if (item.getContainer() != null)
                item.getContainer().removeFromBag(item);
        }
        return true;
    }
});
