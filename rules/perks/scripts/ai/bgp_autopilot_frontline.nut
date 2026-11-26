// Tactical opener and shield-vanguard behavior for Autopilot-controlled player brothers.
// Coordinates:
// 1. Holding position (Wait in phase 1, Idle in phase 2) when enemy ranged firepower is absent or weaker.
// 2. Yielding phase 1 to unacted nearby shieldbearers so shieldbearers engage first.
// 3. Stepping shieldbearers into contact while preserving AP/fatigue to raise Shieldwall the same turn.
// 4. Executing a guaranteed same-turn move-and-attack step when holding and an enemy enters strike budget.
this.bgp_autopilot_frontline <- ::inherit("scripts/ai/tactical/behavior", {
    m = {
        Mode = null,
        TargetTile = null,
        Skill = null,
        WeaponToEquip = null,
        IsMoving = false,
        MovedTileID = -1,
        BlockedRound = -1
    },

    function create()
    {
        this.m.ID = ::Const.AI.Behavior.ID.BGP_Frontline;
        this.m.Order = ::Const.AI.Behavior.Order.BGP_Frontline;
        this.behavior.create();
    }

    function onTurnStarted()
    {
        this.m.Mode = null;
        this.m.TargetTile = null;
        this.m.Skill = null;
        this.m.WeaponToEquip = null;
        this.m.IsMoving = false;
        this.m.MovedTileID = -1;
    }

    function onTurnResumed()
    {
        this.m.Mode = null;
        this.m.TargetTile = null;
        this.m.Skill = null;
        this.m.WeaponToEquip = null;
        this.m.IsMoving = false;
        this.m.MovedTileID = -1;
    }

    function onEvaluate( _entity )
    {
        this.m.Mode = null;
        this.m.TargetTile = null;
        this.m.Skill = null;
        this.m.WeaponToEquip = null;
        this.m.IsMoving = false;

        if (!::Autopilot.isUnderAIControl(_entity) || !::Autopilot.conf("bgpSmartFrontline"))
            return ::Const.AI.Behavior.Score.Zero;
        if (::Tactical.State.isAutoRetreat() || _entity.getMoraleState() == ::Const.MoraleState.Fleeing)
            return ::Const.AI.Behavior.Score.Zero;
        if (_entity.getCurrentProperties().IsStunned || _entity.getActionPoints() < ::Const.Movement.AutoEndTurnBelowAP)
            return ::Const.AI.Behavior.Score.Zero;

        local F = ::BGP.Autopilot.Frontline;
        local agent = this.getAgent();
        local decision = F.shouldActorHold(_entity, agent);
        local info = decision.Info;
        if (info.Enemies.len() == 0)
            return ::Const.AI.Behavior.Score.Zero;

        local myTile = _entity.getTile();
        local inZoC = myTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) > 0;
        local isShield = ::BGP.hasShield(_entity);
        local isRanged = F.isRangedRole(_entity);
        local isCaster = F.isCasterRole(_entity);
        local canWait = ::Tactical.TurnSequenceBar.canEntityWait(_entity);

        // 1. Hold-line phase-1 Wait: hold formation when enemy has no or weaker ranged firepower.
        if (decision.Hold && !inZoC)
        {
            if (canWait && _entity.getActionPoints() >= 4)
            {
                // Lower than attacks/summons/ranged shots (~100-2500), higher than ai_idle (~1).
                this.m.Mode = "wait";
                return 45.0;
            }
            return ::Const.AI.Behavior.Score.Zero;
        }

        // 2. Non-shield melee brothers yield phase 1 to unacted nearby shieldbearers so tanks engage first.
        if (!isShield && !isRanged && !isCaster && !inZoC && canWait && _entity.getActionPoints() >= 4
            && F.hasUnactedShieldAlly(_entity, info))
        {
            this.m.Mode = "wait";
            return 500.0;
        }

        // 2b. Player brother Rotation rescue: pull critically wounded or fragile/Mentor ally out of enemy ZoC.
        local rot = _entity.getSkills().getSkillByID("actives.rotation");
        if (rot != null && !rot.isHidden() && rot.isUsable() && rot.isAffordable()
            && _entity.getHitpointsPct() >= 0.55 && !_entity.getCurrentProperties().IsRooted)
        {
            local myZone = myTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions());
            local bestRotTile = null;
            local bestRotScore = 0.0;
            for (local d = 0; d < 6; ++d)
            {
                if (!myTile.hasNextTile(d)) continue;
                local nt = myTile.getNextTile(d);
                if (!nt.IsOccupiedByActor || !rot.isUsableOn(nt)) continue;
                local ally = nt.getEntity();
                if (ally == null || ::MSU.isNull(ally) || !ally.isAlive() || ally.isDying() || !ally.isAlliedWith(_entity)) continue;
                if (ally.getFaction() != ::Const.Faction.Player) continue;
                local allyZone = nt.getZoneOfControlCountOtherThan(ally.getAlliedFactions());
                if (allyZone <= myZone) continue;
                local allyHP = ally.getHitpointsPct();
                local fragile = F.isRangedRole(ally) || F.isCasterRole(ally);
                if (fragile || allyHP <= 0.50)
                {
                    local s = (fragile ? 930.0 : 880.0) + (1.0 - allyHP) * 180.0;
                    if (s > bestRotScore) { bestRotScore = s; bestRotTile = nt; }
                }
            }
            if (bestRotTile != null)
            {
                this.m.Mode = "rotate_rescue";
                this.m.Skill = rot;
                this.m.TargetTile = bestRotTile;
                return bestRotScore;
            }
        }

        // 2c. Backline kiting retreat for Mentor (caster) or Ranged brothers when a live melee threat closes to <= 2 tiles or Mentor is exposed to heavy archers.
        if ((isCaster || isRanged) && !inZoC && !_entity.getCurrentProperties().IsRooted
            && this.m.BlockedRound != ::Time.getRound() && this.m.MovedTileID == -1)
        {
            local safeTile = F.findBacklineSafeTile(this, _entity, info);
            if (safeTile != null && safeTile.ID != myTile.ID)
            {
                this.m.Mode = "backline_kite";
                this.m.TargetTile = safeTile;
                if (isCaster)
                {
                    local acuteMelee = F.nearestLiveBacklineThreatDist(_entity, info.Enemies) <= 2;
                    return acuteMelee ? 2600.0 : 1400.0;
                }
                return 650.0;
            }
        }

        // 2d. Emergency Switch-to-Melee for ranged brothers caught in melee ZoC with a backup melee weapon in bag.
        if (isRanged && inZoC && _entity.isArmedWithRangedWeapon()
            && !_entity.getSkills().hasSkill("actives.footwork") && !_entity.getSkills().hasSkill("actives.rf_move_under_cover"))
        {
            local backup = F.findBestBagMeleeWeapon(_entity);
            if (backup != null)
            {
                local curMain = _entity.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
                local swapList = curMain != null ? [curMain, backup] : [backup];
                if (_entity.getItems().isActionAffordable(swapList))
                {
                    this.m.Mode = "switch_melee";
                    this.m.WeaponToEquip = backup;
                    return 780.0;
                }
            }
        }

        // 3. Shieldbearer vanguard intercept MUST run before Shieldwall (moving cancels Shieldwall in BB).
        // Never slow-crawl against enemy archers; advance full speed when HoldLine is off and no enemy is within 2 tiles!
        if (isShield && !inZoC && !_entity.getCurrentProperties().IsRooted
            && !_entity.getSkills().hasSkill("effects.shieldwall")
            && this.m.BlockedRound != ::Time.getRound())
        {
            local intercept = F.findShieldInterceptTile(this, _entity, info);
            if (intercept != null && intercept.ID != myTile.ID && intercept.ID != this.m.MovedTileID)
            {
                this.m.Mode = "vanguard_move";
                this.m.TargetTile = intercept;
                return 850.0;
            }
        }

        // 4. Shieldbearer Shieldwall: raise only when truly needed:
        // - >= 2 dangerous adjacent melee enemies, OR
        // - 1 adjacent melee enemy while low HP (<= 45%) or right after a vanguard opening intercept, OR
        // - holding line at distance 2 when >= 2 melee enemies are about to crash in.
        if (isShield && !_entity.getSkills().hasSkill("effects.shieldwall"))
        {
            local sw = _entity.getSkills().getSkillByID("actives.shieldwall");
            if (sw != null && !sw.isHidden() && sw.isUsable() && sw.isAffordable())
            {
                local meleeAdj = F.countDangerousMeleeAdjacent(_entity, info.Enemies);
                local meleeWithin2 = F.countDangerousMeleeWithin(_entity, info.Enemies, 2);
                local zone = myTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions());
                local lowHP = _entity.getHitpointsPct() <= 0.45;
                local justIntercepted = this.m.MovedTileID != -1;
                // Only raise Shieldwall while rooted under fire AFTER Break Free was attempted (<= 5 AP left) so we never block Break Free!
                local rootedUnderFire = _entity.getCurrentProperties().IsRooted && meleeAdj == 0 && info.EnemyProjectileRanged >= 4.0 && _entity.getActionPoints() <= 5;
                // Strict Shieldwall discipline: raise when >= 2 melee adjacent, OR 1 melee adjacent + low HP (<= 45%),
                // OR opening Round 1-2 intercept facing >= 2 enemies within 2 tiles, OR holding line vs >= 2 approaching melee.
                local needSW = (meleeAdj >= 2)
                    || (meleeAdj == 1 && (lowHP || (justIntercepted && ::Time.getRound() <= 2 && meleeWithin2 >= 2)))
                    || (zone == 0 && info.HoldLine && meleeWithin2 >= 2)
                    || rootedUnderFire;
                if (needSW)
                {
                    // Fatigue-disciplined shieldbearer rule: only attack before Shieldwall for a lethal finish
                    // or a very high hit-chance swing with healthy fatigue cushion.
                    local attackFirst = meleeAdj > 0 && !lowHP && F.shouldShieldbearerAttackFirst(_entity, sw, info.Enemies, meleeAdj);
                    if (!attackFirst)
                    {
                        this.m.Mode = "shieldwall";
                        this.m.Skill = sw;
                        return 900.0;
                    }
                }
            }
        }

        // 4b. Indomitable for engaged frontliners facing heavy pressure/bruisers/low HP, OR pre-cast before incoming Orc Charge/Push (distance 2-3)!
        if (!isRanged && !isCaster && !_entity.getSkills().hasSkill("effects.indomitable"))
        {
            local indom = _entity.getSkills().getSkillByID("actives.indomitable");
            if (indom != null && !indom.isHidden() && indom.isUsable() && indom.isAffordable())
            {
                if (inZoC)
                {
                    local meleeAdj = F.countDangerousMeleeAdjacent(_entity, info.Enemies);
                    local heavyAdj = F.hasHeavyMeleeAdjacent(_entity, info.Enemies);
                    local atk = F.cheapestMeleeSkill(_entity);
                    local hasSW = _entity.getSkills().hasSkill("effects.shieldwall");
                    // 2H Greatsword (6 AP) cannot attack + Indomitable (5 AP) in 9 AP: NEVER steal a healthy 2H Greatsword's attack turn unless truly in lethal danger!
                    // 1H Duelist (4 AP) CAN attack (4 AP) + Indomitable (5 AP) = 9 AP, so keep his swing-then-Indomitable combo!
                    local canComboWithAtk = atk != null && (_entity.getActionPointsMax() >= atk.getActionPointCost() + indom.getActionPointCost());
                    local lowHP = _entity.getHitpointsPct() <= (isShield ? 0.50 : (canComboWithAtk ? 0.65 : 0.45));
                    local needIndom = lowHP || (hasSW ? meleeAdj >= 3 : (canComboWithAtk ? (meleeAdj >= 2 || (heavyAdj && _entity.getHitpointsPct() <= 0.80))
                                                                                         : (meleeAdj >= 3 && _entity.getHitpointsPct() <= 0.70)));
                    if (needIndom)
                    {
                        local attackFirst = false;
                        if (!lowHP && !hasSW && atk != null)
                        {
                            local availFat = _entity.getFatigueMax() - _entity.getFatigue();
                            if (F.hasAdjacentTarget(_entity, atk, info.Enemies)
                                && _entity.getActionPoints() >= atk.getActionPointCost() + indom.getActionPointCost()
                                && availFat >= atk.getFatigueCost() + indom.getFatigueCost())
                                attackFirst = true;
                        }
                        if (!attackFirst)
                        {
                            this.m.Mode = "indomitable";
                            this.m.Skill = indom;
                            return 880.0;
                        }
                    }
                }
                else if ((info.HoldLine || (isShield && _entity.getActionPoints() <= 5))
                    && F.hasIncomingChargerWithin(_entity, info.Enemies, 3))
                {
                    // Pre-cast Indomitable ONLY while holding line or with leftover <= 5 AP on a Shieldbearer (never paralyze unengaged 2H/Duelist DPS from walking in to kill Orcs!).
                    local atk = F.cheapestMeleeSkill(_entity);
                    local canHitNow = atk != null && F.hasAdjacentTarget(_entity, atk, info.Enemies);
                    if (!canHitNow)
                    {
                        this.m.Mode = "indomitable";
                        this.m.Skill = indom;
                        return 860.0;
                    }
                }
            }
        }

        // 5. Same-turn step-and-attack when holding line is active and this melee bro has a confirmed strike tile.
        if (info.HoldLine && !isShield && !isRanged && !isCaster && !inZoC && !_entity.getCurrentProperties().IsRooted
            && this.m.BlockedRound != ::Time.getRound() && decision.StrikePlan != null
            && decision.StrikePlan.Tile != null && decision.StrikePlan.Tile.ID != myTile.ID
            && decision.StrikePlan.Tile.ID != this.m.MovedTileID)
        {
            this.m.Mode = "step_attack";
            this.m.TargetTile = decision.StrikePlan.Tile;
            return 320.0;
        }

        return ::Const.AI.Behavior.Score.Zero;
    }

    function onExecute( _entity )
    {
        if (this.m.Mode == "wait")
        {
            this.m.Mode = null;
            if (::Tactical.TurnSequenceBar.canEntityWait(_entity))
            {
                ::Tactical.TurnSequenceBar.entityWaitTurn(_entity);
            }
            return true;
        }

        if (this.m.Mode == "rotate_rescue")
        {
            local rot = this.m.Skill;
            local dest = this.m.TargetTile;
            this.m.Mode = null;
            this.m.Skill = null;
            this.m.TargetTile = null;
            if (rot != null && dest != null && rot.isUsable() && rot.isAffordable() && rot.isUsableOn(dest))
            {
                if (rot.use(dest))
                {
                    if (!_entity.isHiddenToPlayer())
                        this.getAgent().declareAction();
                    if (rot.getDelay() != 0)
                        this.getAgent().declareEvaluationDelay(rot.getDelay());
                }
            }
            return true;
        }

        if (this.m.Mode == "shieldwall" || this.m.Mode == "indomitable")
        {
            local sw = this.m.Skill;
            this.m.Mode = null;
            this.m.Skill = null;
            if (sw != null && sw.isUsable() && sw.isAffordable())
            {
                if (sw.use(_entity.getTile()))
                {
                    if (!_entity.isHiddenToPlayer())
                        this.getAgent().declareAction();
                    if (sw.getDelay() != 0)
                        this.getAgent().declareEvaluationDelay(sw.getDelay());
                }
            }
            return true;
        }

        if (this.m.Mode == "switch_melee")
        {
            local w = this.m.WeaponToEquip;
            this.m.Mode = null;
            this.m.WeaponToEquip = null;
            if (w != null)
            {
                local items = _entity.getItems();
                local curMain = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
                local swapList = curMain != null ? [curMain, w] : [w];
                if (items.isActionAffordable(swapList))
                {
                    items.removeFromBag(w);
                    if (curMain != null)
                    {
                        items.unequip(curMain);
                        items.addToBag(curMain);
                    }
                    items.equip(w);
                    items.payForAction(swapList);
                    this.getAgent().getIntentions().IsChangingWeapons = true;
                }
            }
            return true;
        }

        if (this.m.Mode == "vanguard_move" || this.m.Mode == "step_attack" || this.m.Mode == "backline_kite")
        {
            local navigator = ::Tactical.getNavigator();
            if (this.m.IsFirstExecuted)
            {
                this.m.IsFirstExecuted = false;
                local dest = this.m.TargetTile;
                if (dest == null || !dest.IsEmpty || dest.ID == _entity.getTile().ID)
                {
                    this.m.Mode = null;
                    this.m.TargetTile = null;
                    return true;
                }
                local settings = ::BGP.Autopilot.Frontline.navSettings(_entity, navigator);
                if (!navigator.findPath(_entity.getTile(), dest, settings, 0))
                {
                    this.m.BlockedRound = ::Time.getRound();
                    this.m.Mode = null;
                    this.m.TargetTile = null;
                    return true;
                }
                local cost = navigator.getCostForPath(_entity, settings, _entity.getActionPoints(), _entity.getFatigueMax() - _entity.getFatigue());
                if (cost.Tiles < 1)
                {
                    this.m.BlockedRound = ::Time.getRound();
                    this.m.Mode = null;
                    this.m.TargetTile = null;
                    return true;
                }
                this.getAgent().adjustCameraToTarget(dest);
                this.m.MovedTileID = _entity.getTile().ID;
                this.m.IsMoving = true;
                return false;
            }

            if (this.m.IsMoving)
            {
                if (!navigator.travel(_entity, _entity.getActionPoints(), _entity.getFatigueMax() - _entity.getFatigue()))
                {
                    this.m.IsMoving = false;
                    if (_entity.getTile().ID == this.m.MovedTileID)
                        this.m.BlockedRound = ::Time.getRound();
                    this.m.Mode = null;
                    this.m.TargetTile = null;
                    return true;
                }
                return false;
            }
        }

        this.m.Mode = null;
        this.m.TargetTile = null;
        this.m.Skill = null;
        return true;
    }
});
