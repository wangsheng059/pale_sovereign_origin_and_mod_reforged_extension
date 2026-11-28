this.pale_corpse_shot <- ::inherit("scripts/skills/skill", {
    m = { DivertedHit = false },
    function create()
    {
        this.m.ID = "actives.pale_corpse_shot";
        this.m.Name = "尸弹";
        this.m.Description = "将一具沉重的防腐尸骸掷向敌阵，落地的尸体可随时复活或引爆。";
        this.m.Icon = "skills/pale_corpse_shot.png";
        this.m.IconDisabled = "skills/pale_corpse_shot_sw.png";
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.UtilityTargeted;
        this.m.IsActive = true;
        this.m.IsTargeted = true;
        this.m.IsRanged = true;
        this.m.IsAttack = true;
        this.m.IsWeaponSkill = false;
        this.m.IsIgnoredAsAOO = true;
        this.m.IsSerialized = false;
        this.m.IsShowingProjectile = true;
        this.m.ProjectileType = ::PaleSovereign.CorpseProjectile;
        this.m.ActionPointCost = 4;
        this.m.FatigueCost = 20;
        this.m.MinRange = 1;
        this.m.MaxRange = 3;
        this.m.DirectDamageMult = 0.15;
        this.m.InjuriesOnBody = ::Const.Injury.BluntBody;
        this.m.InjuriesOnHead = ::Const.Injury.BluntHead;
        this.m.DamageType.add(::Const.Damage.DamageType.Blunt);
    }

    function getTooltip()
    {
        local ret = this.getDefaultTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "消耗 1 点防腐尸骸（剩余 " + ::PaleSovereign.get("Reserve") + " 点）。命中时尸体落在受击者脚下，未命中则落在目标格。" });
        return ret;
    }

    function isHidden()
    {
        local s = ::PaleSovereign;
        return !s.isActive() || s.oath() != s.Oath.Scourge || s.get("Reserve") <= 0;
    }

    function isUsable()
    {
        return !this.isHidden() && this.skill.isUsable();
    }

    function onAfterUpdate( _properties )
    {
        this.m.FatigueCost = ::PaleSovereign.ambitionDone("laden_cart") ? 16 : 20;
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (_skill != this)
            return;
        _properties.DamageRegularMin = 20;
        _properties.DamageRegularMax = 30;
        _properties.DamageArmorMult = 1.0;
    }

    function onVerifyTarget( _origin, _tile )
    {
        return _origin.getDistanceTo(_tile) <= this.getMaxRange() && this.skill.onVerifyTarget(_origin, _tile)
            && ::PaleSovereign.isEnemy(this.getContainer().getActor(), _tile);
    }

    function onUse( _user, _tile )
    {
        local s = ::PaleSovereign;
        if (this.isHidden() || !this.onVerifyTarget(_user.getTile(), _tile) || !s.changeReserve(-1))
            return false;
        s.set("CorpseTossCount", s.get("CorpseTossCount") + 1);
        this.m.DivertedHit = false;
        if (!this.attackEntity(_user, _tile.getEntity()) && !this.m.DivertedHit)
        {
            local flight = 0;
            if (_user.getTile().getDistanceTo(_tile) >= ::Const.Combat.SpawnProjectileMinDist)
                flight = ::Tactical.spawnProjectileEffect(::Const.ProjectileSprite[this.m.ProjectileType], _user.getTile(), _tile, 1.0, 1.0, false, false);
            s.playBattleArt("landing", _tile, 7, 0.85, flight);
            s.placeShot(_tile);
        }
        return true;
    }

    function divertAttack( _user, _target )
    {
        local tile = _target.getTile();
        local from = _user.getTile();
        local distance = from.getDistanceTo(tile);
        if (distance < ::Const.Combat.DiversionMinDist)
            return;
        local d = distance >= ::Const.Combat.DiversionSpreadMinDist ? ::Math.rand(0, 5) : from.getDirectionTo(tile);
        if (!tile.hasNextTile(d))
            return;
        local side = tile.getNextTile(d);
        if (side.IsOccupiedByActor && side.Level - tile.Level <= ::Const.Combat.DiversionMaxLevelDifference)
            this.m.DivertedHit = this.attackEntity(_user, side.getEntity(), false);
    }

    function onScheduledTargetHit( _info )
    {
        local tile = _info.TargetEntity != null && !::MSU.isNull(_info.TargetEntity) && _info.TargetEntity.isPlacedOnMap() ? _info.TargetEntity.getTile() : null;
        // Projectile callbacks may run without the skill as their environment.
        local shot = _info.Skill;
        shot.skill.onScheduledTargetHit.call(shot, _info);
        if (tile != null)
        {
            ::PaleSovereign.playBattleArt("landing", tile, 10);
            ::PaleSovereign.placeShot(tile);
        }
    }
});
