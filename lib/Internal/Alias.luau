--!strict
local Internal = script.Parent

local Registry = require(Internal.Registry)
local ClassyObject = require(Internal.Parent.ClassyObject)

local GlobalRegistry = Registry.GlobalRegistry
local AliasRegistry = Registry.AliasRegistry

local Alias = {}

function Alias.ResolveClassyForTag(Tag: string, Metadata: { [string]: any }?): any
	local BaseTag = Metadata and (Metadata.useComponent or Metadata.UseComponent)
	if not BaseTag then
		return GlobalRegistry[Tag]
	end

	if typeof(BaseTag) ~= "string" then
		warn(`[Classy] Invalid useComponent for tag {Tag}`)
		return GlobalRegistry[Tag]
	end

	if BaseTag == Tag then
		return GlobalRegistry[Tag]
	end

	AliasRegistry[BaseTag] = AliasRegistry[BaseTag] or {}

	local ExistingAlias = AliasRegistry[BaseTag][Tag]
	if ExistingAlias then
		return ExistingAlias
	end

	local BaseClassy = GlobalRegistry[BaseTag]
	if not BaseClassy then
		warn(`[Classy] Missing base component: {BaseTag} (requested by {Tag})`)
		return nil
	end

	local AliasContext = table.clone(BaseClassy.Context)
	AliasContext.tag = Tag

	local AliasClassy = ClassyObject.ClassyObject.new(Tag, BaseClassy.Constructable, BaseClassy.ConstructorKind, {
		Predicate = BaseClassy.Predicate,
		ClassNames = BaseClassy.ClassNames,
		NamingConvention = {
			Init = BaseClassy.NamingConvention.Init,
			Destroy = BaseClassy.NamingConvention.Destroy,
		},
		Nuke = BaseClassy.Nuke,
		Context = AliasContext,
		RemoveTagOnCleanup = BaseClassy.RemoveTagOnCleanup,
		Logging = BaseClassy.Logging,
		Ancestors = BaseClassy.Ancestors,
		AutoInit = BaseClassy.AutoInit,
		WaitForMetadata = BaseClassy.WaitForMetadata,
	} :: any)
	AliasClassy:Init()

	AliasRegistry[BaseTag][Tag] = AliasClassy
	GlobalRegistry[Tag] = AliasClassy

	return AliasClassy
end

return Alias