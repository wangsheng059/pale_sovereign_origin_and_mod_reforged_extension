this.pale_conquest_choice_event <- ::inherit("scripts/events/event", {
    m = {},

    function create()
    {
        this.m.ID = "event.pale_conquest_choice";
        this.m.Title = "城镇的命运";
        this.m.Cooldown = 0;
        this.m.IsSpecial = true;
        this.m.Screens.push({
            ID = "A", Text = "广场上的活人跪了一整夜，没有一个人敢起身。他们还在等候导师的裁决。", Options = [],
            function start( _event )
            {
                this.Options = [];
                local town = ::Conquest.Target == null || ::Conquest.Target.isNull() ? null : ::Conquest.Target.get();
                ::PaleSovereign.conquestChoices(this, town);
            }
        });
        this.m.Screens.push(::PaleSovereign.conquestResultScreen());
    }
});
