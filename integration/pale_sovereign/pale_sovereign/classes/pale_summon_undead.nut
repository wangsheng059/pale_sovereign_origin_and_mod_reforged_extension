// 召唤僵尸 / 召唤骷髅：在相邻空格召出一名临时亡灵仆从（战斗结束后消散），每场每种 1 次
// 1.6.8：召出的仆从必定有武器和护甲；施法者学会“死灵精通”后召出更强的种类、换上更好的装备；
//        召唤僵尸也给普通死灵法师（背景 bgp_necromancer），召唤骷髅只给亡灵法师导师
// 1.6.9：学会第 7 阶特技（不灭冠军或尸爆）后再升一档
this.pale_summon_undead <- ::inherit("scripts/skills/skill", {
    m = {
        Script = "", MasteryScript = "", EliteScript = "", MinionName = "", MasteryName = "", EliteName = "", ForNecromancers = false,
        Gear = null, MasteryGear = null, EliteGear = null, Used = false
    },
    function create()
    {
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

    // 0 = 基础，1 = 死灵精通（第 4 阶），2 = 第 7 阶（不灭冠军 / 尸爆）
    function getRank()
    {
        local skills = this.getContainer().getActor().getSkills();
        if (skills.hasSkill("perk.bgp_necro_undying_champion") || skills.hasSkill("perk.bgp_corpse_explosion"))
            return 2;
        return skills.hasSkill("perk.bgp_necro_mastery") ? 1 : 0;
    }

    function getTooltip()
    {
        local ret = this.skill.getDefaultUtilityTooltip();
        local rank = this.getRank();
        local names = [this.m.MinionName, this.m.MasteryName, this.m.EliteName];
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "在相邻的空格召出一名" + names[rank] + "，自带武器和护甲，由 AI 控制，战斗结束后消散" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "学会死灵精通（第 4 阶）后召出" + this.m.MasteryName + (rank >= 1 ? "（已生效）" : "")
            + "；学会第 7 阶特技（不灭冠军或尸爆）后召出" + this.m.EliteName + (rank >= 2 ? "（已生效）" : "") });
        ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "每场战斗限 1 次" });
        if (this.m.Used)
            ret.push({ id = 13, type = "text", icon = "ui/icons/warning.png", text = "本场已经使用过" });
        return ret;
    }

    function isHidden()
    {
        local actor = this.getContainer().getActor();
        local s = ::PaleSovereign;
        if (s.isActive() && s.isChief(actor))
            return false;
        return !this.m.ForNecromancers || !actor.getSkills().hasSkill("background.bgp_necromancer");
    }

    function isUsable()
    {
        return !this.isHidden() && !this.m.Used && this.skill.isUsable();
    }

    function onCombatStarted()
    {
        this.m.Used = false;
    }

    function onCombatFinished()
    {
        this.m.Used = false;
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
        local e = ::Tactical.spawnEntity([this.m.Script, this.m.MasteryScript, this.m.EliteScript][rank], _targetTile.Coords.X, _targetTile.Coords.Y);
        if (e == null)
            return false;
        this.m.Used = true;
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
        try { e.riseFromGround(); } catch (err) {}
        ::BGP.Necro.copySocket(_user, e);
        ::BGP.Necro.markMinion(_user, e);
        if (s.isActive() && s.Battle != null)
        {
            e.getFlags().set("PaleRaised", true);
            s.addBattleBoons(e);
            if (s.isChief(_user) && s.isAscended() && s.oath() == s.Oath.Scourge && !e.getSkills().hasSkill("effects.pale_dominion"))
                e.getSkills().add(::new(s.SkillDir + "effects/pale_dominion_effect"));
        }
        e.getSkills().update();
        try { s.playBattleArt("resurrect", _targetTile, 28); } catch (err) {}
        if (!_user.isHiddenToPlayer())
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_user) + " 召出了 " + ::Const.UI.getColorizedEntityName(e));
        return true;
    }
});
