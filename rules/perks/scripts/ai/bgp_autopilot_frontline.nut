// Tactical opener, shield-vanguard, kiting, hazard-escape, and rescue behavior for Autopilot-controlled player brothers.
this.bgp_autopilot_frontline <- ::inherit("scripts/ai/tactical/behavior", {
    m = {
        Mode = null,
        TargetTile = null,
        ReapAimTile = null,
        Skill = null,
        WeaponToEquip = null,
        IsMoving = false,
        MovedTileID = -1,
        BlockedRound = -1,
        BashedRound = -1,
        TerrainMovedRound = -1,
        CohesiveMovedRound = -1,
        UphillBaitRound = -1,
        KitedRound = -1,
        HybridSwapRound = -1,
        HybridSwapCount = 0
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
        this.m.ReapAimTile = null;
        this.m.Skill = null;
        this.m.WeaponToEquip = null;
        this.m.IsMoving = false;
        this.m.MovedTileID = -1;
    }

    function onTurnResumed()
    {
        this.m.Mode = null;
        this.m.TargetTile = null;
        this.m.ReapAimTile = null;
        this.m.Skill = null;
        this.m.WeaponToEquip = null;
        this.m.IsMoving = false;
        this.m.MovedTileID = -1;
    }

    function onEvaluate( _entity )
    {
        this.m.Mode = null;
        this.m.TargetTile = null;
        this.m.ReapAimTile = null;
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
        // If a former ranged brother already holds a melee weapon and has 0 ranged ammo left, ensure Autopilot treats them as melee.
        if (("_autopilot" in _entity.m) && _entity.m._autopilot.ranged && !_entity.isArmedWithRangedWeapon() && !F.hasAnyRangedAmmoLeft(_entity))
        {
            _entity.m._autopilot.ranged = false;
            local wMult = "autopilot_mults" in agent ? agent.autopilot_mults : agent.m.Properties.BehaviorMult;
            if (::Const.AI.Behavior.ID.EngageMelee < wMult.len())
                wMult[::Const.AI.Behavior.ID.EngageMelee] = 1.0;
            if (::Const.AI.Behavior.ID.Disengage < wMult.len())
                wMult[::Const.AI.Behavior.ID.Disengage] = 0.35;
        }
        local isRanged = F.isRangedRole(_entity);
        local isCaster = F.isCasterRole(_entity);
        local canWait = ::Tactical.TurnSequenceBar.canEntityWait(_entity);
        local tacticalWait = canWait ? F.evaluateTacticalWait(_entity, info, agent) : null;

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

        // 2b. Player brother Rotation rescue: pull Mentor, fragile backliners, or critically wounded unshielded frontliners out of danger.
        local rot = _entity.getSkills().getSkillByID("actives.rotation");
        if (rot != null && !rot.isHidden() && rot.isUsable() && rot.isAffordable()
            && _entity.getHitpointsPct() >= 0.40 && !_entity.getCurrentProperties().IsRooted)
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
                local allyHP = ally.getHitpointsPct();
                local isMentor = F.isCasterRole(ally);
                local fragile = isMentor || F.isRangedRole(ally);
                local tankSwapDying = isShield && _entity.getHitpointsPct() >= 0.65 && myZone <= 1
                    && !::BGP.hasShield(ally) && allyZone >= 1 && allyZone >= myZone && allyHP <= 0.45;
                if (allyZone <= myZone && !tankSwapDying) continue;
                if (isMentor || tankSwapDying || (_entity.getHitpointsPct() >= 0.55 && (fragile || allyHP <= 0.55)))
                {
                    local s = (isMentor ? 1250.0 : (fragile ? 960.0 : 900.0)) + (1.0 - allyHP) * 180.0;
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

        // 2b-1. Smart Throwing Net on high-threat elites, Mentor-breachers, or flanking melee threats.
        local netPlan = F.findBestNetTarget(_entity, info);
        if (netPlan != null)
        {
            this.m.Mode = "throw_net";
            this.m.Skill = netPlan.Skill;
            this.m.TargetTile = netPlan.Tile;
            return 1650.0;
        }

        // 2b-1b. Immediately re-equip primary weapon from bag if Mainhand is empty (e.g. right after a 2H backliner threw a backpack Net)
        // BEFORE considering unbagging a second net, so backliners never stay bare-handed or dump both nets without shooting!
        if (_entity.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand) == null)
        {
            local reequipWep = F.findReequipMainWeapon(_entity, info);
            if (reequipWep != null)
            {
                this.m.Mode = "reequip_main";
                this.m.WeaponToEquip = reequipWep;
                return 1100.0;
            }
        }

        // 2b-1c. Smart backpack Throwing Net unbagging (including 2H Crossbow/Bow/Polearm backliners) when a high-threat target is in same-turn range!
        local bagNetPlan = F.findBagNetPlan(_entity, info);
        if (bagNetPlan != null)
        {
            this.m.Mode = "unbag_net";
            this.m.WeaponToEquip = bagNetPlan.Net;
            return bagNetPlan.Score;
        }

        // 2b-2. Step out of Miasma / Fire / negative tile effects (2-3 AP) for unengaged living brothers before shooting/casting/attacking!
        if (!inZoC && !_entity.getCurrentProperties().IsRooted
            && this.m.BlockedRound != ::Time.getRound() && this.m.MovedTileID == -1
            && this.hasNegativeTileEffect(myTile, _entity))
        {
            local cleanTile = F.findHazardEscapeTile(this, _entity, info);
            if (cleanTile != null && cleanTile.ID != myTile.ID)
            {
                this.m.Mode = "hazard_step";
                this.m.TargetTile = cleanTile;
                return isCaster ? 1500.0 : (isRanged ? 950.0 : 890.0);
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
                    local threat = F.assessBacklineThreat(_entity, info);
                    local curArch = F.nearestEnemyArcherDist(myTile, info.Enemies);
                    local isGoblinPoisoned = _entity.getSkills().hasSkill("effects.goblin_poison");
                    local lowHpSniper = (_entity.getHitpointsPct() < 0.55 || (isGoblinPoisoned && _entity.getHitpointsPct() < 0.78))
                        && info.EnemyProjectileRanged >= 2.0
                        && curArch <= (info.EnemyProjectileRanged >= 5.0 ? 9 : 7);
                    local deepVolleyZone = (info.EnemyProjectileRanged >= 10.0 && curArch <= 6)
                        || (info.EnemyProjectileRanged >= 5.0 && curArch <= 7 && !F.hasRangedCoverAt(myTile, _entity, info.Enemies, 8));
                    // Threat-tiered Mentor kiting priority:
                    // - Urgent high melee threat (dist <= 2, swarm, or fragile/hurt) OR Mentor HP < 55% (or goblin-poisoned < 78%) inside sniper range:
                    //   2550-2600 (below Lich King & emergency reserve summon, ABOVE routine Curse/CE/Raise so wounded Mentor actually retreats!).
                    // - Inside 6 tiles of 5+ enemy shooters (saturated soft cover like Goblin24): 1750 (cheap 2-AP step back before casting Curse/Raise!).
                    // - Unscreened high melee threat at dist 3 OR healthy Mentor exposed without adjacent ranged cover: 1400.
                    // - Lone low-threat fodder at dist 2 (healthy armored/Nimble Mentor): 950 (cast impactful spells first, sidestep with leftover AP).
                    if (threat.UrgentHigh)
                        return 2600.0;
                    if (lowHpSniper)
                        return 2550.0;
                    if (deepVolleyZone)
                        return 1750.0;
                    if (threat.LowThreatClose && !threat.UnscreenedHigh3)
                        return 950.0;
                    return 1400.0;
                }
                local rThreat = F.assessBacklineThreat(_entity, info);
                return rThreat.UrgentHigh ? 960.0 : 820.0;
            }
        }

        // 2c-2. Critically wounded unshielded melee bro (<= 28% HP, free of ZoC) retreats behind healthy allies to survive!
        if (!inZoC && F.shouldWoundedRetreat(_entity, info)
            && this.m.BlockedRound != ::Time.getRound() && this.m.MovedTileID == -1)
        {
            local retreatTile = F.findWoundedRetreatTile(this, _entity, info);
            if (retreatTile != null && retreatTile.ID != myTile.ID)
            {
                this.m.Mode = "wounded_retreat";
                this.m.TargetTile = retreatTile;
                return 820.0;
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

        // 2d-1b. Late-battle Out-of-Ammo Melee Join: when a ranged brother has 0 ranged ammo left anywhere
        // and enemies are wounded/routing/late-battle, swap to backup melee weapon and join the surround!
        if (isRanged && !inZoC && _entity.isArmedWithRangedWeapon() && F.shouldOutOfAmmoJoinMelee(_entity, info))
        {
            local backup = F.findBestBagMeleeWeapon(_entity);
            if (backup != null)
            {
                local items = _entity.getItems();
                local curMain = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
                local curOff = items.getItemAtSlot(::Const.ItemSlot.Offhand);
                local needDropOff = (curOff != null && backup.getBlockedSlotType() == ::Const.ItemSlot.Offhand);
                local swapList = [];
                if (curMain != null) swapList.push(curMain);
                if (needDropOff) swapList.push(curOff);
                swapList.push(backup);
                if (items.isActionAffordable(swapList) && (!needDropOff || F.emptyBagSlots(items) > 0))
                {
                    this.m.Mode = "out_of_ammo_melee";
                    this.m.WeaponToEquip = backup;
                    return 720.0;
                }
            }
        }

        // 2d-2. Smart Crossbow/Bow <-> Throwing weapon swap for hybrid ranged brothers (perk.rf_hybridization / Quick Hands).
        if (isRanged && !inZoC)
        {
            if (this.m.HybridSwapRound != ::Time.getRound())
            {
                this.m.HybridSwapRound = ::Time.getRound();
                this.m.HybridSwapCount = 0;
            }
            if (this.m.HybridSwapCount < 2)
            {
                local hSwap = F.findHybridRangedSwap(_entity, info);
                if (hSwap != null && (hSwap.EmptyBundle || this.m.HybridSwapCount == 0))
                {
                    this.m.Mode = "hybrid_ranged_swap";
                    this.m.WeaponToEquip = hSwap.Weapon;
                    return hSwap.Score;
                }
            }
        }

        // 2e. Crossbow Take Aim when safe to stand still and shoot.
        if (isRanged && !inZoC && _entity.getActionPoints() >= 9 && !_entity.getSkills().hasSkill("effects.rf_take_aim")
            && F.nearestLiveBacklineThreatDist(_entity, info.Enemies) > 2)
        {
            local takeAim = _entity.getSkills().getSkillByID("actives.rf_take_aim");
            local shoot = _entity.getSkills().getSkillByID("actives.shoot_bolt");
            local availFat = _entity.getFatigueMax() - _entity.getFatigue();
            if (takeAim != null && shoot != null && !takeAim.isHidden() && takeAim.isUsable() && takeAim.isAffordable()
                && !shoot.isHidden() && shoot.isUsable() && shoot.isAffordable()
                && availFat >= takeAim.getFatigueCost() + shoot.getFatigueCost() + 26)
            {
                local needAim = false;
                local maxRng = shoot.getMaxRange();
                foreach (foe in info.Enemies)
                {
                    if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                    local ft = foe.getTile();
                    local dist = myTile.getDistanceTo(ft);
                    if (dist < 2 || dist > maxRng || !shoot.isUsableOn(ft, myTile)) continue;
                    // Check if at least one actor stands adjacent to target blocking line of fire (classic zombie-wall cover).
                    local blocked = false;
                    for (local d = 0; d < 6; ++d)
                    {
                        if (!ft.hasNextTile(d)) continue;
                        local bt = ft.getNextTile(d);
                        if (bt.IsOccupiedByActor && bt.getDistanceTo(myTile) < dist) { blocked = true; break; }
                    }
                    if (!blocked) continue;
                    local fs = foe.getSkills();
                    local isPriest = fs.hasSkill("actives.horror") || fs.hasSkill("actives.miasma");
                    // Don't spend 25 fatigue sniping armored regular skeletons that take reduced ranged damage.
                    if (foe.getFlags().has("skeleton") && !isPriest && foe.getArmor(::Const.BodyPart.Body) >= 120) continue;
                    local isHVT = isPriest || foe.isArmedWithRangedWeapon() || fs.hasSkill("racial.champion")
                        || fs.hasSkill("actives.raise_undead") || fs.hasSkill("actives.root")
                        || fs.hasSkill("actives.rally_the_troops") || foe.ClassName == "rf_banshee"
                        || foe.ClassName == "orc_berserker" || foe.ClassName == "desert_stalker"
                        || foe.ClassName == "rf_marshal" || foe.ClassName == "rf_skeleton_legatus"
                        || foe.getHitpointsPct() <= 0.50;
                    if (isHVT) { needAim = true; break; }
                }
                if (needAim)
                {
                    this.m.Mode = "take_aim";
                    this.m.Skill = takeAim;
                    return 620.0;
                }
            }
        }

        // 3. Shieldbearer vanguard intercept (prioritizes pinning enemy elites and screening Mentor/fragiles)
        // arbitrated cleanly against early Spearwall.
        local interceptPlan = null;
        if (isShield && !inZoC && !_entity.getCurrentProperties().IsRooted
            && !_entity.getSkills().hasSkill("effects.shieldwall")
            && !_entity.getSkills().hasSkill("effects.spearwall")
            && this.m.BlockedRound != ::Time.getRound())
        {
            interceptPlan = F.findShieldInterceptTile(this, _entity, info);
        }

        if (interceptPlan != null && interceptPlan.Urgent
            && interceptPlan.Tile.ID != myTile.ID && interceptPlan.Tile.ID != this.m.MovedTileID)
        {
            this.m.Mode = "vanguard_move";
            this.m.TargetTile = interceptPlan.Tile;
            return 885.0;
        }

        // 3a. Early Spearwall opener against approaching non-charger melee enemies when no urgent elite/Mentor intercept is needed.
        if (isShield && !inZoC && !_entity.getSkills().hasSkill("effects.spearwall") && !_entity.getSkills().hasSkill("effects.shieldwall")
            && info.EnemyProjectileRanged < 3.0 && info.EnemyChargers < 3 && ::Time.getRound() <= 3)
        {
            local spw = _entity.getSkills().getSkillByID("actives.spearwall");
            if (spw != null && !spw.isHidden() && spw.isUsable() && spw.isAffordable())
            {
                local meleeDist23 = F.countDangerousMeleeWithin(_entity, info.Enemies, 3);
                local availFat = _entity.getFatigueMax() - _entity.getFatigue();
                if (meleeDist23 >= 2 && availFat >= spw.getFatigueCost() + 24)
                {
                    this.m.Mode = "spearwall";
                    this.m.Skill = spw;
                    return 870.0;
                }
            }
        }

        if (interceptPlan != null && interceptPlan.Tile.ID != myTile.ID && interceptPlan.Tile.ID != this.m.MovedTileID)
        {
            this.m.Mode = "vanguard_move";
            this.m.TargetTile = interceptPlan.Tile;
            return 850.0;
        }

        // 3b. Uphill-bait stand-off & Initiative-aware Shieldbearer Wait:
        // When no equal-elevation intercept exists and uphill melee/polearm enemies sit above us:
        //   - If enemy archers already shot in Phase 1 (wait_shield_read), wait first so uphill enemies step down before we commit!
        //   - Otherwise step cleanly to dist 2 from uphill 1-tile melee (dist 3 from uphill 2-tile polearms) retaining Shieldwall AP!
        local uphillBaitPlan = null;
        if (!inZoC && !isRanged && !isCaster && !_entity.getCurrentProperties().IsRooted
            && !_entity.getSkills().hasSkill("effects.shieldwall")
            && !_entity.getSkills().hasSkill("effects.spearwall")
            && this.m.BlockedRound != ::Time.getRound())
        {
            uphillBaitPlan = F.findUphillBaitTile(this, _entity, info);
        }

        // If Shieldbearer can safely wait in Phase 1 (0 unacted enemy archers left!) before moving/shieldwalling, read enemy movement first!
        if (isShield && !inZoC && tacticalWait != null && tacticalWait.Reason == "wait_shield_read")
        {
            this.m.Mode = "wait";
            return tacticalWait.Score;
        }

        // Shieldbearer uphill-bait step (move to dist 2 vs 1-tile uphill melee / dist 3 vs uphill polearm, then follow up with Shieldwall!).
        if (isShield && uphillBaitPlan != null && !uphillBaitPlan.HoldHere
            && uphillBaitPlan.Tile.ID != myTile.ID && uphillBaitPlan.Tile.ID != this.m.MovedTileID
            && this.m.UphillBaitRound != ::Time.getRound())
        {
            this.m.Mode = "uphill_bait";
            this.m.TargetTile = uphillBaitPlan.Tile;
            return 840.0;
        }

        // 3c. Reforged Shield Bash on undazed heavy melee threats (once per round).
        if (isShield && inZoC && _entity.getHitpointsPct() >= 0.45 && this.m.BashedRound != ::Time.getRound())
        {
            local bash = _entity.getSkills().getSkillByID("actives.rf_shield_bash");
            if (bash != null && !bash.isHidden() && bash.isUsable() && bash.isAffordable())
            {
                local sw = _entity.getSkills().getSkillByID("actives.shieldwall");
                local hasSW = _entity.getSkills().hasSkill("effects.shieldwall");
                local meleeAdj = F.countDangerousMeleeAdjacent(_entity, info.Enemies);
                local availFat = _entity.getFatigueMax() - _entity.getFatigue();
                local canFollowSW = hasSW
                    || (meleeAdj <= 1 && availFat >= bash.getFatigueCost() + 18)
                    || (sw != null && !sw.isHidden() && sw.isUsable()
                        && _entity.getActionPoints() >= bash.getActionPointCost() + sw.getActionPointCost()
                        && availFat >= bash.getFatigueCost() + sw.getFatigueCost() + 14);
                if (canFollowSW)
                {
                    local bestBashTile = null;
                    local bestBashScore = 0.0;
                    foreach (foe in info.Enemies)
                    {
                        if (!F.isHeavyMeleeThreat(foe)) continue;
                        if (foe.getCurrentProperties().IsImmuneToDaze || foe.getSkills().hasSkill("effects.dazed")) continue;
                        if (!foe.getSkills().hasSkill("racial.champion") && foe.getHitpointsPct() < 0.35) continue;
                        local ft = foe.getTile();
                        if (myTile.getDistanceTo(ft) != 1 || !bash.isUsableOn(ft, myTile)) continue;
                        local hit = 0;
                        try { hit = bash.getHitchance(foe); } catch (e) {}
                        if (hit < 50) continue;
                        local stB = F.enemyLiveStats(foe);
                        local sc = hit + (foe.getSkills().hasSkill("racial.champion") ? 45.0 : 20.0) + (foe.getHitpointsPct() >= 0.50 ? 15.0 : 0.0);
                        // Prioritize dazing enemies BEFORE they act this round, especially high relative hit-chance attackers!
                        if (stB.CanActThisRound) sc += (stB.TurnsUntil <= 3 ? 28.0 : 18.0);
                        else sc -= 20.0;
                        if (F.enemyEffectiveHitOn(foe, _entity) >= 50) sc += 14.0;
                        if (sc > bestBashScore) { bestBashScore = sc; bestBashTile = ft; }
                    }
                    if (bestBashTile != null)
                    {
                        this.m.Mode = "shield_bash";
                        this.m.Skill = bash;
                        this.m.TargetTile = bestBashTile;
                        // Higher than Shieldwall (900) when we still have AP to Bash (4 AP) + Shieldwall (4 AP) in the same turn!
                        return 915.0;
                    }
                }
            }
        }

        // 4. Shieldbearer Shieldwall under melee pressure or rooted ranged fire
        // (skipped when peeling an enemy currently engaged in melee with Mentor so the shieldbearer attacks immediately!).
        if (isShield && !_entity.getSkills().hasSkill("effects.shieldwall") && !F.isPeelingMentorMelee(_entity, info))
        {
            local sw = _entity.getSkills().getSkillByID("actives.shieldwall");
            if (sw != null && !sw.isHidden() && sw.isUsable() && sw.isAffordable())
            {
                local meleeAdj = F.countDangerousMeleeAdjacent(_entity, info.Enemies);
                local meleeWithin2 = F.countDangerousMeleeWithin(_entity, info.Enemies, 2);
                local zone = myTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions());
                local lowHP = _entity.getHitpointsPct() <= 0.45;
                local justIntercepted = this.m.MovedTileID != -1;
                local rootedUnderFire = _entity.getCurrentProperties().IsRooted && meleeAdj == 0 && info.EnemyProjectileRanged >= 4.0 && _entity.getActionPoints() <= 5;
                local eliteAdj = false;
                foreach (foe in info.Enemies)
                {
                    if (myTile.getDistanceTo(foe.getTile()) == 1 && ::Math.abs(myTile.Level - foe.getTile().Level) <= 1
                        && F.enemyEliteScore(foe, info) >= 1.5)
                    {
                        eliteAdj = true;
                        break;
                    }
                }
                local uphillBaitSW = (zone == 0 && uphillBaitPlan != null && uphillBaitPlan.HoldHere && uphillBaitPlan.NeedsShieldwall);
                local needSW = (meleeAdj >= 2)
                    || (meleeAdj == 1 && (lowHP || (::Time.getRound() <= 2 && meleeWithin2 >= 2)
                        || (eliteAdj && (justIntercepted || _entity.getCurrentProperties().getMeleeDefense() < 35))))
                    || (zone == 0 && info.HoldLine && meleeWithin2 >= 2)
                    || (zone == 0 && ::Time.getRound() <= 2 && info.HybridRangedHeavyMelee && (justIntercepted || _entity.getActionPoints() <= 5))
                    || uphillBaitSW
                    || rootedUnderFire;
                // Skip pointless Shieldwall when engaged but ZERO adjacent/reach foes can attack before our next turn!
                if (needSW && inZoC && !(info.EnemyProjectileRanged >= 4.0 && _entity.getHitpointsPct() <= 0.65))
                {
                    if (F.hasThreatBeforeNextTurn(_entity, info.Enemies).Count == 0)
                        needSW = false;
                }
                if (needSW)
                {
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

        // 4b. Indomitable under heavy melee pressure or incoming chargers.
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
                    // Only combine attack + Indomitable when weapon AP and Indomitable AP fit in one turn.
                    local canComboWithAtk = atk != null && (_entity.getActionPointsMax() >= atk.getActionPointCost() + indom.getActionPointCost());
                    local lowHP = _entity.getHitpointsPct() <= (isShield ? 0.50 : (canComboWithAtk ? 0.65 : 0.45));
                    local needIndom = lowHP || (hasSW ? meleeAdj >= 3 : (canComboWithAtk ? (meleeAdj >= 2 || (heavyAdj && _entity.getHitpointsPct() <= 0.80))
                                                                                         : (meleeAdj >= 3 && _entity.getHitpointsPct() <= 0.70)));
                    if (needIndom && !(info.EnemyProjectileRanged >= 4.0 && _entity.getHitpointsPct() <= 0.55))
                    {
                        if (F.hasThreatBeforeNextTurn(_entity, info.Enemies).Count == 0)
                            needIndom = false;
                    }
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

        // 4b-2. Initiative & Turn-Order Tactical Wait (safe in-ZoC armor-strip/surround combo wait, buff-expire wait,
        // unengaged surround/focus-fire wait, first-strike/uphill bait wait, or ranged wait-for-range):
        // Runs strictly AFTER rescues, nets, kiting, Mentor peels, Shield Bash, Shieldwall, Indomitable, and Spearwall!
        if (tacticalWait != null)
        {
            this.m.Mode = "wait";
            return tacticalWait.Score;
        }

        // 4c. High-priority terrain positioning (climb high ground or leave Swamp/bad terrain) BEFORE waiting/holding (at most once per round).
        // Disabled against urgent enemy casters (Ancient Priests / Necromancers) and in late-battle cleanup so assaults never stall.
        local terrainPlan = null;
        if (!inZoC && !_entity.getCurrentProperties().IsRooted
            && info.EnemyUrgentCasters == 0 && ::Time.getRound() < 10
            && !_entity.getSkills().hasSkill("effects.shieldwall")
            && !_entity.getSkills().hasSkill("effects.spearwall")
            && this.m.BlockedRound != ::Time.getRound()
            && this.m.TerrainMovedRound != ::Time.getRound()
            && this.m.MovedTileID == -1)
        {
            terrainPlan = F.findTacticalTerrainTile(this, _entity, info);
            if (terrainPlan != null && terrainPlan.HighPriority && terrainPlan.Tile.ID != myTile.ID)
            {
                this.m.Mode = "terrain_anchor";
                this.m.TargetTile = terrainPlan.Tile;
                return 545.0;
            }
        }

        // 4d. Zero-friendly-fire Step-and-Reap for 2-tile polearms (Warscythe / Swordlance / Scythe):
        // steps 1-2 safe non-ZoC tiles (using dynamic previewSkillCostsAfterMove for Polearm Mastery / Vigorous Assault)
        // to line up a clean 2-3 enemy Reap arc with ZERO allied hits!
        if (!inZoC && !isRanged && !isCaster && !_entity.getCurrentProperties().IsRooted
            && _entity.getSkills().hasSkill("actives.reap")
            && this.m.BlockedRound != ::Time.getRound())
        {
            local reapPlan = F.findBestReapPlan(this, _entity, info);
            if (reapPlan != null && reapPlan.NeedsMove
                && reapPlan.OriginTile.ID != myTile.ID && reapPlan.OriginTile.ID != this.m.MovedTileID)
            {
                this.m.Mode = "step_reap";
                this.m.TargetTile = reapPlan.OriginTile;
                this.m.ReapAimTile = reapPlan.AimTile;
                this.m.Skill = reapPlan.Skill;
                return reapPlan.Score;
            }
        }

        // 5. Dynamic safe melee routing for unshielded 1-tile DPS: prefer flanking weaker/pinned enemies with allies,
        // and Wait rather than diving solo into snow/surrounds with zero attacks left.
        if (!isShield && !isRanged && !isCaster && !inZoC && !_entity.getCurrentProperties().IsRooted)
        {
            local chkAtk = F.cheapestMeleeSkill(_entity);
            if (this.m.BlockedRound != ::Time.getRound() && this.m.MovedTileID == -1)
            {
                local smartPlan = F.findSmartDpsMeleeTile(this, _entity, info);
                if (smartPlan != null && smartPlan.Tile != null && smartPlan.Tile.ID != myTile.ID)
                {
                    this.m.Mode = "dynamic_melee_move";
                    this.m.TargetTile = smartPlan.Tile;
                    return smartPlan.ChiefPeel ? 780.0 : 520.0;
                }
                if (info.HoldLine && decision.StrikePlan != null
                    && decision.StrikePlan.Tile != null && decision.StrikePlan.Tile.ID != myTile.ID
                    && !F.isSuicidalDiveV2(_entity, decision.StrikePlan.Tile, info, decision.StrikePlan.APAfter, decision.StrikePlan.EffAP))
                {
                    this.m.Mode = "step_attack";
                    this.m.TargetTile = decision.StrikePlan.Tile;
                    return 320.0;
                }
            }
            // Only true low-MDef 1H fragile DPS wait when facing non-caster, non-charger, non-ranged melee waves
            // (never freeze 2H heavy frontliners, polearms, or assaults vs Ancient Priests / Necromancers / charging Orcs!).
            if (canWait && F.isFragileMelee(_entity) && _entity.getCurrentProperties().getMeleeDefense() < 18
                && _entity.getActionPoints() >= 4 && ::Time.getRound() < 12
                && info.EnemyProjectileRanged < 3.0 && info.EnemyUrgentCasters == 0 && info.EnemyChargers < 3
                && (chkAtk == null || (chkAtk.getMaxRange() <= 1 && chkAtk.getActionPointCost() <= 4 && !F.hasAdjacentTarget(_entity, chkAtk, info.Enemies)))
                && F.nearestDangerousMeleeDist(_entity, info.Enemies) <= 5)
            {
                this.m.Mode = "wait";
                return 480.0;
            }
        }

        // 5b. No-ranged melee discipline: when enemy has ZERO ranged units (no archers/crossbows/javelins) and no Miasma/Horror priests,
        // wait in Phase 1 during early/mid engagements whenever an unengaged melee brother cannot strike this turn (lets Zombies/melee walk into OUR first-strike range!).
        if (info.NoEnemyRanged && !isRanged && !isCaster && !inZoC && canWait && ::Time.getRound() <= 8
            && _entity.getActionPoints() >= 4 && !F.hasBacklineBreach(info))
        {
            local strikeNow = F.findSameTurnStrikePlan(_entity, info.Enemies);
            if (strikeNow == null)
            {
                this.m.Mode = "wait";
                return 480.0;
            }
        }

        // 5c-0. Unshielded melee uphill-bait stand-off (stop at dist 2 from uphill 1-tile melee / dist 3 from uphill polearms).
        if (!isShield && uphillBaitPlan != null && !uphillBaitPlan.HoldHere
            && uphillBaitPlan.Tile.ID != myTile.ID && uphillBaitPlan.Tile.ID != this.m.MovedTileID
            && this.m.UphillBaitRound != ::Time.getRound())
        {
            this.m.Mode = "uphill_bait";
            this.m.TargetTile = uphillBaitPlan.Tile;
            return 430.0;
        }

        // 5c. Cohesive R1-R2 advance against hybrid heavy-ranged + strong-melee armies (Nomads/Nobles/Southern armies):
        // Shieldbearers advance 1-2 tiles retaining Shieldwall AP; unshielded melee advance 1-2 tiles right behind/beside them with cover!
        if (!inZoC && !isRanged && !isCaster && !_entity.getCurrentProperties().IsRooted
            && ::Time.getRound() <= 2 && info.HybridRangedHeavyMelee && !info.HoldLine
            && !_entity.getSkills().hasSkill("effects.shieldwall")
            && !_entity.getSkills().hasSkill("effects.spearwall")
            && this.m.BlockedRound != ::Time.getRound() && this.m.MovedTileID == -1)
        {
            local advTile = F.findCohesiveAdvanceTile(this, _entity, info);
            if (advTile != null && advTile.ID != myTile.ID)
            {
                this.m.Mode = "cohesive_advance";
                this.m.TargetTile = advTile;
                return 410.0;
            }
        }

        // 6. Lower-priority terrain anchor (chokepoint / flank anchoring ONLY when otherwise idle; score 90 never overrides EngageMelee assaults).
        if (terrainPlan != null && terrainPlan.Tile.ID != myTile.ID && info.EnemyChargers < 3 && ::Time.getRound() <= 4)
        {
            this.m.Mode = "terrain_anchor";
            this.m.TargetTile = terrainPlan.Tile;
            return 90.0;
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

        if (this.m.Mode == "shieldwall" || this.m.Mode == "indomitable" || this.m.Mode == "spearwall" || this.m.Mode == "take_aim")
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

        if (this.m.Mode == "throw_net")
        {
            local net = this.m.Skill;
            local dest = this.m.TargetTile;
            this.m.Mode = null;
            this.m.Skill = null;
            this.m.TargetTile = null;
            if (net != null && dest != null && net.isUsable() && net.isAffordable() && net.isUsableOn(dest))
            {
                if (net.use(dest))
                {
                    if (!_entity.isHiddenToPlayer())
                        this.getAgent().declareAction();
                    if (net.getDelay() != 0)
                        this.getAgent().declareEvaluationDelay(net.getDelay());
                }
            }
            return true;
        }

        if (this.m.Mode == "shield_bash")
        {
            local bash = this.m.Skill;
            local dest = this.m.TargetTile;
            this.m.Mode = null;
            this.m.Skill = null;
            this.m.TargetTile = null;
            if (bash != null && dest != null && bash.isUsable() && bash.isAffordable() && bash.isUsableOn(dest))
            {
                this.m.BashedRound = ::Time.getRound();
                if (bash.use(dest))
                {
                    if (!_entity.isHiddenToPlayer())
                        this.getAgent().declareAction();
                    if (bash.getDelay() != 0)
                        this.getAgent().declareEvaluationDelay(bash.getDelay());
                }
            }
            return true;
        }

        if (this.m.Mode == "unbag_net")
        {
            local net = this.m.WeaponToEquip;
            this.m.Mode = null;
            this.m.WeaponToEquip = null;
            if (net != null)
            {
                local items = _entity.getItems();
                local curMain = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
                local curOff = items.getItemAtSlot(::Const.ItemSlot.Offhand);
                local needDropMain = (curMain != null && curMain.getBlockedSlotType() == ::Const.ItemSlot.Offhand);
                local swapList = needDropMain ? [curMain, net] : [net];
                if (items.isActionAffordable(swapList))
                {
                    items.removeFromBag(net);
                    if (needDropMain)
                    {
                        items.unequip(curMain);
                        items.addToBag(curMain);
                    }
                    if (curOff != null)
                    {
                        items.unequip(curOff);
                        items.addToBag(curOff);
                    }
                    items.equip(net);
                    items.payForAction(swapList);
                    this.getAgent().getIntentions().IsChangingWeapons = true;
                }
            }
            return true;
        }

        if (this.m.Mode == "switch_melee" || this.m.Mode == "out_of_ammo_melee" || this.m.Mode == "hybrid_ranged_swap" || this.m.Mode == "reequip_main")
        {
            local isHybrid = (this.m.Mode == "hybrid_ranged_swap");
            local isOutOfAmmo = (this.m.Mode == "out_of_ammo_melee");
            local w = this.m.WeaponToEquip;
            this.m.Mode = null;
            this.m.WeaponToEquip = null;
            if (w != null)
            {
                local items = _entity.getItems();
                local curMain = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
                local curOff = items.getItemAtSlot(::Const.ItemSlot.Offhand);
                local needDropOff = (curOff != null && w.getBlockedSlotType() == ::Const.ItemSlot.Offhand);
                local swapList = [];
                if (curMain != null) swapList.push(curMain);
                if (needDropOff) swapList.push(curOff);
                swapList.push(w);
                if (items.isActionAffordable(swapList) && (!needDropOff || ::BGP.Autopilot.Frontline.emptyBagSlots(items) > 0))
                {
                    items.removeFromBag(w);
                    if (curMain != null)
                    {
                        items.unequip(curMain);
                        items.addToBag(curMain);
                    }
                    if (needDropOff)
                    {
                        items.unequip(curOff);
                        items.addToBag(curOff);
                    }
                    items.equip(w);
                    items.payForAction(swapList);
                    local ag = this.getAgent();
                    ag.getIntentions().IsChangingWeapons = true;
                    if (isOutOfAmmo)
                    {
                        if ("_autopilot" in _entity.m)
                            _entity.m._autopilot.ranged = false;
                        local wMult = "autopilot_mults" in ag ? ag.autopilot_mults : ag.m.Properties.BehaviorMult;
                        if (::Const.AI.Behavior.ID.EngageMelee < wMult.len())
                            wMult[::Const.AI.Behavior.ID.EngageMelee] = 1.0;
                        if (::Const.AI.Behavior.ID.Disengage < wMult.len())
                            wMult[::Const.AI.Behavior.ID.Disengage] = 0.35;
                        if (ag.getBehavior(::Const.AI.Behavior.ID.EngageMelee) == null)
                        {
                            ag.addBehavior(::new("scripts/ai/tactical/behaviors/ai_engage_melee"));
                            ag.finalizeBehaviors();
                        }
                    }
                    if (isHybrid)
                    {
                        if (this.m.HybridSwapRound != ::Time.getRound())
                        {
                            this.m.HybridSwapRound = ::Time.getRound();
                            this.m.HybridSwapCount = 0;
                        }
                        ++this.m.HybridSwapCount;
                    }
                }
            }
            return true;
        }

        if (this.m.Mode == "step_reap")
        {
            local navigator = ::Tactical.getNavigator();
            if (this.m.IsFirstExecuted)
            {
                this.m.IsFirstExecuted = false;
                local dest = this.m.TargetTile;
                if (dest == null || dest.ID == _entity.getTile().ID)
                {
                    this.m.IsMoving = false;
                    return false;
                }
                if (!dest.IsEmpty)
                {
                    this.m.Mode = null;
                    this.m.TargetTile = null;
                    this.m.ReapAimTile = null;
                    this.m.Skill = null;
                    return true;
                }
                local settings = ::BGP.Autopilot.Frontline.navSettings(_entity, navigator);
                if (!navigator.findPath(_entity.getTile(), dest, settings, 0))
                {
                    this.m.BlockedRound = ::Time.getRound();
                    this.m.Mode = null;
                    this.m.TargetTile = null;
                    this.m.ReapAimTile = null;
                    this.m.Skill = null;
                    return true;
                }
                local cost = navigator.getCostForPath(_entity, settings, _entity.getActionPoints(), _entity.getFatigueMax() - _entity.getFatigue());
                if (cost.Tiles < 1)
                {
                    this.m.BlockedRound = ::Time.getRound();
                    this.m.Mode = null;
                    this.m.TargetTile = null;
                    this.m.ReapAimTile = null;
                    this.m.Skill = null;
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
                    {
                        this.m.BlockedRound = ::Time.getRound();
                        this.m.Mode = null;
                        this.m.TargetTile = null;
                        this.m.ReapAimTile = null;
                        this.m.Skill = null;
                        return true;
                    }
                    return false;
                }
                return false;
            }

            local skill = this.m.Skill;
            local aim = this.m.ReapAimTile;
            local curTile = _entity.getTile();
            this.m.Mode = null;
            this.m.TargetTile = null;
            this.m.ReapAimTile = null;
            this.m.Skill = null;
            if (skill != null && aim != null && skill.isUsable() && skill.isAffordable() && skill.isUsableOn(aim, curTile))
            {
                // Re-verify strict zero friendly fire from actual post-move tile before executing!
                local chk = ::BGP.Autopilot.Frontline.evaluateAoEStrike(_entity, curTile, aim, skill, null, 2);
                if (chk.AlliesHit == 0 && chk.ActiveEnemies >= 2)
                {
                    if (skill.use(aim))
                    {
                        if (!_entity.isHiddenToPlayer())
                            this.getAgent().declareAction();
                        if (skill.getDelay() != 0)
                            this.getAgent().declareEvaluationDelay(skill.getDelay());
                    }
                }
            }
            return true;
        }

        if (this.m.Mode == "vanguard_move" || this.m.Mode == "uphill_bait" || this.m.Mode == "cohesive_advance" || this.m.Mode == "dynamic_melee_move" || this.m.Mode == "wounded_retreat" || this.m.Mode == "terrain_anchor" || this.m.Mode == "step_attack" || this.m.Mode == "backline_kite" || this.m.Mode == "hazard_step")
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
                if (this.m.Mode == "terrain_anchor")
                    this.m.TerrainMovedRound = ::Time.getRound();
                else if (this.m.Mode == "cohesive_advance")
                    this.m.CohesiveMovedRound = ::Time.getRound();
                else if (this.m.Mode == "uphill_bait")
                    this.m.UphillBaitRound = ::Time.getRound();
                else if (this.m.Mode == "backline_kite" || this.m.Mode == "hazard_step")
                    this.m.KitedRound = ::Time.getRound();
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
