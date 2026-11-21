this.pale_tier_aura <- ::inherit("scripts/skills/effects/pale_tier_passive", {
    m = {},

    function onDeathWithInfo( _killer, _skill, _deathTile, _corpseTile, _fatality )
    {
        local S = ::PaleSovereign;
        if (this.m.TierTalent == "dead_command" && S.Battle != null)
        {
            ::Time.scheduleEvent(::TimeUnit.Virtual, 1, function( _battle )
            {
                if (S.Battle == _battle)
                    S.refreshDeadCommand();
            }, S.Battle);
        }
    }
});
