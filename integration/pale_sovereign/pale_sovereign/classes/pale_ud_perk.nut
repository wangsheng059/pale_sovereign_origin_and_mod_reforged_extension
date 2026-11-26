// Shared base class for permanent undead exclusive perks (retained across tier promotions).
this.pale_ud_perk <- ::inherit("scripts/skills/skill", {
    m = {
        PaleKey = "",
        PaleRetainOnPromote = true,
        IsSpent = false,
        IsUsed = false
    },

    function create()
    {
        if (this.m.DamageType == null)
        {
            this.m.DamageType = ::MSU.Class.DamageType();
            this.m.DamageType.setSkill(this);
            this.m.DamageType.doInit();
        }
        local def = ::PaleSovereign.UndeadPerks[this.m.PaleKey];
        this.m.ID = "perk.pale_ud_" + this.m.PaleKey;
        this.m.Name = def.Name;
        this.m.Description = def.Description;
        this.m.Icon = def.Icon + ".png";
        this.m.IconDisabled = def.Icon + "_sw.png";
        this.m.Type = ::Const.SkillType.Perk;
        this.m.Order = ::Const.SkillOrder.Perk;
        this.m.IsActive = false;
        this.m.IsStacking = false;
        this.m.IsHidden = false;
        if (this.m.PaleKey == "plague")
        {
            this.m.SoundOnUse = [
                "sounds/combat/poison_applied_01.wav",
                "sounds/combat/poison_applied_02.wav"
            ];
        }
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        local actor = null;
        try { actor = this.getContainer().getActor(); } catch (e) { actor = null; }
        switch (this.m.PaleKey)
        {
            case "necro_pact":
                local lvl = actor != null && !::MSU.isNull(actor) ? actor.getLevel() : 1;
                local minB = ::Math.floor((lvl + 1) * 0.5);
                local maxB = lvl;
                ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png",
                    text = "当前最小伤害 " + ::MSU.Text.colorPositive("+" + minB) + "、最大伤害 " + ::MSU.Text.colorPositive("+" + maxB) });
                break;
            case "regenerative":
                if (actor != null && !::MSU.isNull(actor))
                {
                    local heal = ::Math.max(1, ::Math.floor(actor.getHitpointsMax() * 0.08));
                    ret.push({ id = 10, type = "text", icon = "ui/icons/health.png",
                        text = "每回合开始回复 " + ::MSU.Text.colorPositive("" + heal) + " 点生命（8% 最大生命）" });
                }
                break;
            case "soften_blows":
                if (this.m.IsUsed)
                    ret.push({ id = 10, type = "text", icon = "ui/icons/warning.png", text = ::MSU.Text.colorNegative("本回合已触发") });
                break;
            case "unlife":
                if (this.m.IsSpent)
                    ret.push({ id = 10, type = "text", icon = "ui/icons/warning.png", text = ::MSU.Text.colorNegative("本场已经用过") });
                break;
        }
        ret.push({ id = 15, type = "text", icon = "ui/icons/special.png", text = "常驻亡灵专属特技：升阶时永久保留。" });
        return ret;
    }

    function onAdded()
    {
        this.m.IsSpent = false;
        this.m.IsUsed = false;
    }

    function onCombatStarted()
    {
        this.m.IsSpent = false;
        this.m.IsUsed = false;
    }

    function onCombatFinished()
    {
        this.skill.onCombatFinished();
        this.m.IsSpent = false;
        this.m.IsUsed = false;
    }

    function onUpdate( _properties )
    {
        local actor = this.getContainer().getActor();
        switch (this.m.PaleKey)
        {
            case "healthy":
                _properties.Hitpoints += 25;
                break;
            case "undying_flesh":
                _properties.DamageReceivedTotalMult *= 0.9;
                break;
            case "necro_pact":
                local lvl = actor != null && !::MSU.isNull(actor) ? actor.getLevel() : 1;
                _properties.DamageRegularMin += ::Math.floor((lvl + 1) * 0.5);
                _properties.DamageRegularMax += lvl;
                break;
        }
    }

    function onTurnStart()
    {
        local actor = this.getContainer().getActor();
        if (actor == null || ::MSU.isNull(actor))
            return;
        switch (this.m.PaleKey)
        {
            case "soften_blows":
                this.m.IsUsed = false;
                break;
            case "rot_stench":
                if (!actor.isPlacedOnMap())
                    return;
                local tile = actor.getTile();
                for (local i = 0; i < 6; ++i)
                {
                    if (!tile.hasNextTile(i))
                        continue;
                    local next = tile.getNextTile(i);
                    if (!next.IsOccupiedByActor)
                        continue;
                    local e = next.getEntity();
                    if (e == null || !e.isAlive() || e.isDying() || e.isAlliedWith(actor))
                        continue;
                    try
                    {
                        e.setFatigue(::Math.min(e.getFatigueMax(), e.getFatigue() + 5));
                        e.setDirty(true);
                    }
                    catch (err) {}
                }
                break;
            case "regenerative":
                if (!actor.isPlacedOnMap() || !actor.isAlive() || actor.isDying())
                    return;
                local missing = actor.getHitpointsMax() - actor.getHitpoints();
                if (missing <= 0)
                    return;
                local heal = ::Math.min(missing, ::Math.max(1, ::Math.floor(actor.getHitpointsMax() * 0.08)));
                actor.setHitpoints(actor.getHitpoints() + heal);
                actor.setDirty(true);
                if (!actor.isHiddenToPlayer())
                {
                    try { this.spawnIcon("status_effect_79", actor.getTile()); } catch (e) {}
                    ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(actor) + " 恢复了 " + heal + " 点生命（骨髓再生）");
                }
                break;
        }
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        if (this.m.PaleKey != "soften_blows" || this.m.IsUsed)
            return;
        local actor = this.getContainer().getActor();
        if (actor == null || ::MSU.isNull(actor) || actor.getCurrentProperties().IsStunned
            || actor.getMoraleState() == ::Const.MoraleState.Fleeing)
            return;
        this.m.IsUsed = true;
        _properties.DamageReceivedTotalMult *= 0.75;
    }

    function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
    {
        if (this.m.PaleKey != "plague" || _skill == null || !_skill.isAttack() || this.getContainer() == null)
            return;
        if (_targetEntity == null || ::MSU.isNull(_targetEntity) || !_targetEntity.isAlive() || _targetEntity.isDying() || _targetEntity.getHitpoints() <= 0)
            return;
        local actor = this.getContainer().getActor();
        if (actor == null || ::MSU.isNull(actor) || _targetEntity.isAlliedWith(actor) || _targetEntity.getCurrentProperties().IsImmuneToPoison)
            return;
        if (_targetEntity.getSkills().hasSkill("effects.bgp_undead_poison"))
            return;
        _targetEntity.getSkills().add(::new("scripts/skills/effects/bgp_undead_poison_effect"));
        if (!_targetEntity.isHiddenToPlayer())
        {
            if (this.m.SoundOnUse.len() > 0)
                ::Sound.play(this.m.SoundOnUse[::Math.rand(0, this.m.SoundOnUse.len() - 1)], ::Const.Sound.Volume.RacialEffect * 1.5, _targetEntity.getPos());
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_targetEntity) + " 中了尸毒");
        }
        try { this.spawnIcon("status_effect_54", _targetEntity.getTile()); } catch (e) {}
    }

    function onTargetKilled( _targetEntity, _skill )
    {
        if (this.m.PaleKey != "soul_siphon")
            return;
        local actor = this.getContainer().getActor();
        if (actor == null || ::MSU.isNull(actor) || !actor.isAlive() || _targetEntity == null || ::MSU.isNull(_targetEntity) || _targetEntity.isAlliedWith(actor))
            return;
        local parts = [];
        local heal = ::Math.min(20, actor.getHitpointsMax() - actor.getHitpoints());
        if (heal > 0)
        {
            ::BGP.heal(actor, heal);
            parts.push(heal + " 点生命");
        }
        try
        {
            local fat = ::Math.min(20, actor.getFatigue());
            if (fat > 0)
            {
                actor.setFatigue(actor.getFatigue() - fat);
                actor.setDirty(true);
                parts.push(fat + " 点疲劳");
            }
        }
        catch (e) {}
        if (parts.len() == 0)
            return;
        local text = "回复了 ";
        foreach (i, p in parts)
            text += (i == 0 ? "" : "、") + p;
        ::BGP.log(actor, text + "（灵魂虹吸）");
    }

    function tryCheatDeath()
    {
        if (this.m.PaleKey != "unlife" || this.m.IsSpent)
            return false;
        local actor = this.getContainer().getActor();
        if (actor == null || ::MSU.isNull(actor))
            return false;
        this.m.IsSpent = true;
        actor.setHitpoints(::Math.max(1, ::Math.floor(actor.getHitpointsMax() * 0.3)));
        try { actor.getSkills().removeByType(::Const.SkillType.DamageOverTime); } catch (e) {}
        actor.setDirty(true);
        ::BGP.log(actor, "从死亡中又爬了起来（死而复生）");
        return true;
    }
});
