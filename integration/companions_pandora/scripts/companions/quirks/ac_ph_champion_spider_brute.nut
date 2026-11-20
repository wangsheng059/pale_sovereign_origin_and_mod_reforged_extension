this.ac_ph_champion_spider_brute <- this.inherit("scripts/companions/quirks/ac_ph_champion", {
	m = {},
	function create()
	{
		this.ac_ph_champion.create();
		this.setChampion("spider_brute");
	}
});
