// 1.5.2 死灵契约：死灵宠物 11 级时得到，代替配件兄弟的“好孩子”（效果相同：按等级加伤害），只在装了配件兄弟时用到
this.bgp_quirk_necro_pact <- ::inherit("scripts/companions/quirks/companions_good_boy", {
	m = {},
	function create()
	{
		this.companions_good_boy.create();
		this.m.ID = "quirk.bgp_necro_pact";
		this.m.Name = "死灵契约";
		this.m.Description = "主仆之约越深，它出手越狠。";
		this.m.Icon = "ui/perks/bgp_quirk_necro_pact.png";
	}

	function getTooltip()
	{
		local ret = this.companions_good_boy.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "11 级起每升 1 级：最小伤害 +0.5、最大伤害 +1（同“好孩子”）" });
		return ret;
	}
});
