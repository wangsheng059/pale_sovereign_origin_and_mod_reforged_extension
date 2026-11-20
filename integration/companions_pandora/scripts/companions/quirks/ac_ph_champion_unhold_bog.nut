this.ac_ph_champion_unhold_bog <- this.inherit("scripts/companions/quirks/ac_ph_champion", {
	m = {},
	function create()
	{
		this.ac_ph_champion.create();
		this.setChampion("unhold_bog");
	}
});
