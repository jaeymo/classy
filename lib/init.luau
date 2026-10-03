--!strict
local Internal = script.Internal

local Alias = require(Internal.Alias)
local ClassyObject = require(script.ClassyObject)
local Registry = require(Internal.Registry)

local Types = require(Internal.Types)

export type Signal<T...> = Types.Signal<T...>

export type Janitor = Types.Janitor

export type Classy<T> = ClassyObject.Classy<T>

export type Applied<T> = ClassyObject.Applied<T>

export type ConstructorKind = "Class" | "Function"

export type ClassConstructable<T> = Types.ClassConstructable<T>

export type FunctionConstructable<T> = Types.FunctionConstructable<T>

export type ClassyConfig = Types.ClassyConfig

export type Static = {
	ClassName: "Classy",
	Version: string,
	
	ClassyObject: typeof(ClassyObject.ClassyObject),
	AppliedObject: typeof(ClassyObject.AppliedObject),
	
	new: <T>(Tag: string, Constructable: FunctionConstructable<T>, Config: ClassyConfig?) -> ClassyObject.Classy<T>,
	newClass: <T>(Tag: string, Constructable: ClassConstructable<T>, Config: ClassyConfig?) -> ClassyObject.Classy<T>,
	registerGlobal: (Tag: string, ClassyInstance: any) -> (),
	getGloballyRegistered: (Tag: string) -> Classy<any>?,
	getComponent: (Inst: Instance, Tag: string) -> Applied<any>?,
	getComponents: (Inst: Instance) -> { [string]: Applied<any> }?,
	callOnAllComponents: (Inst: Instance, MethodName: string,...any) -> (),
	applyComponents: (Inst: Instance, Components: { [string]: { [string]: any } }) -> (),
	emit: (Inst: Instance, TriggerName: string, Context: any?) -> (),
}

--[=[
	@class Classy

	A lifecycle manager built on top of `CollectionService` that makes both
	composition and OOP architecture more appealing in Luau.

	This creates [ClassyObject]s, manages the global registry, and provides 
	helpers for working with the components attached to an instance.
```lua
	local Classy = require(path.to.classy)

	Classy.new("KillPart", function(instance: BasePart, janitor: Classy.Janitor)
		janitor:Add(instance.Touched:Connect(function(hit)
			local humanoid = hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end))
	end, {
		ClassNames = { "BasePart" },
		Ancestors = { workspace },
	}):Init()
```
]=]
local Classy = {
	Version = "2.1.6",
	ClassName = "Classy",
	ClassyObject = ClassyObject.ClassyObject,
	AppliedObject = ClassyObject.AppliedObject,	
} :: Static

--[=[
	@prop Version string
	@within Classy
	@readonly

	The current version of Classy.
]=]

--[=[
	@prop ClassName "Classy"
	@within Classy
	@readonly

	The class name of the module.
]=]

--[=[
	@prop ClassyObject ClassyObject
	@within Classy
	@readonly

	The [ClassyObject] class table.
]=]

--[=[
	@prop AppliedObject AppliedObject
	@within Classy
	@readonly

	The [AppliedObject] class table.
]=]

--[=[
	Creates a new [ClassyObject] using **function-based** construction.

	Your function is called with `(Instance, Janitor, Context, Metadata?)` and
	may return any value. That value is what `:GetData()` returns on the
	resulting [AppliedObject].

```lua
	local DoorClassy = Classy.new("Door", function(instance, janitor, context, metadata)
		return DoorClass.new(instance, janitor)
	end, {
		ClassNames = { "Model" },
	})

	DoorClassy:Init()
```

	@param Tag string -- The CollectionService tag to manage
	@param Constructable FunctionConstructable<T> -- Function that builds the object for each tagged instance
	@param Config ClassyConfig? -- Optional configuration
	@return ClassyObject<T>
]=]
function Classy.new<T>(Tag: string, Constructable: FunctionConstructable<T>, Config: ClassyConfig?): Classy<T>
	return Classy.ClassyObject.new(Tag, Constructable, "Function", Config)
end

--[=[
	Creates a new [ClassyObject] using **class-based** construction.

	The table you pass must have a `new` function, which is called with
	`(Instance, Janitor, Context, Metadata?)`.

```lua
	local DoorClassy = Classy.newClass("Door", DoorClass, {
		ClassNames = { "Model" },
		Logging = true,
	})

	DoorClassy:Init()
```

	@param Tag string -- The CollectionService tag to manage
	@param Constructable ClassConstructable<T> -- Class table exposing a `new` constructor
	@param Config ClassyConfig? -- Optional configuration
	@return ClassyObject<T>
]=]
function Classy.newClass<T>(Tag: string, Constructable: ClassConstructable<T>, Config: ClassyConfig?): Classy<T>
	return Classy.ClassyObject.new(Tag, Constructable, "Class", Config)
