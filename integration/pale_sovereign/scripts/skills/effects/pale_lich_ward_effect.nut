// 1.7.7 尸妖王在场时，导师每回合首次受击伤害 −12（最低 1），并免疫爆头额外伤害与击退抓取
this.pale_lich_ward_effect <- ::inherit("scripts/skills/skill", {
    m = { Lich = null, UsedRound = -1, Pending = false },
    function create()
    {
        this.m.ID = "effects.pale_lich_ward";
        this.m.Name = "冢王护持";
        this.m.Description = "尸妖王仍立在战场上，冰冷的魂火绕在导师身侧。只要它还在场，导师每回合首次受到敌方攻击时生命与护甲伤害各 −12（最低保留 1 点），并免疫爆头额外伤害与击退、抓取。";
        this.m.Icon = "skills/pale_lich_ward_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function setLich( _entity )
    {
        this.m.Lich = ::MSU.asWeakTableRef(_entity);
    }

    function isLichPresent()
    {
        local lich = this.m.Lich;
        return lich != null && !::MSU.isNull(lich) && lich.isAlive() && !lich.isDying() && lich.isPlacedOnMap();
    }

    function isHidden()
    {
        return !this.isLichPresent();
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        local ready = this.m.UsedRound != ::Time.getRound();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "每回合首次受到敌方攻击时生命与护甲伤害各 [color=" + ::Const.UI.Color.PositiveValue + "]-" + ::PaleSovereign.LichWardFlat + "[/color]" + (ready ? "（本回合可用）" : "（本回合已触发）") });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "免疫爆头额外伤害、击退与抓取" });
        return ret;
    }

    function onUpdate( _properties )
    {
        if (!this.isLichPresent())
            return;
        _properties.IsImmuneToCriticals = true;
        _properties.IsImmuneToKnockBackAndGrab = true;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        this.m.Pending = false;
        if (!this.isLichPresent() || this.m.UsedRound == ::Time.getRound() || _skill == null || !_skill.isAttack())
            return;
        local actor = this.getContainer().getActor();
        if (_attacker != null && !::MSU.isNull(_attacker) && _attacker.isAlliedWith(actor))
            return;
        if (_hitInfo.DamageRegular <= 0 && _hitInfo.DamageArmor <= 0)
            return;
        local flat = ::PaleSovereign.LichWardFlat;
        if (_hitInfo.DamageRegular > 0)
            _hitInfo.DamageRegular = ::Math.max(1, _hitInfo.DamageRegular - flat);
        if (_hitInfo.DamageArmor > 0)
            _hitInfo.DamageArmor = ::Math.max(0, _hitInfo.DamageArmor - flat);
        this.m.Pending = true;
    }

    function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
    {
        if (!this.m.Pending)
            return;
        this.m.Pending = false;
        this.m.UsedRound = ::Time.getRound();
        ::PaleSovereign.playActorArt("lich_ward", this.getContainer().getActor());
    }
});
