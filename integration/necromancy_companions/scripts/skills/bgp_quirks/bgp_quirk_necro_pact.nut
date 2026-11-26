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
		local level = 11;
		try { level = this.getContainer().getActor().m.Item.m.Level; } catch (e) { level = 11; }
		local bonus = ::Math.max(0, level - 10);
		local minB = ::Math.floor(0.5 * bonus);
		local maxB = ::Math.floor(1.0 * bonus);
		ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "当前最小伤害 " + ::MSU.Text.colorPositive("+" + minB) + "、最大伤害 " + ::MSU.Text.colorPositive("+" + maxB) + "（11 级起每升 1 级 +0.5 / +1，向下取整）" });
		return ret;
	}
});
