this.pale_ambition <- ::inherit("scripts/ambitions/ambition", {
    m = { Goal = "" },

    function setup( _key )
    {
        this.ambition.create();
        local goal = ::PaleSovereign.AmbitionData[_key];
        this.m.Goal = _key;
        this.m.ID = "ambition.ps_" + _key;
        this.m.UIText = goal.Name;
        this.m.ButtonText = goal.Task;
        this.m.TooltipText = goal.Task;
        this.m.TaskTooltip = goal.Task;
        this.m.RewardTooltip = goal.Reward;
        this.m.SuccessText = goal.Story;
        this.m.SuccessButtonText = "让亡者记住此刻。";
        this.m.IsShowingMood = false;
        this.m.ButtonIcon = goal.Icon;
    }

    function getAbandonText()
    {
        return ::PaleSovereign.AmbitionData[this.m.Goal].Abandon;
    }

    function getRenownOnSuccess()
    {
        return ::PaleSovereign.AmbitionData[this.m.Goal].Renown;
    }

    function onStart()
    {
        if (this.m.Goal == "night_walker")
            ::PaleSovereign.set("NightGoalStart", ::PaleSovereign.get("NightWins"));
    }

    function onUpdateScore()
    {
        this.m.Score = ::PaleSovereign.ambitionScore(this.m.Goal);
    }

    function onCheckSuccess()
    {
        return ::PaleSovereign.ambitionComplete(this.m.Goal);
    }

    function onReward()
    {
        ::PaleSovereign.rewardAmbition(this, this.m.Goal);
    }
});
