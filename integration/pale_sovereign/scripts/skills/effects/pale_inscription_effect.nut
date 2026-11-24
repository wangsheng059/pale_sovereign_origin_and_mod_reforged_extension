// 1.7.0 冠军的魂玉铭刻：玉骨威压 / 苍白共鸣 / 守墓死契 / 裂魂锋芒（一个效果承载已铭刻的全部条目）
this.pale_inscription_effect <- ::inherit("scripts/skills/skill", {
    m = { Keys = [], ResonanceRound = -1, ResonancePending = false, Rage = 0 },
    function create()
    {
        this.m.ID = "effects.pale_inscription";
        this.m.Name = "魂玉铭刻";
        this.m.Icon = "skills/pale_dead_command_effect.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function setKeys( _keys )
    {
        this.m.Keys = clone _keys;
    }

    function has( _key )
    {
        return this.m.Keys.find(_key) != null;
    }

    function getDescription()
    {
        local S = ::PaleSovereign;
        local text = "刻进骨头里的魂玉记住了几种杀戮的方式。";
        foreach (key in this.m.Keys)
            text += "\n【" + S.Inscriptions[key].Name + "】" + S.Inscriptions[key].Desc;
        if (this.m.Rage > 0)
            text += "\n护主之怒 " + this.m.Rage + " 层：伤害 +" + (this.m.Rage * 10) + "%、近战技能 +" + (this.m.Rage * 5);
        return text;
    }

    function addRage()
    {
        if (this.m.Rage < 3)
        {
            ++this.m.Rage;
            this.getContainer().update();
        }
    }

    function onUpdate( _properties )
    {
        if (this.m.Rage > 0)
        {
            _properties.DamageTotalMult *= 1.0 + 0.1 * this.m.Rage;
            _properties.MeleeSkill += 5 * this.m.Rage;
        }
    }

    // 玉骨威压：出棺和击杀时触发
    function terrify()
    {
        if (!this.has("dread") || ::PaleSovereign.Battle == null)
            return;
        local actor = this.getContainer().getActor();
        if (!actor.isPlacedOnMap())
            return;
        local chief = ::PaleSovereign.chief();
        local hard = chief != null && chief.isPlacedOnMap() && chief.getTile().getDistanceTo(actor.getTile()) <= 4;
        local tile = actor.getTile();
        foreach (faction in ::Tactical.Entities.getAllInstances())
            foreach (other in faction)
            {
                if (other == null || !other.isAlive() || other.isDying() || !other.isPlacedOnMap() || other.isAlliedWith(actor)
                    || other.getFlags().has("undead") || other.getTile().getDistanceTo(tile) > 2
                    || other.getMoraleState() == ::Const.MoraleState.Ignore)
                    continue;
                local failed = false;
                try { failed = other.checkMorale(-1, hard ? -15 : -10, ::Const.MoraleCheckType.MentalAttack); } catch (e) { failed = false; }
                if (failed && other.isAlive())
                {
                    local daunted = other.getSkills().getSkillByID("effects.pale_daunted");
                    if (daunted == null)
                        other.getSkills().add(::new("scripts/skills/effects/pale_daunted_effect"));
                    else
                        daunted.m.Turns = 2;
                }
            }
    }

    function isPreyTarget( _target )
    {
        return _target != null && !::MSU.isNull(_target) && _target.getSkills().hasSkill("effects.pale_prey");
    }

    function onAnySkillUsed( _skill, _targetEntity, _properties )
    {
        if (_skill == null || !_skill.isAttack() || _targetEntity == null)
            return;
        if (this.has("resonance") && this.isPreyTarget(_targetEntity) && this.m.ResonanceRound != ::Time.getRound())
        {
            _properties.MeleeSkill += 15;
            _properties.RangedSkill += 15;
            _properties.DamageDirectAdd += 0.15;
            this.m.ResonancePending = true;
        }
        if (this.has("edge") && (this.isPreyTarget(_targetEntity) || _targetEntity.getHitpoints() * 2 <= _targetEntity.getHitpointsMax()))
            _properties.DamageDirectAdd += 0.15;
    }

    function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
    {
        if (!this.m.ResonancePending)
            return;
        this.m.ResonancePending = false;
        this.m.ResonanceRound = ::Time.getRound();
        local actor = this.getContainer().getActor();
        actor.setActionPoints(::Math.min(actor.getActionPointsMax(), actor.getActionPoints() + 2));
        actor.setDirty(true);
    }

    function onTargetMissed( _skill, _targetEntity )
    {
        if (this.m.ResonancePending)
        {
            this.m.ResonancePending = false;
            this.m.ResonanceRound = ::Time.getRound();
        }
    }

    function onTargetKilled( _targetEntity, _skill )
    {
        local actor = this.getContainer().getActor();
        if (this.has("edge"))
        {
            actor.setHitpoints(::Math.min(actor.getHitpointsMax(), actor.getHitpoints() + ::Math.floor(actor.getHitpointsMax() * 0.15)));
            foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
            {
                local item = actor.getItems().getItemAtSlot(slot);
                if (item != null)
                    item.setCondition(::Math.minf(item.getConditionMax(), item.getCondition() + 25));
            }
            actor.setDirty(true);
        }
        this.terrify();
    }
});
