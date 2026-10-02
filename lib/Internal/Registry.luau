--!strict

--[=[
	@class Registry
	@private

	Internal lookup tables shared across Classy's modules.
]=]

--[=[
	@prop GlobalRegistry { [string]: any }
	@within Registry
	@private

	Maps a tag to the ClassyObject registered globally under it. Written by
	`Classy.registerGlobal` and by alias resolution.
]=]

--[=[
	@prop AliasRegistry { [string]: { [string]: any } }
	@within Registry
	@private

	Maps a base tag to the aliases built from it (`UseComponent`), keyed by alias
	tag. Used so each alias is only built once.
]=]

--[=[
	@prop InstanceRegistry { [Instance]: { [string]: any? } }
	@within Registry
	@private

	Maps an instance to every AppliedObject attached to it, keyed by tag. Has
	weak keys (`__mode = "k"`) so destroyed instances can be garbage collected.
]=]
return {
	GlobalRegistry = {} :: { [string]: any },
	AliasRegistry = {} :: { [string]: { [string]: any } },

	InstanceRegistry = (setmetatable({}, {
		__mode = "k",
	}) :: any) :: { [Instance]: { [string]: any? } }
}