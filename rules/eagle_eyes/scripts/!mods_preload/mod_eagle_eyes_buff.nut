// Eagle Eyes trait enhancement with live MSU toggle support.
::EagleEyesBuff <- {
	ID = "mod_eagle_eyes_buff",
	Name = "鹰眼特性强化",
	Version = "1.1.0",

	RangedSkill = 5,
	HeadHitChance = 20,
	VisionTotal = 5,
	VanillaVision = 1
};

::EagleEyesBuff.HooksMod <- ::Hooks.register(::EagleEyesBuff.ID, ::EagleEyesBuff.Version, ::EagleEyesBuff.Name);
::EagleEyesBuff.HooksMod.require("mod_modern_hooks");

::EagleEyesBuff.HooksMod.queue([">mod_reforged", ">mod_msu", ">mod_local_rules"], function()
{
	::EagleEyesBuff.HooksMod.hook("scripts/skills/traits/eagle_eyes_trait", function(q)
	{
		q.onUpdate = @(__original) function( _properties )
		{
			__original(_properties);
			if (("BGP" in ::getroottable()) && !::BGP.getSetting("BGP_EagleEyesBuff", true))
				return;
			local c = ::EagleEyesBuff;
			_properties.RangedSkill += c.RangedSkill;
			_properties.HitChance[::Const.BodyPart.Head] += c.HeadHitChance;
			_properties.Vision += c.VisionTotal - c.VanillaVision;
		};

		q.getTooltip = @(__original) function()
		{
			local ret = __original();
			if (("BGP" in ::getroottable()) && !::BGP.getSetting("BGP_EagleEyesBuff", true))
				return ret;
			local c = ::EagleEyesBuff;
			local pos = ::Const.UI.Color.PositiveValue;
			local visionText = "[color=" + pos + "]+" + c.VisionTotal + "[/color] 视野";
			local replaced = false;
			foreach (e in ret)
			{
				if (("icon" in e) && e.icon == "ui/icons/vision.png")
				{
					e.text = visionText;
					replaced = true;
					break;
				}
			}
			if (!replaced)
				ret.push({ id = 10, type = "text", icon = "ui/icons/vision.png", text = visionText });

			ret.push({ id = 11, type = "text", icon = "ui/icons/ranged_skill.png", text = "[color=" + pos + "]+" + c.RangedSkill + "[/color] 远程技能" });
			ret.push({ id = 12, type = "text", icon = "ui/icons/chance_to_hit_head.png", text = "命中头部的几率 [color=" + pos + "]+" + c.HeadHitChance + "%[/color]" });
			return ret;
		};
	});
}, ::Hooks.QueueBucket.Normal);
