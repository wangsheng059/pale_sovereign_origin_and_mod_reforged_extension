// 召唤僵尸 / 召唤骷髅：在相邻空格召出一名临时亡灵仆从（战斗结束后消散）
// 1.6.8：召出的仆从必定有武器和护甲；施法者学会“死灵精通”后召出更强的种类、换上更好的装备；
// 1.6.9：学会第 7 阶特技（不灭勇士、尸爆或亡灵法术大师）后再升一档；
//        亡灵法师导师默认每场免费各 1 次，学会亡灵法术大师后各 +1（共 2 次）；普通死灵法师学会亡灵法术大师后解锁各 1 次
this.pale_summon_undead <- ::inherit("scripts/skills/skill", {
    m = {
        Script = "", MasteryScript = "", EliteScript = "", MinionName = "", MasteryName = "", EliteName = "", ForNecromancers = false,
        Gear = null, MasteryGear = null, EliteGear = null, Used = false, FreeUsed = 0, ArtStem = "", FearInsteadOfOverwhelm = false, EliteExtraSkills = null, EliteExtraText = ""
    },
    function create()
    {
        if (this.m.DamageType == null)
            this.m.DamageType = ::MSU.Class.DamageType();
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.UtilityTargeted;
        this.m.SoundOnUse = ["sounds/enemies/necromancer_01.wav", "sounds/enemies/necromancer_02.wav", "sounds/enemies/necromancer_03.wav"];
        this.m.SoundVolume = 1.2;
        this.m.Overlay = "";
        this.m.IsSerialized = false;
        this.m.IsActive = true;
        this.m.IsTargeted = true;
        this.m.IsTargetingActor = false;
        this.m.IsVisibleTileNeeded = false;
        this.m.IsStacking = false;
        this.m.IsAttack = false;
        this.m.IsIgnoredAsAOO = true;
        this.m.ActionPointCost = 4;
        this.m.FatigueCost = 20;
        this.m.MinRange = 1;
        this.m.MaxRange = 1;
    }

    function hasMastery()
    {
        return this.getContainer().getActor().getSkills().hasSkill("perk.bgp_necro_mastery");
    }

    // 0 = 基础，1 = 死灵精通（第 4 阶），2 = 第 7 阶（不灭勇士 / 尸爆 / 亡灵法术大师）
    function getRank()
    {
        local skills = this.getContainer().getActor().getSkills();
        if (skills.hasSkill("perk.bgp_necro_undying_champion") || skills.hasSkill("perk.bgp_corpse_explosion") || skills.hasSkill("perk.bgp_necro_grandmaster"))
            return 2;
        return skills.hasSkill("perk.bgp_necro_mastery") ? 1 : 0;
    }

    function isChiefCaster( _actor )
    {
        if (_actor == null)
            return false;
        local s = ::PaleSovereign;
        return (s.isActive() && s.isChief(_actor)) || _actor.getSkills().hasSkill("background.pale_necromancer");
    }

    function getFreeUses()
    {
        local container = this.getContainer();
        local actor = container == null ? null : container.getActor();
        if (actor == null)
            return 0;
        local baseUses = this.isChiefCaster(actor) ? 1 : 0;
        local bonus = actor.getSkills().hasSkill("perk.bgp_necro_grandmaster") ? 1 : 0;
        return baseUses + bonus;
    }

    function hasFreeUseLeft()
    {
        return this.m.FreeUsed < this.getFreeUses();
    }

    function getTooltip()
    {
        local ret = this.skill.getDefaultUtilityTooltip();
        local rank = this.getRank();
        local names = [this.m.MinionName, this.m.MasteryName, this.m.EliteName];
        ret.push({ id = 10, type = "text", icon = "ui/backgrounds/" + this.m.ArtStem + "_" + rank + ".png",
            text = "在相邻的空格召出一名" + names[rank] + "，自带武器和护甲，由 AI 控制，战斗结束后消散" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "学会亡灵法术精通（第 4 阶）后召出" + this.m.MasteryName + (rank >= 1 ? "（已生效）" : "")
            + "；学会第 7 阶特技（不灭勇士、尸爆或亡灵法术大师）后召出" + this.m.EliteName + (rank >= 2 ? "（已生效）" : "") });
        if (this.m.FearInsteadOfOverwhelm)
            ret.push({ id = 14, type = "text", icon = "ui/icons/special.png", text = "召出的僵尸用“恐惧”取代“压制”，决心为施法者当前决心的一半，可获得战旗加成" });
        if (this.m.EliteExtraText != "")
            ret.push({ id = 15, type = "text", icon = "ui/icons/special.png", text = this.m.EliteExtraText });
        local actor = this.getContainer().getActor();
        local isChief = this.isChiefCaster(actor);
        local freeMax = this.getFreeUses();
        local freeLeft = ::Math.max(0, freeMax - this.m.FreeUsed);
        local grandTag = freeMax > (isChief ? 1 : 0) ? (isChief ? "（亡灵法术大师 +1）" : "（亡灵法术大师解锁）") : "";
        ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "每场战斗免费施放 " + freeMax + " 次" + grandTag + (this.m.FreeUsed > 0 ? "，剩余 " + freeLeft + " 次" : "") });
        local s = ::PaleSovereign;
        if (s.isActive() && s.isChief(actor))
            ret.push({ id = 16, type = "text", icon = "ui/icons/special.png", text = "耗骸续召：免费次数用完后可再消耗 " + s.ExtraSummonCost + " 点防腐尸骸追加施放，每场共 " + s.extraSummonCap() + " 次（两种召唤共用）；续召仆从所穿戴的头甲、身甲各 +25 临时护甲" });
        if (!this.hasFreeUseLeft())
            ret.push({ id = 13, type = "text", icon = "ui/icons/warning.png", text = s.canExtraSummon(actor) ? "本场免费次数已用完，可耗骸续召" : "本场免费次数已用完" });
        return ret;
    }

    function isHidden()
    {
        local container = this.getContainer();
        local actor = container == null ? null : container.getActor();
        if (actor == null)
            return true;
        if (this.isChiefCaster(actor))
            return false;
        return !actor.getSkills().hasSkill("perk.bgp_necro_grandmaster");
    }

    function isUsable()
    {
        return !this.isHidden() && (this.hasFreeUseLeft() || ::PaleSovereign.canExtraSummon(this.getContainer().getActor())) && this.skill.isUsable();
    }

    function onCombatStarted()
    {
        this.m.Used = false;
        this.m.FreeUsed = 0;
    }

    function onCombatFinished()
    {
        this.m.Used = false;
        this.m.FreeUsed = 0;
    }

    function onVerifyTarget( _originTile, _targetTile )
    {
        return this.skill.onVerifyTarget(_originTile, _targetTile) && _targetTile.IsEmpty;
    }

    // 某一栏没有装备时，从列表里随机挑一件能生成的
    function equipFrom( _e, _slot, _paths )
    {
        local items = _e.getItems();
        if (_paths == null || _paths.len() == 0 || items.getItemAtSlot(_slot) != null)
            return;
        local pool = clone _paths;
        while (pool.len() > 0)
        {
            local path = pool.remove(::Math.rand(0, pool.len() - 1));
            local item = null;
            try { item = ::new("scripts/items/" + path); } catch (err) { item = null; }
            if (item != null && items.equip(item))
                return;
        }
    }

    function onUse( _user, _targetTile )
    {
        local s = ::PaleSovereign;
        if (!this.isUsable() || !_targetTile.IsEmpty)
            return false;
        local rank = this.getRank();
        local extraCast = !this.hasFreeUseLeft();
        if (extraCast && !s.payExtraSummon(_user))
            return false;
        local e = ::Tactical.spawnEntity([this.m.Script, this.m.MasteryScript, this.m.EliteScript][rank], _targetTile.Coords.X, _targetTile.Coords.Y);
        if (e == null)
            return false;
        if (!extraCast)
            ++this.m.FreeUsed;
        this.m.Used = !this.hasFreeUseLeft();
        if (extraCast)
            e.getFlags().set("PaleExtraSummon", true);
        try { e.setFaction(::Const.Faction.PlayerAnimals); } catch (err) {}
        try { e.assignRandomEquipment(); } catch (err) {}
        local gear = [this.m.Gear, this.m.MasteryGear, this.m.EliteGear][rank];
        if (gear != null)
        {
            // 第 7 阶：换掉自带的武器和副手，从列表里重新挑（双手武器不配副手，单手武器配盾）
            local items = e.getItems();
            if ("ReplaceWeapon" in gear && gear.ReplaceWeapon)
                foreach (slot in [::Const.ItemSlot.Mainhand, ::Const.ItemSlot.Offhand])
                {
                    local held = items.getItemAtSlot(slot);
                    if (held != null)
                        items.unequip(held);
                }
            this.equipFrom(e, ::Const.ItemSlot.Mainhand, gear.Mainhand);
            local weapon = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
            if ("Offhand" in gear && (weapon == null || !weapon.isItemType(::Const.Items.ItemType.TwoHanded)))
                this.equipFrom(e, ::Const.ItemSlot.Offhand, gear.Offhand);
            this.equipFrom(e, ::Const.ItemSlot.Body, gear.Body);
            this.equipFrom(e, ::Const.ItemSlot.Head, gear.Head);
        }
        ::BGP.Necro.markGearNoLoot(e);
        e.m.Name = [this.m.MinionName, this.m.MasteryName, this.m.EliteName][rank];
        s.applySummonedLook(e, this.m.ArtStem + "_" + rank);
        try { e.riseFromGround(); } catch (err) {}
        ::BGP.Necro.copySocket(_user, e);
        ::BGP.Necro.markMinion(_user, e);
        if (s.isActive() && s.Battle != null)
        {
            e.getFlags().set("PaleRaised", true);
            e.getFlags().set("PaleFormationSummon", true);
            s.addBattleBoons(e);
            if (s.isChief(_user) && s.isAscended() && s.oath() == s.Oath.Scourge && !e.getSkills().hasSkill("effects.pale_dominion"))
                e.getSkills().add(::new(s.SkillDir + "effects/pale_dominion_effect"));
        }
        // 1.6.12：“压制”换“恐惧”；1.6.15 起改由 BGP.Necro.markMinion 对所有我方僵尸统一处理（决心同时降到 60）
        // 第 7 阶的额外技能（召唤僵尸：堕落英雄得“恐惧之容”）
        if (rank == 2 && this.m.EliteExtraSkills != null)
            foreach (script in this.m.EliteExtraSkills)
            {
                try
                {
                    local extra = ::new(script);
                    if (!e.getSkills().hasSkill(extra.getID()))
                        e.getSkills().add(extra);
                }
                catch (err)
                {
                    ::logError("[PaleSovereign] 召唤额外技能 " + script + ": " + err);
                }
            }
        if (extraCast)
            s.addSummonPlating(e, 25);
        s.onPaleSummoned(_user, e);
        e.getSkills().update();
        local art = this.m.ArtStem.slice("pale_".len()) + "_" + ::Math.rand(1, 3);
        try { s.playBattleArt(art, _targetTile, 28); } catch (err) {}
        if (!_user.isHiddenToPlayer())
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " 召出了 " + ::Const.UI.getColorizedEntityName(e));
        return true;
    }
});
