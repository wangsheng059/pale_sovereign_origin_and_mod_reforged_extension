this.pale_follower <- ::inherit("scripts/retinue/ph_follower", {
    m = { PaleKey = "", IsUnlocked = true },

    function setup( _key )
    {
        this.ph_follower.create();
        this.m.PaleKey = _key;
        this.m.ID = "follower.pale_" + _key;
        local data = ::PaleSovereign.FollowerData[_key];
        this.m.Name = data.Name;
        this.m.Archetype = ::PandorasHobby.Follower.Archetype[data.Archetype];
        this.m.BaseCost = 1500;
        this.m.Cost = this.m.BaseCost;
        this.m.Skills = 4194304;
        this.m.Requirements = [{ Text = "亡灵主宰专属随从", IsSatisfied = true }];
    }

    function onEvaluate() {}

    function isVisible()
    {
        return ::PaleSovereign.isActive();
    }

    function getName()
    {
        return this.m.Name + "（" + this.m.Level + " 级）";
    }

    function getImage()
    {
        return ::PaleSovereign.FollowerData[this.m.PaleKey].Image;
    }

    function getDescription()
    {
        return ::PaleSovereign.FollowerData[this.m.PaleKey].Description;
    }

    function getXPHintText()
    {
        return "每次战斗胜利获得 3 点经验。升到 2、3 级自动学会下一项技能。";
    }

    function isMaxLevel()
    {
        return this.m.Level >= 3;
    }

    function getPaleRank()
    {
        return (this.m.Skills & 16777216) != 0 ? 3 : (this.m.Skills & 8388608) != 0 ? 2 : 1;
    }

    function onUpdate()
    {
        ::PaleSovereign.followerAssets(this.m.PaleKey, this.getPaleRank());
    }

    function getMovementSpeedMult()
    {
        return ::PaleSovereign.followerMovementMult(this.m.PaleKey);
    }

    function earnVictoryXP()
    {
        if (this.isMaxLevel())
            return;
        this.m.XP += 3;
        local needed = this.getXPForNextLevel();
        if (this.m.XP >= needed)
        {
            this.m.XP -= needed;
            ++this.m.Level;
            this.m.LevelsSpent = this.m.Level;
            this.m.Skills = this.m.Skills | (4194304 << (this.m.Level - 1));
            this.setFlag("LVL", this.m.Level);
            this.setFlag("LVLSpent", this.m.LevelsSpent);
            this.setFlag("Skills", this.m.Skills);
            ::World.Assets.resetToDefaults();
        }
        this.setFlag("XP", this.m.XP);
        this.updateEffects();
    }

    function updateEffects()
    {
        local unlocked = this.getPaleRank();
        this.m.Effects = [];
        foreach (index, effect in ::PaleSovereign.FollowerData[this.m.PaleKey].Effects)
            this.m.Effects.push((index + 1 <= unlocked ? "" : "（" + (index + 1) + " 级解锁）") + effect);
        this.m.TooltipEffects = clone this.m.Effects;
    }
});
