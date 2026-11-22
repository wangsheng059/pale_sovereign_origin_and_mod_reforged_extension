this.pale_heavy_stomp <- ::inherit("scripts/skills/actives/pale_tier_attack", {
    m = { Splash = null },

    function create()
    {
        this.pale_tier_attack.create();
        this.m.Overlay = "";
        this.m.ActionPointCost = 6;
        this.m.FatigueCost = 25;
        this.m.MaxRange = 1;
        this.m.DamageLow = 0;
        this.m.DamageHigh = 0;
        this.m.ArmorEfficiency = 1.4;
        this.m.DirectDamageMult = 0.45;
        this.m.InjuriesOnBody = ::Const.Injury.BluntBody;
        this.m.InjuriesOnHead = ::Const.Injury.BluntHead;
        this.m.DamageType.add(::Const.Damage.DamageType.Blunt);
    }

    function getTooltip()
    {
        local ret = this.getDefaultTooltip();
        local actor = this.getContainer().getActor();
        ret.push({ id = 12, type = "text", icon = "ui/icons/regular_damage.png", text = "基础伤害 = 最大生命 ÷ 4 + 头甲与身甲的疲劳惩罚之和。当前为 "
            + ::Math.floor(actor.getHitpointsMax() / 4.0) + " + " + this.getArmorWeight(actor) + " = " + this.getStompDamage(actor) + "。" });
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "命中时使主目标眩晕 1 回合。主目标身旁随机一名敌人承受一半伤害并踉跄，行动推迟至回合末。" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/hitchance.png", text = "无视主目标一半的盾牌防御加成。" });
        return ret;
    }

    function getArmorWeight( _actor )
    {
        local weight = 0;
        foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
        {
            local item = _actor.getItems().getItemAtSlot(slot);
            if (item != null)
                weight += ::Math.abs(item.getStaminaModifier());
        }
        return weight;
    }

    function getStompDamage( _actor )
    {
        return ::Math.floor(_actor.getHitpointsMax() / 4.0) + this.getArmorWeight(_actor);
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (_skill == this)
        {
            local damage = this.getStompDamage(this.getContainer().getActor());
            this.m.DamageLow = damage;
            this.m.DamageHigh = damage;
        }
        this.pale_tier_attack.onAnySkillUsed(_skill, _target, _properties);
        if (_skill == this && _target != null)
        {
            local bonus = this.MV_getShieldBonus(_target) * 0.5;
            // Apply the shield adjustment after the attacker's melee skill multiplier.
            if (_properties.MeleeSkillMult > 0)
                _properties.MeleeSkill += bonus / _properties.MeleeSkillMult;
        }
    }

    function onVerifyTarget( _origin, _tile )
    {
        return _origin.getDistanceTo(_tile) == 1 && this.skill.onVerifyTarget(_origin, _tile)
            && ::PaleSovereign.isEnemy(this.getContainer().getActor(), _tile);
    }

    function onUse( _user, _tile )
    {
        if (!this.onVerifyTarget(_user.getTile(), _tile))
            return false;
        ::PaleSovereign.playBattleArt("launch", _user.getTile(), 6, 0.65);
        this.attackEntity(_user, _tile.getEntity());
        return true;
    }

    function onBeforeTargetHit( _skill, _target, _hit )
    {
        if (_skill == this)
            this.m.Splash = clone _hit;
    }

    function onTargetHit( _skill, _target, _part, _hp, _armor )
    {
        if (_skill != this)
            return;
        local S = ::PaleSovereign;
        if (S.tierActorOnMap(_target))
            _target.getSkills().add(::new("scripts/skills/effects/stunned_effect"));

        local hit = this.m.Splash;
        this.m.Splash = null;
        if (hit != null)
            S.playBattleArt("stomp", hit.Tile, 6);
        if (hit == null)
            return;
        local actor = this.getContainer().getActor();
        local victims = [];
        foreach (tile in S.area(hit.Tile))
        {
            if (tile.ID != hit.Tile.ID && S.isEnemy(actor, tile) && tile.getEntity().getID() != _target.getID())
                victims.push(tile.getEntity());
        }
        if (victims.len() == 0)
            return;
        local victim = victims[::Math.rand(0, victims.len() - 1)];
        hit.Tile = victim.getTile();
        S.playBattleArt("stomp", hit.Tile, 6, 0.62, 70);
        hit.DamageRegular *= 0.5;
        hit.DamageArmor *= 0.5;
        hit.DamageFatigue *= 0.5;
        hit.DamageMinimum *= 0.5;
        hit.BodyPart = ::Const.BodyPart.Body;
        hit.BodyDamageMult = hit.MV_PropertiesForUse.DamageAgainstMult[::Const.BodyPart.Body];
        hit.Injuries = ::Const.Damage.getApplicableInjuries(::Const.Damage.DamageType.Blunt, hit.BodyPart, victim);
        hit.MV_PropertiesForDefense = victim.getSkills().buildPropertiesForDefense(actor, this);
        victim.onDamageReceived(actor, this, hit);
        if (S.tierActorOnMap(victim))
            S.applyTierStagger(victim);
    }
});
