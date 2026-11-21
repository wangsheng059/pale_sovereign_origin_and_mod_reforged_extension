local S = ::PaleSovereign;

S.gildArmor <- function( _actor, _fill = true )
{
    local items = _actor.getItems();
    foreach (slot in [::Const.ItemSlot.Body, ::Const.ItemSlot.Head])
    {
        local item = items.getItemAtSlot(slot);
        local empty = item == null;
        if (empty && !_fill)
            continue;
        if (empty)
            item = ::new(this.ItemDir + (slot == ::Const.ItemSlot.Body ? "armor/pale_gilded_bones" : "helmets/pale_gilded_skull"));
        if ("PaleGildedBonus" in item.m)
            continue;
        local shell = ["armor.pale_gilded_bones", "helmet.pale_gilded_skull"].find(item.getID()) != null;
        local bonus = shell ? 19 : 20;
        item.m.PaleGildedBonus <- bonus;
        local condition = item.getCondition();
        item.m.ConditionMax += bonus;
        item.setCondition(condition + bonus);
        if (empty)
            items.equip(item);
    }
};

S.Mod.hook("scripts/items/item_container", function(q)
{
    q.equip = @(__original) function( _item )
    {
        local result = __original(_item);
        local actor = this.m.Actor;
        if (result && actor != null && !::MSU.isNull(actor) && S.isUndead(actor) && actor.getFlags().has("PaleGilded")
            && (_item.getSlotType() == ::Const.ItemSlot.Body || _item.getSlotType() == ::Const.ItemSlot.Head))
            S.gildArmor(actor, false);
        return result;
    };

    q.unequip = @(__original) function( _item )
    {
        local result = __original(_item);
        if (result && _item != null && "PaleGildedBonus" in _item.m)
        {
            _item.m.ConditionMax -= _item.m.PaleGildedBonus;
            delete _item.m.PaleGildedBonus;
            _item.setCondition(::Math.minf(_item.getCondition(), _item.getConditionMax()));
        }
        return result;
    };
});

S.Mod.hook("scripts/entity/tactical/player", function(q)
{
    q.onSerialize = @(__original) function( ... )
    {
        local args = [this];
        args.extend(vargv);
        if (!this.getFlags().has("PaleGilded"))
            return __original.acall(args);
        local restore = [];
        foreach (slot in [::Const.ItemSlot.Body, ::Const.ItemSlot.Head])
        {
            local item = this.getItems().getItemAtSlot(slot);
            if (item == null || !("PaleGildedBonus" in item.m))
                continue;
            local condition = item.getCondition();
            this.getFlags().set("PaleGildedCondition." + slot, condition);
            restore.push({ Item = item, Condition = condition });
            item.m.ConditionMax -= item.m.PaleGildedBonus;
            item.setCondition(::Math.minf(condition, item.getConditionMax()));
        }
        try
        {
            __original.acall(args);
        }
        catch (e)
        {
            foreach (entry in restore)
            {
                entry.Item.m.ConditionMax += entry.Item.m.PaleGildedBonus;
                entry.Item.setCondition(entry.Condition);
            }
            throw e;
        }
        foreach (entry in restore)
        {
            entry.Item.m.ConditionMax += entry.Item.m.PaleGildedBonus;
            entry.Item.setCondition(entry.Condition);
        }
    };

    q.onDeserialize = @(__original) function( ... )
    {
        local args = [this];
        args.extend(vargv);
        local result = __original.acall(args);
        if (this.getFlags().has("PaleGilded"))
        {
            S.gildArmor(this);
            foreach (slot in [::Const.ItemSlot.Body, ::Const.ItemSlot.Head])
                if (this.getFlags().has("PaleGildedCondition." + slot))
                    this.getItems().getItemAtSlot(slot).setCondition(this.getFlags().getAsFloat("PaleGildedCondition." + slot));
        }
        return result;
    };
});