end

--[=[
	Registers a [ClassyObject] globally under a tag.

	A global registration is required for [Classy.applyComponents] and for
	component aliases (`UseComponent`) to find the Classy.

	```lua
		Classy.registerGlobal("KillPart", KillPartClassy)
	```

	@param Tag string
	@param ClassyInstance ClassyObject<any>
]=]
function Classy.registerGlobal(Tag: string, ClassyInstance: any)
	Registry.GlobalRegistry[Tag] = ClassyInstance
end

--[=[
	Looks up a globally registered [ClassyObject].

	@param Tag string
	@return ClassyObject<any>? -- `nil` if nothing is registered under `Tag`
]=]
function Classy.getGloballyRegistered(Tag: string): Classy<any>?
	return Registry.GlobalRegistry[Tag]
end

--[=[
	Gets the component applied to an instance under a tag.

```lua
	local killPart = Classy.getComponent(workspace.Lava, "KillPart")
	if killPart then
		killPart:GetData():DoSomething()
	end
```

	@param Inst Instance
	@param Tag string
	@return AppliedObject<any>? -- `nil` if the instance has no component for `Tag`
]=]
function Classy.getComponent(Inst: Instance, Tag: string): Applied<any>?
	return Registry.InstanceRegistry[Inst] and Registry.InstanceRegistry[Inst][Tag]
end

--[=[
	Gets every component applied to an instance, keyed by tag.

	@param Inst Instance
	@return { [string]: AppliedObject<any> }? -- `nil` if the instance has no components
]=]
function Classy.getComponents(Inst: Instance): { [string]: Applied<any> }?
	return Registry.InstanceRegistry[Inst]
end

--[=[
	Calls a method on every component of an instance that has that method.
	Components without the method are skipped.

```lua
	Classy.callOnAllComponents(workspace.Lava, "DoSomething")
```

	@param Inst Instance
	@param MethodName string -- Name of the method to call on each component's data
	@param ... any -- Arguments forwarded to each method (after `self`)
]=]
function Classy.callOnAllComponents(Inst: Instance, MethodName: string, ...: any): ()
	local CollectedRegistry = Registry.InstanceRegistry[Inst]
	if not CollectedRegistry then
		return
	end	
	
	for _, AppliedValue in CollectedRegistry do
		local Data = (AppliedValue :: any):GetData()
		local Method = Data and Data[MethodName]

		if typeof(Method) == "function" then
			Method(Data, ...)
		end
	end
end

--[=[
	Applies a set of components to an instance at runtime and tags it.

	Each key is a tag and each value is that component's metadata. Every tag must
	be registered with [Classy.registerGlobal]. Metadata may include
	`UseComponent` to build the component from another registered component
	(an alias), and `Triggers` to map trigger names to methods.

```lua
	Classy.registerGlobal("KillPart", KillPartClassy)

	Classy.applyComponents(workspace.Lava, {
		KillPart = { Damage = 25 },
	})
```

	:::info
	Metadata is saved on the instance as a JSON attribute, so it must only contain
	JSON-serializable values (no functions or Instances).
	:::

	@param Inst Instance
	@param Components { [string]: { [string]: any } } -- Map of tag to metadata
]=]
function Classy.applyComponents(Inst: Instance, Components: { [string]: { [string]: any } })
	for Tag, Metadata in Components do
		local ClassyInstance = Alias.ResolveClassyForTag(Tag, Metadata)
		if not ClassyInstance then
			continue
		end

		ClassyInstance:Apply(Inst, Metadata)

		-- Run this after `ClassyInstance:Apply()` because under the "Immediate" signal behavior, we would have a race condition
		Inst:AddTag(Tag)
	end
end

--[=[
	Fires a trigger on an instance.

	Every component whose metadata maps `TriggerName` to a method has that method
	called with `Context`.

```lua
	Classy.applyComponents(door, {
		Door = { Triggers = { Activated = "Open" } },
	})

	-- Calls Data:Open({ Source = "Lever" }) on the door's Door component
	Classy.emit(door, "Activated", { Source = "Lever" })
```

	@param Instance Instance
	@param TriggerName string
	@param Context any? -- Passed to the triggered method
]=]
function Classy.emit(Instance: Instance, TriggerName: string, Context: any?)
	local InstanceRegistry = Registry.InstanceRegistry[Instance]
	if not InstanceRegistry then
		return
	end

	for _, AppliedValue in InstanceRegistry do
		local Triggers = AppliedValue.Triggers
		if not Triggers then
			continue
		end

		local MethodName = Triggers[TriggerName]
		if not MethodName then
			continue
		end

		local Data = (AppliedValue :: any):GetData()
		local Method = Data and (Data :: any)[MethodName]

		if typeof(Method) == "function" then
			(Method :: any)(Data, Context)
		end
	end
end

return Classy :: Static