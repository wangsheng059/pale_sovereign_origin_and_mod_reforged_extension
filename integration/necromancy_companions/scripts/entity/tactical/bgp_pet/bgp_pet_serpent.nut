// 配件兄弟宠物版：亡灵大蛇（继承本 mod 的复活类 bgp_undead_serpent，补上配件兄弟宠物需要的接口）
// 死灵精通：驯服对应的亡灵，或用“封魂入器”把复活的单位装进配件后，放出来的就是这个类
this.bgp_pet_serpent <- this.inherit("scripts/entity/tactical/bgp_undead/bgp_undead_serpent", {
	m = {
		Item = null
	},
	function setItem( _i )
	{
		::BGP.NecroPet.setItem(this, _i);
	}

	function setName( _n )
	{
		this.m.Name = _n;
	}

	function setVariant( _v )
	{
	}

	function onDeath( _killer, _skill, _tile, _fatalityType )
	{
		::BGP.NecroPet.releaseItem(this);
		this.bgp_undead_serpent.onDeath(_killer, _skill, _tile, _fatalityType);
	}

	function onActorKilled( _actor, _tile, _skill )
	{
		this.bgp_undead_serpent.onActorKilled(_actor, _tile, _skill);
		::BGP.NecroPet.onKill(this, _actor);
	}

	function applyCompanionScaling()
	{
		::BGP.NecroPet.applyScaling(this);
	}
});
