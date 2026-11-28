// Configurable player battle standard enhancement (70-90 damage + Reap skill).
local mod = ::Hooks.register("battle_standard", "1.1.0", "战旗增强");
mod.require("mod_modern_hooks", "mod_msu", "mod_local_rules");

mod.queue([">mod_reforged", ">mod_msu", ">mod_local_rules"], function()
{
	mod.hook("scripts/items/tools/player_banner", function(q)
	{
		q.m.BGP_OrigDamageMin <- 50;
		q.m.BGP_OrigDamageMax <- 70;
		q.m.BGP_ReapSkill <- null;

		q.BGP_syncBannerBuff <- function( _forceEnabled = null )
		{
			local enabled = _forceEnabled != null ? _forceEnabled : ::BGP.getSetting("BGP_BannerBuff", true);
			this.m.RegularDamage = enabled ? 70 : this.m.BGP_OrigDamageMin;
			this.m.RegularDamageMax = enabled ? 90 : this.m.BGP_OrigDamageMax;

			local container = this.getContainer();
			local actor = container == null ? null : container.getActor();
			local isEquippedMainhand = actor != null && !::MSU.isNull(actor)
				&& actor.getItems() != null && actor.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand) == this;

			if (!isEquippedMainhand)
				return;

			if (enabled)
			{
				if (!actor.getSkills().hasSkill("actives.reap"))
				{
					local reap = ::new("scripts/skills/actives/reap_skill");
					this.m.BGP_ReapSkill = ::MSU.asWeakTableRef(reap);
					this.addSkill(reap);
				}
			}
			else if (this.m.BGP_ReapSkill != null && !::MSU.isNull(this.m.BGP_ReapSkill))
			{
				local reap = this.m.BGP_ReapSkill.get();
				this.m.BGP_ReapSkill = null;
				local idx = this.m.SkillPtrs.find(reap);
				if (idx != null)
					this.m.SkillPtrs.remove(idx);
				try { actor.getSkills().remove(reap); } catch (e) {}
			}
		};

		q.create = @(__original) function()
		{
			__original();
			this.m.BGP_OrigDamageMin = this.m.RegularDamage;
			this.m.BGP_OrigDamageMax = this.m.RegularDamageMax;
			if (::BGP.getSetting("BGP_BannerBuff", true))
			{
				this.m.RegularDamage = 70;
				this.m.RegularDamageMax = 90;
			}
		};

		q.onEquip = @(__original) function()
		{
			this.m.BGP_ReapSkill = null;
			__original();
			this.BGP_syncBannerBuff();
		};

		q.onUnequip = @(__original) function()
		{
			this.m.BGP_ReapSkill = null;
			__original();
		};

		q.onUpdateProperties = @(__original) function( _properties )
		{
			this.BGP_syncBannerBuff();
			__original(_properties);
		};
	});
});
