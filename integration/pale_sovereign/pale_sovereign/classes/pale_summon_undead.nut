// 召唤僵尸 / 召唤骷髅：亡灵法师导师自带的主动技能，在相邻空格召出一名临时亡灵仆从（战斗结束后消散），每场每种 1 次
this.pale_summon_undead <- ::inherit("scripts/skills/skill", {
    m = { Script = "", MinionName = "", Used = false },
    function create()
    {
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.UtilityTargeted;
        this.m.SoundOnUse = ["sounds/enemies/necromancer_01.wav", "sounds/enemies/necromancer_02.wav", "sounds/enemies/necromancer_03.wav"];
        this.m.SoundVolume = 1.2;
        this.m.Overlay = "";
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
        this.m.MaxRange = 1;
    }

    function getTooltip()
    {
        local ret = this.skill.getDefaultUtilityTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "在相邻的空格召出一名" + this.m.MinionName + "，由 AI 控制，战斗结束后消散" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "每场战斗限 1 次" });
        if (this.m.Used)
            ret.push({ id = 12, type = "text", icon = "ui/icons/warning.png", text = "本场已经使用过" });
        return ret;
    }

    function isHidden()
    {
        local s = ::PaleSovereign;
        return !s.isActive() || !s.isChief(this.getContainer().getActor());
    }

    function isUsable()
    {
        return !this.isHidden() && !this.m.Used && ::PaleSovereign.Battle != null && this.skill.isUsable();
    }

    function onCombatStarted()
    {
        this.m.Used = false;
    }

    function onCombatFinished()
    {
        this.m.Used = false;
    }

    function onVerifyTarget( _originTile, _targetTile )
    {
        return this.skill.onVerifyTarget(_originTile, _targetTile) && _targetTile.IsEmpty;
    }

    function onUse( _user, _targetTile )
    {
        local s = ::PaleSovereign;
        if (!this.isUsable() || !_targetTile.IsEmpty)
            return false;
        local e = ::Tactical.spawnEntity(this.m.Script, _targetTile.Coords.X, _targetTile.Coords.Y);
        if (e == null)
            return false;
        this.m.Used = true;
        try { e.setFaction(::Const.Faction.PlayerAnimals); } catch (err) {}
        try { e.assignRandomEquipment(); } catch (err) {}
        ::BGP.Necro.markGearNoLoot(e);
        try { e.m.Name = e.m.BGP_MinionName; } catch (err) {}
        try { e.riseFromGround(); } catch (err) {}
        ::BGP.Necro.copySocket(_user, e);
        ::BGP.Necro.markMinion(_user, e);
        e.getFlags().set("PaleRaised", true);
        s.addBattleBoons(e);
        if (s.isAscended() && s.oath() == s.Oath.Scourge && !e.getSkills().hasSkill("effects.pale_dominion"))
            e.getSkills().add(::new(s.SkillDir + "effects/pale_dominion_effect"));
        e.getSkills().update();
        s.playBattleArt("resurrect", _targetTile, 28);
        if (!_user.isHiddenToPlayer())
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " 召出了 " + ::Const.UI.getColorizedEntityName(e));
        return true;
    }
});
