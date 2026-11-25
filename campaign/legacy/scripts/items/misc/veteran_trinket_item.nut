// Base class for unique keepsake trinkets left behind by retired level 11+ veterans.
// Preserves exact binary serialization layout (VeteranName + EventIcon) for save compatibility.

this.veteran_trinket_item <- this.inherit("scripts/items/item", {
	m = {
		VeteranName = "",
		EventIcon = ""
	},

	function create()
	{
		this.item.create();
		this.m.SlotType = this.Const.ItemSlot.None;
		this.m.ItemType = this.Const.Items.ItemType.Misc | this.Const.Items.ItemType.Loot;
		this.m.IsDroppedAsLoot = true;
		this.m.Value = 150;
	}

	function setVeteranName( _name )
	{
		this.m.rawset("VeteranName", _name != null ? _name : "");
	}

	function getName()
	{
		return this.m.Name;
	}

	function getDescription()
	{
		if (this.m.Description == null || this.m.Description.len() == 0)
			return "这件物品让人想起一位昔日的战友。";

		local desc = this.m.Description;
		local name = this.m.VeteranName != null && this.m.VeteranName != "" ? this.m.VeteranName : "一位老兵";
		local out = "";
		local pos = 0;
		local idx = desc.find("%name%", pos);
		while (idx != null)
		{
			out += desc.slice(pos, idx) + name;
			pos = idx + 6;
			idx = desc.find("%name%", pos);
		}
		out += desc.slice(pos);
		return out;
	}

	function getTooltip()
	{
		return [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() },
			{ id = 66, type = "text", text = this.getValueString() }
		];
	}

	function onSerialize( _out )
	{
		this.item.onSerialize(_out);
		_out.writeString(this.m.VeteranName);
		_out.writeString(this.m.EventIcon);
	}

	function onDeserialize( _in )
	{
		this.item.onDeserialize(_in);
		this.m.VeteranName = _in.readString();
		this.m.EventIcon = _in.readString();
	}
});
