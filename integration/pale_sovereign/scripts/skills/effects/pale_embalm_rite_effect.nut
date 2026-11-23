// 1.6.30 古堡盐窖的防腐秘仪：开局由 embalm_craft.nut 挂上，只在本场战斗存在（不存档）
this.pale_embalm_rite_effect <- ::inherit("scripts/skills/skill", {
    m = { Rites = [], Infusion = 0, MoveBackup = null, BreakFreeAP = -1, Busy = false },
    function create()
    {
        this.m.ID = "effects.pale_embalm_rite";
        this.m.Name = "防腐秘仪";
        this.m.Description = "盐窖里的防腐师用尸骸为这具躯壳做了额外的处理，效果会持续到本场战斗结束。";
        this.m.Icon = "ui/traits/pale_embalmed.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsActive = false;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function hasRite( _key )
    {
        return this.m.Rites.find(_key) != null;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        local S = ::PaleSovereign;
        local id = 10;
        foreach (rite in S.Rites)
        {
            if (!this.hasRite(rite.Key))
                continue;
            local text = "【" + rite.Name + "】" + rite.Effect;
            if (rite.Key == "infuse")
                text += "（剩余 " + this.m.Infusion + " 层，当前每层 " + this.getInfusionDamage() + " 点）";
            local left = S.riteCharges(this.getContainer().getActor(), rite.Key);
            text += left > 0 ? "，本场之后还剩 " + left + " 场" : "，本场为最后一场";
            ret.push({ id = id++, type = "text", icon = "ui/icons/special.png", text = text });
        }
        return ret;
    }

    function setupBattle()
    {
        local actor = this.getContainer().getActor();
        if (this.hasRite("infuse"))
            this.m.Infusion = 3;
        if (this.hasRite("armor"))
        {
            local flags = actor.getFlags();
            local b = actor.getBaseProperties();
            foreach (part in ["Head", "Body"])
            {
                local index = ::Const.BodyPart[part];
                flags.set("PaleRiteArmor" + part, b.Armor[index]);
                flags.set("PaleRiteArmorMax" + part, b.ArmorMax[index]);
                b.Armor[index] += 40;
                b.ArmorMax[index] += 40;
            }
            flags.set("PaleRiteArmor", true);
        }
        if (this.hasRite("tendon"))
            this.applyMovement();
        this.getContainer().update();
    }

    function applyMovement()
    {
        local actor = this.getContainer().getActor();
        if (this.m.MoveBackup != null)
            return;
        this.m.MoveBackup = { AP = actor.m.ActionPointCosts, Fatigue = actor.m.FatigueCosts, Level = actor.m.LevelActionPointCost };
        if (!this.getContainer().hasSkill("perk.pathfinder") && "PathfinderMovementAPCost" in ::Const && "PathfinderMovementFatigueCost" in ::Const)
        {
            // 没有探路者：直接套用原版探路者的移动消耗
            actor.m.ActionPointCosts = ::Const.PathfinderMovementAPCost;
            actor.m.FatigueCosts = ::Const.PathfinderMovementFatigueCost;
            actor.m.LevelActionPointCost = 0;
            return;
        }
        // 已有探路者：在现有消耗上再 −1 行动点（最低 1）、疲劳再减半
        local ap = [];
        foreach (cost in actor.m.ActionPointCosts)
            ap.push(cost <= 0 ? cost : ::Math.max(1, cost - 1));
        local fatigue = [];
        foreach (cost in actor.m.FatigueCosts)
            fatigue.push(cost <= 0 ? cost : ::Math.max(1, ::Math.floor(cost / 2)));
        actor.m.ActionPointCosts = ap;
        actor.m.FatigueCosts = fatigue;
        actor.m.LevelActionPointCost = 0;
    }

    function restoreMovement()
    {
        if (this.m.MoveBackup == null)
            return;
        local actor = this.getContainer().getActor();
        actor.m.ActionPointCosts = this.m.MoveBackup.AP;
        actor.m.FatigueCosts = this.m.MoveBackup.Fatigue;
        actor.m.LevelActionPointCost = this.m.MoveBackup.Level;
        this.m.MoveBackup = null;
    }

    function getInfusionDamage()
    {
        local chief = ::PaleSovereign.chief();
        local will = 0;
        if (chief != null)
            try { will = chief.getCurrentProperties().getBravery(); } catch (e) { will = chief.getBaseProperties().Bravery; }
        return ::Math.floor(8 + ::Math.max(0, will) * 0.1);
    }

    function onUpdate( _properties )
    {
        if (this.hasRite("fumigate"))
        {
            _properties.RangedDefense += 15;
            _properties.IsImmuneToFire = true;
        }
        if (this.hasRite("armor"))
            _properties.IsImmuneToCriticals = true;
        if (this.hasRite("tendon"))
            _properties.IsImmuneToKnockBackAndGrab = true;
        if (this.hasRite("imprint"))
            _properties.XPGainMult *= this.getContainer().getActor().getLevel() <= 6 ? 1.6 : 1.4;
    }

    function onAfterUpdate( _properties )
    {
        if (!this.hasRite("tendon"))
            return;
        foreach (skill in this.getContainer().getSkillsByFunction(@(_s) _s.getID().find("break_free") != null))
        {
            // MSU 每次更新会把行动点还原成基础值；只在还没减半时减半，避免重复叠加
            if (skill.m.ActionPointCost == this.m.BreakFreeAP)
                continue;
            this.m.BreakFreeAP = ::Math.max(1, ::Math.ceil(skill.m.ActionPointCost / 2.0));
            skill.m.ActionPointCost = this.m.BreakFreeAP;
        }
    }

    // 尸脂熏蒸：自己回合开始和结束时，在相邻敌人脚下铺开 / 续上苍白冷焰
    function onTurnStart()
    {
        if (this.hasRite("fumigate"))
            ::PaleSovereign.spreadColdfire(this.getContainer().getActor());
    }

    function onTurnEnd()
    {
        if (this.hasRite("fumigate"))
            ::PaleSovereign.spreadColdfire(this.getContainer().getActor());
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        // 厚骨覆甲：受到攻击时穿甲比例减 15 个百分点（30% → 15%），本来无视护甲的伤害不变；爆头免疫在 onUpdate
        if (this.hasRite("armor") && _skill != null && _skill.isAttack() && _hitInfo.DamageDirect < 1.0)
            _hitInfo.DamageDirect = ::Math.maxf(0.0, _hitInfo.DamageDirect - 0.15);
        if (!this.hasRite("fumigate"))
            return;
        local burning = false;
        try { burning = _hitInfo.DamageType == ::Const.Damage.DamageType.Burning; } catch (e) { burning = false; }
        if (burning || (_skill != null && (_skill.getID() == "actives.throw_fire_bomb" || _skill.getID() == "actives.throw_acid_flask")))
            _properties.DamageReceivedTotalMult = 0.0;
    }

    function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
    {
        if (this.m.Busy || _skill == null || !_skill.isAttack() || _targetEntity == null || ::MSU.isNull(_targetEntity)
            || !_targetEntity.isAlive() || _targetEntity.isDying())
            return;
        local actor = this.getContainer().getActor();
        if (_targetEntity.isAlliedWith(actor))
            return;
        this.m.Busy = true;
        try
        {
            if (this.hasRite("poison") && !_targetEntity.getFlags().has("undead"))
            {
                local poison = _targetEntity.getSkills().getSkillByID("effects.pale_corpse_poison");
                if (poison != null)
                    poison.resetTime();
                else
                    _targetEntity.getSkills().add(::new("scripts/skills/effects/pale_corpse_poison_effect"));
            }
            if (this.hasRite("infuse") && this.m.Infusion > 0)
            {
                --this.m.Infusion;
                local damage = this.getInfusionDamage();
                if (!actor.isHiddenToPlayer() || !_targetEntity.isHiddenToPlayer())
                    ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(actor) + " 灌注的死气涌入 " + ::Const.UI.getColorizedEntityName(_targetEntity)
                        + " 体内（额外 " + damage + " 点无视护甲伤害，剩余 " + this.m.Infusion + " 层）");
                ::PaleSovereign.directDamage(actor, this, _targetEntity, damage);
                if (_targetEntity.isAlive() && !_targetEntity.isDying())
                {
                    _targetEntity.setFatigue(::Math.min(_targetEntity.getFatigueMax(), _targetEntity.getFatigue() + 10));
                    _targetEntity.checkMorale(-1, 20);
                }
            }
        }
        catch (e)
            ::logError("[PaleSovereign] 防腐秘仪命中: " + e);
        this.m.Busy = false;
    }

    function onCombatFinished()
    {
        this.restoreMovement();
        ::PaleSovereign.restoreRiteArmor(this.getContainer().getActor());
        this.removeSelf();
    }

    function onRemoved()
    {
        this.restoreMovement();
    }
});
