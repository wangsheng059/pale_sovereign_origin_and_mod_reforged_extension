this.pale_weaken <- ::inherit("scripts/skills/skill", {
    m = { Champion = false, Scourge = false, Used = false },
    function create()
    {
        this.m.ID = "actives.pale_weaken";
        this.m.Name = "衰弱术";
        this.m.Description = "无视遮挡的阴冷诅咒，抽干目标的气力，让它出刃无力、架盾发虚。必定命中，不会造成临时伤。";
        this.m.Icon = "skills/pale_weaken.png";
        this.m.IconDisabled = "skills/pale_weaken_sw.png";
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.UtilityTargeted;
        this.m.IsActive = true;
        this.m.IsTargeted = true;
        this.m.IsTargetingActor = true;
        this.m.IsAttack = false;
        this.m.IsWeaponSkill = false;
        this.m.IsVisibleTileNeeded = false;
        this.m.IsIgnoredAsAOO = true;
        this.m.IsSerialized = false;
        this.m.ActionPointCost = 5;
        this.m.FatigueCost = 12;
        this.m.MinRange = 2;
        this.m.MaxRange = 5;
        this.m.MaxLevelDifference = 99;
        this.m.DamageType.add(::Const.Damage.DamageType.Blunt);
    }

    function getTooltip()
    {
        local ret = this.getDefaultUtilityTooltip();
        local actor = this.getContainer().getActor();
        local w = ::BGP.Necro.getWill(actor);
        local turns = 2 + ::BGP.Necro.spellDurationBonus(actor);
        ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "距离 2–" + this.m.MaxRange + " 格，无需视野。造成 12–20 点无视护甲伤害。" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/melee_skill.png", text = "近战技能、远程技能、近战防御各 −" + (2 + ::Math.floor(w / 20.0)) + "，持续 " + turns + " 回合。" });
        ret.push({ id = 13, type = "text", icon = "ui/icons/hitchance.png", text = "把主目标标记为猎物（" + turns + " 回合，同一时间只有一个）：所有友方亡灵优先攻击它，导师与所有友方亡灵对其命中 +10、伤害 +20%。" });
        if (this.m.Scourge)
            ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "相邻敌人承受一半伤害和完整的衰弱效果。" });
        return ret;
    }

    function isUsable()
    {
        return !this.m.Used && this.skill.isUsable();
    }

    function onTurnStart()
    {
        this.m.Used = false;
    }

    function onCombatFinished()
    {
        this.m.Used = false;
    }

    function onVerifyTarget( _origin, _tile )
    {
        return this.skill.onVerifyTarget(_origin, _tile) && ::PaleSovereign.isEnemy(this.getContainer().getActor(), _tile);
    }

    function onUse( _user, _tile )
    {
        if (this.m.Used || !this.onVerifyTarget(_user.getTile(), _tile))
            return false;
        this.m.Used = true;
        local damage = ::Math.rand(12, 20);
        local penalty = 2 + ::Math.floor(::BGP.Necro.getWill(_user) / 20.0);
        local turns = 2 + ::BGP.Necro.spellDurationBonus(_user);
        local tiles = this.m.Scourge ? ::PaleSovereign.area(_tile) : [_tile];
        foreach (tile in tiles)
        {
            if (!::PaleSovereign.isEnemy(_user, tile))
                continue;
            local target = tile.getEntity();
            ::PaleSovereign.playBattleArt("curse", tile, 42, tile.ID == _tile.ID ? 1.0 : 0.66);
            ::PaleSovereign.directDamage(_user, this, target, tile.ID == _tile.ID ? damage : damage * 0.5);
            if (target == null || ::MSU.isNull(target) || !target.isAlive() || target.isDying())
                continue;
            local skills = target.getSkills();
            local effect = skills.getSkillByID("effects.pale_weaken");
            if (effect == null)
            {
                effect = ::new("scripts/skills/effects/pale_weaken_effect");
                skills.add(effect);
            }
            effect.m.Penalty = penalty;
            effect.m.Turns = turns;
            if (tile.ID == _tile.ID)
                ::PaleSovereign.markPrey(target, turns);
            skills.update();
        }
        return true;
    }
});
