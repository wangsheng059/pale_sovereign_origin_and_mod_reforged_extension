// Settlement trade price comparison tooltip with live MSU toggle support.
::mods_registerMod("mod_settlement_prices_tooltip", 6, "Settlement prices tooltip");

local modGetTooltip = function( tooltip )
{
	if (("LocalInterface" in ::getroottable()) && !::LocalInterface.get("UI_SettlementPrices", true))
		return tooltip;
	if (!tooltip.len())
		return tooltip;

	local green = function( text )
	{
		if (text == null) return "";
		return "[color=" + this.Const.UI.Color.PositiveValue + "]" + text + "[/color]";
	};
	local red = function( text )
	{
		if (text == null) return "";
		return "[color=" + this.Const.UI.Color.NegativeValue + "]" + text + "[/color]";
	};
	local blue = function( text )
	{
		if (text == null) return "";
		return "[color=#002869]" + text + "[/color]";
	};

	if (this.m.IsVisited)
	{
		this.updateSituations();
		local baseBuyPrice = this.Const.World.Assets.BaseBuyPrice * 100 * this.Const.Difficulty.BuyPriceMult[this.World.Assets.getEconomicDifficulty()];
		local baseSellPrice = this.Const.World.Assets.BaseSellPrice * 100 * this.Const.Difficulty.SellPriceMult[this.World.Assets.getEconomicDifficulty()];
		local getBuy = function( settlement )
		{
			return this.Math.ceil(settlement.getBuyPriceMult() * baseBuyPrice);
		};
		local getSell = function( settlement )
		{
			return this.Math.floor(settlement.getSellPriceMult() * baseSellPrice);
		};
		local buy = getBuy(this);
		local sell = getSell(this);
		local settlements = this.World.EntityManager.getSettlements();
		local buyPrices = [];
		local sellPrices = [];

		foreach (s in settlements)
		{
			s.updateSituations();
			buyPrices.push(getBuy(s));
			sellPrices.push(getSell(s));
		}

		local getMax = function( items )
		{
			if (!items || !items.len()) return 0;
			local max = items[0];
			foreach (i in items.slice(1))
			{
				if (i > max) max = i;
			}
			return max;
		};
		local getMin = function( items )
		{
			if (!items || !items.len()) return 0;
			local min = items[0];
			foreach (i in items.slice(1))
			{
				if (i < min) min = i;
			}
			return min;
		};
		local getRangeString = function( numbers, reverseColors = false )
		{
			local colorizeLeft = reverseColors ? green : red;
			local colorizeRight = reverseColors ? red : green;
			return " vs" + blue(" [") + colorizeLeft(getMin(numbers)) + "-" + colorizeRight(getMax(numbers)) + blue("]");
		};

		local bestBuy = getMin(buyPrices);
		local worstBuy = getMax(buyPrices);
		local tenPercents = this.Math.abs(worstBuy - bestBuy) * 0.1;
		local colorizeBuy = buy <= bestBuy + tenPercents ? green : red;
		local bestSell = getMax(sellPrices);
		local worstSell = getMin(sellPrices);
		tenPercents = this.Math.abs(bestSell - worstSell) * 0.1;
		local colorizeSell = sell >= bestSell - tenPercents ? green : red;

		tooltip.push({
			id = 50,
			type = "text",
			icon = "ui/icons/bag.png",
			text = "购买价: " + colorizeBuy(buy) + "%" + getRangeString(buyPrices, true)
		});
		tooltip.push({
			id = 51,
			type = "text",
			icon = "ui/icons/asset_money.png",
			text = "出售价: " + colorizeSell(sell) + "%" + getRangeString(sellPrices)
		});
	}

	return tooltip;
};

local patchGetTooltip = function( obj )
{
	if (("getTooltip" in obj) && ("getCurrentBuilding" in obj) && ("getAttachedLocations" in obj))
	{
		local _getTooltip = obj.getTooltip;
		obj.getTooltip = function()
		{
			return modGetTooltip(_getTooltip());
		};
	}
};

::mods_queue(null, null, function()
{
	::mods_hookBaseClass("entity/world/location", function( obj )
	{
		return patchGetTooltip(obj);
	});
});
