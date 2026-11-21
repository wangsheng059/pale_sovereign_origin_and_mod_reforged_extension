this.pale_conquest_choice_event <- ::inherit("scripts/events/event", {
    m = {},

    function create()
    {
        this.m.ID = "event.pale_conquest_choice";
        this.m.Title = "城镇的命运";
        this.m.Cooldown = 0;
        this.m.IsSpecial = true;
        this.m.Screens.push({
            ID = "A", Text = "城里的活人还在等候导师的裁决。", Options = [],
            function start( _event )
            {
                this.Options = [];
                local town = ::Conquest.Target == null || ::Conquest.Target.isNull() ? null : ::Conquest.Target.get();
                ::PaleSovereign.conquestChoices(this, town);
            }
        });
    }
});
