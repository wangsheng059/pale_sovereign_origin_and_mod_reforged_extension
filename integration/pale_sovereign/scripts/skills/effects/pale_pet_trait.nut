this.pale_pet_trait <- ::inherit("scripts/skills/skill", {
    m = { Species = 0, Intercepted = false, PendingInterception = false },
    function create()
    {
        this.m.Type = ::Const.SkillType.Trait;
        this.m.IsSerialized = false;
        this.m.IsStacking = false;
    }

    function configure( _species )
    {
        this.m.Species = _species;
        this.m.ID = "trait.pale_soul_" + _species;
        this.m.Name = ["", "仪仗列盾", "堕落者之力", "饮血", "第三面残旗"][_species];
        this.m.Description = [
            "", "装备盾牌时，其近防和远防加成提高 25%。",
            "近战技能 +5，近战伤害 +10%。",
            "攻击造成生命伤害时，恢复该生命伤害 25% 的生命。",
            "每战首次在首席身旁遭受敌方攻击时，生命与护甲伤害减半。"
        ][_species];
        local icon = "pale_" + ["", "honor", "fallen", "vampire", "banner"][_species];
        this.m.Icon = "skills/" + icon + ".png";
        this.m.IconDisabled = "skills/" + icon + "_sw.png";
    }

    function onUpdate( _properties )
    {
        if (this.m.Species == 1)
            _properties.IsSpecializedInShields = true;
        else if (this.m.Species == 2)
        {
            _properties.MeleeSkill += 5;
            _properties.MeleeDamageMult *= 1.1;
        }
    }

    function onTargetHit( _skill, _target, _part, _hp, _armor )
    {
        if (this.m.Species != 3 || _hp < 1 || !_skill.isAttack())
            return;
        local actor = this.getContainer().getActor();
        actor.setHitpoints(::Math.minf(actor.getHitpointsMax(), actor.getHitpoints() + ::Math.max(1, ::Math.floor(_hp * 0.25))));
    }

    function onBeforeDamageReceived( _attacker, _skill, _hit, _properties )
    {
        this.m.PendingInterception = false;
        if (this.m.Species != 4 || this.m.Intercepted || _attacker == null || _skill == null || !_skill.isAttack())
            return;
        local actor = this.getContainer().getActor();
        local chief = ::PaleSovereign.chief();
        if (chief == null || !chief.isAlive() || !chief.isPlacedOnMap()
            || actor.getTile().getDistanceTo(chief.getTile()) != 1 || _attacker.isAlliedWith(actor))
            return;
        this.m.PendingInterception = true;
        _hit.DamageRegular *= 0.5;
        _hit.DamageArmor *= 0.5;
    }

    function onDamageReceived( _attacker, _hp, _armor )
    {
        if (this.m.PendingInterception)
            this.m.Intercepted = true;
        this.m.PendingInterception = false;
    }
});
