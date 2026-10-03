--!strict
local Packages = script.Parent.Parent.Parent

local Janitor = require(Packages.Janitor)
local Signal = require(Packages.Signal)
 
--[=[
	@type Signal Signal<T...>
	@within Classy

	The Signal type used by [ClassyObject] (`InstanceAdded` / `InstanceRevoked`).
]=]
export type Signal<T...> = Signal.Signal<T...>

--[=[
	@type Connection Connection
	@within Classy

	A connection returned by a Signal, e.g. from [ClassyObject:ObserveApplied].
]=]
export type Connection = Signal.Connection

--[=[
	@type Janitor Janitor
	@within Classy

	The [Janitor](https://github.com/howmanysmall/Janitor) handed to your
	constructor. It is cleaned up when the instance is revoked.
]=]
export type Janitor = Janitor.Janitor

--[=[
	@type ConstructorKind "Class" | "Function"
	@within Classy

	How a ClassyObject builds its objects.
]=]
export type ConstructorKind = "Class" | "Function"

--[=[
	@interface ClassConstructable
	@within Classy
	.new (Instance, Janitor, { any }, { [string]: any }?) -> T

	A class table accepted by [Classy.newClass]. Its `new` function receives the
	tagged instance, a Janitor, the `Context` table, and the metadata (if any).
]=]
export type ClassConstructable<T> = {
	new: (
		Instance,
		Janitor,
		{any},
		{[string]: any}?
	) -> T,
}

--[=[
	@type FunctionConstructable (Instance, Janitor, { any }, { [string]: any }?) -> T
	@within Classy

	A function accepted by [Classy.new]. It receives the tagged instance, a
	Janitor, the `Context` table, and the metadata (if any).
]=]
export type FunctionConstructable<T> =
	(
		Instance,
		Janitor,
		{any},
		{[string]: any}?
	) -> T

--[=[
	@interface ClassyConfig
	@within Classy
	.Predicate ((Instance) -> boolean)? -- Custom check. Return `false` to skip an instance
	.ClassNames { string }? -- Instances must pass `IsA` for at least one listed class. Empty means no restriction
	.Ancestors { Instance }? -- Instances must descend from at least one listed ancestor. Empty means no restriction
	.NamingConvention { Init: string?, Destroy: string? }? -- Lifecycle method names Classy calls on your object. Defaults to `Init` / `Destroy`
	.Nuke boolean? -- When an applied object is destroyed, also clear its table and remove its metatable. Defaults to `true`
	.Context any? -- Table handed to your constructor as its third argument. Defaults to `{}`
	.RemoveTagOnCleanup boolean? -- Remove the tag when an instance is revoked. Defaults to `true`
	.Logging boolean? -- Print when instances are applied, revoked, and cleaned up. Defaults to `false`
	.WaitForMetadata boolean? -- Wait up to 7 seconds for the metadata attribute before applying. Defaults to `false`

	Every option is optional. Passed as the last argument to [Classy.new] and
	[Classy.newClass].

```lua
	Classy.newClass("Door", DoorClass, {
		ClassNames = { "Model" },
		Ancestors = { workspace.Doors },
		Predicate = function(instance)
			return instance:GetAttribute("Enabled") ~= false
		end,
		NamingConvention = { Init = "Start", Destroy = "Cleanup" },
		WaitForMetadata = true,
		Logging = true,
	}):Init()
```

	:::note When checks run
	`ClassNames`, `Ancestors`, and `Predicate` are checked when an instance gets
	the tag (or joins the game with it) and again whenever an applied instance's
	ancestry changes. An instance that stops passing is revoked, and is **not**
	re-applied automatically if it passes again later. Re-tag it or call
	[ClassyObject:Apply] yourself.
	:::
]=]
export type ClassyConfig = {
	Predicate: ((Instance) -> boolean)?,
	ClassNames: { string }?,
	NamingConvention: {
		Init: string?,
		Destroy: string?,
	}?,
	AutoInit: boolean?,
	Nuke: boolean?,
	Context: any?,
	RemoveTagOnCleanup: boolean?,
	Logging: boolean?,
	Ancestors: { Instance }?,
	WaitForMetadata: boolean?,
}

return 0