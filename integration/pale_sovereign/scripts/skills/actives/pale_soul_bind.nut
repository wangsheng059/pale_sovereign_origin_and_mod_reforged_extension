// 锁魂复生：亡灵天灾导师消耗 1 条缚魂锁链复活一具亡灵强敌的尸体，每场 1 次；存活到胜利即可在战后收编
this.pale_soul_bind <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "actives.pale_soul_bind";
        this.m.Name = "锁魂复生";
        this.m.Description = "将缚魂锁链缠上一具亡灵强敌的残骸，把它连同生前的力量一起拽回战场。若它撑到胜利，锁链便不会松开。";
        this.m.Icon = "skills/pale_soul_bind.png";
        this.m.IconDisabled = "skills/pale_soul_bind_sw.png";
        this.m.Overlay = "";
        this.m.SoundOnUse = ["sounds/enemies/necromancer_01.wav", "sounds/enemies/necromancer_02.wav", "sounds/enemies/necromancer_03.wav"];
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
        this.m.ActionPointCost = 4;
        this.m.FatigueCost = 20;
        this.m.MinRange = 1;
        this.m.MaxRange = 99;
    }

    function getTooltip()
    {
        local s = ::PaleSovereign;
        local ret = this.skill.getDefaultUtilityTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "目标为亡灵强敌的尸体（古帝军团、堕落骑士、墓穴恶鬼、禁咒师、血族）。复活后保留生前的精英属性，冠军仍是冠军" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "消耗 1 条缚魂锁链，每场战斗限 1 次。它活到战斗胜利，战后即可收编为锁魂者" });
        ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "战团还有 " + s.countItems("misc.pale_chain") + " 条缚魂锁链" });
        if (s.Battle != null && s.Battle.SoulUsed)
            ret.push({ id = 13, type = "text", icon = "ui/icons/warning.png", text = "本场已经使用过" });
        return ret;
    }

    function isHidden()
    {
        local s = ::PaleSovereign;
        return !s.isActive() || s.oath() != s.Oath.Scourge || !s.isChief(this.getContainer().getActor());
    }

    function isUsable()
    {
        local s = ::PaleSovereign;
        return !this.isHidden() && s.Battle != null && !s.Battle.SoulUsed && s.countItems("misc.pale_chain") > 0 && this.skill.isUsable();
    }

    function onVerifyTarget( _originTile, _targetTile )
    {
        if (!this.skill.onVerifyTarget(_originTile, _targetTile) || !_targetTile.IsEmpty)
            return false;
        local corpse = ::BGP.Necro.getCorpse(_targetTile);
        return corpse != null && ::PaleSovereign.soulClassOfCorpse(corpse) != null
            && ::BGP.Necro.getRaisePlan(this.getContainer().getActor(), corpse) != null;
    }

    function onUse( _user, _targetTile )
    {
        local s = ::PaleSovereign;
        if (!this.isUsable())
            return false;
        local corpse = ::BGP.Necro.getCorpse(_targetTile);
        local soulClass = s.soulClassOfCorpse(corpse);
        local info = ::BGP.Necro.getInfo(corpse);
        if (soulClass == null)
            return false;
        local entity = null;
        try
        {
            entity = ::BGP.Necro.raise(_user, _targetTile);
        }
        catch (err)
        {
            ::logError("Pale Sovereign: soul bind raise failed: " + err);
            entity = null;
        }
        if (entity == null)
            return false;
        s.takeItems("misc.pale_chain", 1);
        s.bindSoul(entity, soulClass, info);
        s.playBattleArt("resurrect", _targetTile, 28);
        if (!_user.isHiddenToPlayer())
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " 用缚魂锁链拽起了 " + ::Const.UI.getColorizedEntityName(entity));
        return true;
    }
});
