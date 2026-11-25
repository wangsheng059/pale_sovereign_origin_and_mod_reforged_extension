// Core namespace for the refactored Legacy mod (Career Stats, XP Share, Item History).
// Graves, Permanent Injury Hook, and Blind Enemies have been removed completely.

::Legacy <- {
	ID = "mod_legacy",
	Version = "3.0.0",
	Name = "遗产",
	Lang = "zh",
	Mod = null
};

// Back-compat shim for any external script probing ::Legacy.isRu().
::Legacy.isRu <- function()
{
	return false;
};

::Legacy.MH <- ::Hooks.register(::Legacy.ID, ::Legacy.Version, ::Legacy.Name);
::Legacy.MH.require("mod_modern_hooks", "mod_msu");

::Legacy.MH.queue(">mod_msu", function()
{
	::include("scripts/items/misc/veteran_trinket_item");
	::Legacy.Mod = ::MSU.Class.Mod(::Legacy.ID, ::Legacy.Version, ::Legacy.Name);
	::logInfo("Legacy v" + ::Legacy.Version + ": core initialized (Career Stats + XP Share + Item History)");
});
