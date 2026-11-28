// Settlement situation numeric modifier breakdown with live MSU toggle support.
::mods_hookBaseClass("entity/world/settlements/situations/situation", function(o)
{
	local modifiersFunction = ::mods_getMember(o, "onUpdate");
	local recruitsFunction = ("onUpdateDraftList" in o) ? o.onUpdateDraftList : null;

	while (!("getTooltip" in o)) o = o[o.SuperName];
	local origGetTooltip = o.getTooltip;

	local _situation_modifiers = {
		"PriceMult" : 1.0,
		"BuyPriceMult" : 1.0,
		"SellPriceMult" : 1.0,
		"FoodPriceMult" : 1.0,
		"MedicalPriceMult" : 1.0,
		"BuildingPriceMult" : 1.0,
		"IncensePriceMult" : 1.0,
		"BeastPartsPriceMult" : 1.0,
		"RarityMult" : 1.0,
		"FoodRarityMult" : 1.0,
		"MedicalRarityMult" : 1.0,
		"MineralRarityMult" : 1.0,
		"BuildingRarityMult" : 1.0,
		"RecruitsMult" : 1.0
	};

	local getModifiers = function( _mods )
	{
		modifiersFunction(_mods);
		local changedMultipliers = [];
		foreach (key, value in _mods)
		{
			if (value != 1.0)
			{
				if (key == "PriceMult")
				{
					changedMultipliers.append({ name = "BuyPriceMult", amount = value });
					changedMultipliers.append({ name = "SellPriceMult", amount = value });
				}
				else
				{
					changedMultipliers.append({ name = key, amount = value });
				}
			}
		}
		return changedMultipliers;
	};

	local generateColoredString = function( nameAmountPair )
	{
		local difference = nameAmountPair.amount > 1 ? (nameAmountPair.amount - 1) * 100 : (nameAmountPair.amount - 1) * -100;
		local diffPct = difference.tostring() + "% ";
		local lessOrMore = nameAmountPair.amount > 1 ? "多" : "少";
		local badColor = this.Const.UI.Color.NegativeValue + "]";
		local goodColor = this.Const.UI.Color.PositiveValue + "]";
		local color = lessOrMore == "少" ? badColor : goodColor;

		switch (nameAmountPair.name)
		{
			case "BuyPriceMult":
				color = lessOrMore == "多" ? badColor : goodColor;
				return "购买价" + lessOrMore + "[color=" + color + diffPct + "[/color]";
			case "SellPriceMult":
				return "出售价" + lessOrMore + "[color=" + color + diffPct + "[/color]";
			case "FoodPriceMult":
				color = lessOrMore == "多" ? badColor : goodColor;
				return "食物 价格" + lessOrMore + "[color=" + color + diffPct + "[/color]";
			case "MedicalPriceMult":
				color = lessOrMore == "多" ? badColor : goodColor;
				return "药草 价格" + lessOrMore + "[color=" + color + diffPct + "[/color]";
			case "BeastPartsPriceMult":
				return "野兽战利品 售价" + lessOrMore + "[color=" + color + diffPct + "[/color]";
			case "BuildingPriceMult":
				return "木材 价格" + lessOrMore + "[color=" + color + diffPct + "[/color]";
			case "IncensePriceMult":
				return "熏香 价格" + lessOrMore + "[color=" + color + diffPct + "[/color]";
			case "RarityMult":
				if (lessOrMore == "少") lessOrMore = "减少";
				return lessOrMore + "[color=" + color + diffPct + "[/color]" + "物品出售";
			case "FoodRarityMult":
				return lessOrMore + "[color=" + color + diffPct + "[/color]" + "食物出售";
			case "MedicalRarityMult":
				return lessOrMore + "[color=" + color + diffPct + "[/color]" + "药草出售";
			case "MineralRarityMult":
				return lessOrMore + "[color=" + color + diffPct + "[/color]" + "宝石出售";
			case "BuildingRarityMult":
				return lessOrMore + "[color=" + color + diffPct + "[/color]" + "木材出售";
			case "RecruitsMult":
				if (lessOrMore == "少") lessOrMore = "减少";
				return lessOrMore + "[color=" + color + diffPct + "[/color]" + " 新兵";
		}
		return nameAmountPair.name + " " + difference + "%.";
	};

	local getIconPath = function( name )
	{
		switch (name)
		{
			case "PriceMult": return "ui/icons/PriceMult.png";
			case "BuyPriceMult": return "ui/icons/BuyPriceMult.png";
			case "SellPriceMult": return "ui/icons/SellPriceMult.png";
			case "FoodPriceMult": return "ui/icons/FoodPriceMult.png";
			case "MedicalPriceMult": return "ui/icons/MedicalPriceMult.png";
			case "BuildingPriceMult": return "ui/icons/BuildingPriceMult.png";
			case "IncensePriceMult": return "ui/icons/IncensePriceMult.png";
			case "RarityMult": return "ui/icons/RarityMult.png";
			case "FoodRarityMult": return "ui/icons/FoodRarityMult.png";
			case "MedicalRarityMult": return "ui/icons/MedicalRarityMult.png";
			case "MineralRarityMult": return "ui/icons/MineralRarityMult.png";
			case "BuildingRarityMult": return "ui/icons/BuildingRarityMult.png";
			case "RecruitsMult": return "ui/icons/RecruitsMult.png";
		}
		return "ui/icons/RarityMult.png";
	};

	local capitalizeFirst = function( stringIn )
	{
		return stringIn.slice(0, 1).toupper() + stringIn.slice(1);
	};

	local pluralizeBackground = function( background )
	{
		if (background.find("man") == background.len() - 3)
			return background.slice(0, background.len() - 3) + "men";
		if (background.find("hief") == background.len() - 4)
			return background.slice(0, background.len() - 4) + "hieves";
		if (background == "Killer On The Run")
			return "Killers On The Run";
		return background + "s";
	};

	local createAddedRecruitsSentence = function( parsedBackgroundNames )
	{
		if (parsedBackgroundNames.len() == 1)
			return "有更多的" + pluralizeBackground(parsedBackgroundNames[0]) + "可雇佣";
		if (parsedBackgroundNames.len() == 2)
			return "有更多的" + pluralizeBackground(parsedBackgroundNames[0]) + " 和 " + pluralizeBackground(parsedBackgroundNames[1]) + "可雇佣";
		local sentence = "";
		local numNames = parsedBackgroundNames.len();
		for (local i = 0; i < numNames - 2; i++)
			sentence += pluralizeBackground(parsedBackgroundNames[i]) + ", ";
		return "有更多的" + sentence + pluralizeBackground(parsedBackgroundNames[numNames - 2]) + " 和 " + pluralizeBackground(parsedBackgroundNames[numNames - 1]) + "可雇佣";
	};

	local formatBackgroundNames = function( uniqueBackgrounds )
	{
		local parsedBackgroundNames = [];
		foreach (background in uniqueBackgrounds)
		{
			local backgroundNameArray = split(background, "_");
			local backgroundNameString = "";
			for (local j = 0; j < backgroundNameArray.len() - 1; j++)
			{
				backgroundNameString += capitalizeFirst(strip(backgroundNameArray[j]));
				if (backgroundNameArray.len() > 2 && j < backgroundNameArray.len() - 2)
					backgroundNameString += " ";
			}
			parsedBackgroundNames.append(backgroundNameString);
		}
		return parsedBackgroundNames;
	};

	local parseBackgrounds = function()
	{
		local backgrounds = [];
		local uniqueBackgrounds = [];
		recruitsFunction(backgrounds);
		foreach (background in backgrounds)
		{
			if (uniqueBackgrounds.find(background) == null)
				uniqueBackgrounds.append(background);
		}
		return uniqueBackgrounds;
	};

	local addSituationInfo = function()
	{
		local situationInfo = [];
		local mods = clone(_situation_modifiers);
		local changedMultipliers = getModifiers(mods);
		foreach (pair in changedMultipliers)
		{
			situationInfo.append({
				id = 10,
				type = "text",
				icon = getIconPath(pair.name),
				text = generateColoredString(pair)
			});
		}
		return situationInfo;
	};

	o.getTooltip = function()
	{
		if (("LocalInterface" in ::getroottable()) && !::LocalInterface.get("UI_SituationDetails", true))
			return origGetTooltip();

		local tooltip_contents = [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() }
		];

		tooltip_contents.extend(addSituationInfo());

		if (recruitsFunction)
		{
			local names = formatBackgroundNames(parseBackgrounds());
			if (names.len() > 0)
			{
				tooltip_contents.append({
					id = 10,
					type = "text",
					icon = "ui/icons/RecruitsMult.png",
					text = createAddedRecruitsSentence(names)
				});
			}
		}

		return tooltip_contents;
	};
});
