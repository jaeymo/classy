--!strict
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Packages = script.Parent.Parent
local Internal = script.Parent.Internal

local Constructors = require(Internal.Constructors)
local Janitor = require(Packages.Janitor)
local Registry = require(Internal.Registry)
local Signal = require(Packages.Signal)
local Types = require(Internal.Types)
local Util = require(Internal.Util)

type ConstructorKind = Types.ConstructorKind
type ClassyConfig = Types.ClassyConfig
type Janitor = Types.Janitor

local METADATA_TIMEOUT = 7

--[=[
	@class AppliedObject

	The wrapper Classy keeps for each tagged instance. It holds whatever your
	constructor produced, the [Janitor](https://github.com/howmanysmall/Janitor)
	handed to it, and a reference back to the owning [ClassyObject].

	You normally get one from [ClassyObject:GetApplied], [ClassyObject:ObserveApplied],
	or [Classy.getComponent].
]=]
local Applied = {}
Applied.__index = Applied

--[=[
	@prop Classy ClassyObject<T>
	@within AppliedObject

	The [ClassyObject] that owns this applied object.
]=]

--[=[
	@prop Instance Instance
	@within AppliedObject

	The instance this object is attached to.
]=]

--[=[
	@prop Janitor Janitor
	@within AppliedObject

	The Janitor handed to your constructor. Cleaned up when the instance is revoked.
]=]

--[=[
	@prop Data T
	@within AppliedObject

	What your constructor or class produced. Same as [AppliedObject:GetData].
]=]

--[=[
	@prop Triggers { [string]: string }?
	@within AppliedObject

	The trigger map from the object's metadata, if any. Maps a trigger name to a
	method name. See [Classy.emit].
]=]

export type Applied<T> = typeof(setmetatable(
	{} :: {
		Classy: Classy<T>,
		Instance: Instance,
		Janitor: Janitor,
		Data: T,
		Triggers: { [string]: string }?,
		AncestryConnection: RBXScriptConnection?,
	},
	Applied
	))

--[=[
	Instantiates a new AppliedObject, builds its data through the Classy's
	constructor, and runs the object's `Init` method (if it has one).

	:::caution
	`Init` runs *before* the object is registered, so inside `Init` the object
	can't yet be found with [Classy.getComponent] or [ClassyObject:GetApplied].
	Use [ClassyObject:ObserveApplied] for that.
	:::

	@within AppliedObject
	@private
	@param Inst Instance
	@param ClassyObject ClassyObject<T>
	@param Metadata { [string]: any }?
	@return AppliedObject<T>
]=]
function Applied.new<T>(Inst: Instance, ClassyObject: Classy<T>, Metadata: { [string]: any }?): Applied<T>
	local AppliedJanitor = Janitor.new()
	ClassyObject.Janitor:Add(AppliedJanitor, "Destroy", Inst)

	local Data: T
	
	if ClassyObject.ConstructorKind == "Class" then
		Data = Constructors.constructClass(
			ClassyObject.Constructable,
			Inst,
			AppliedJanitor,
			Metadata,
			ClassyObject.Context
		)
	elseif ClassyObject.ConstructorKind == "Function" then
		Data = Constructors.constructFunction(
			ClassyObject.Constructable,
			Inst,
			AppliedJanitor,
			Metadata,
			ClassyObject.Context
		)
	end
	
	Util.SafeCall(Data, ClassyObject.NamingConvention.Init, Data)

	return setmetatable({
		Janitor = AppliedJanitor,
		Classy = ClassyObject,
		Instance = Inst,
		Data = Data,
		Triggers = Metadata and (Metadata.triggers or Metadata.Triggers),
		AncestryConnection = nil :: RBXScriptConnection?
	}, Applied)
end

--[=[
	Returns the `T` of an AppliedObject: either the custom value returned from a
	function constructable, or the object built by a class constructable.

```lua
	local applied = KillPartClassy:GetApplied(workspace.Lava)
	applied:GetData():DoSomething()
```

	@within AppliedObject
	@return T
]=]
function Applied.GetData<T>(self: Applied<T>): T
	return self.Data
end

--[=[
	Runs your `Destroy` method, destroys the Janitor, and clears the attached
	data of an AppliedObject.

	Prefer [ClassyObject:Revoke] over calling this yourself, since `Revoke` also
	handles the registry, the tag, and the `InstanceRevoked` signal.

	:::warning Metatable Removal
	Running this will make any further attempts to call a method of AppliedObject
	error.
	:::

	@within AppliedObject
]=]
function Applied.Destroy<T>(self: Applied<T>)
	if self.AncestryConnection then
		self.AncestryConnection:Disconnect()
	end

	Util.SafeCall(self.Data, self.Classy.NamingConvention.Destroy, self.Data)
	self.Classy.Janitor:RemoveNoClean(self.Instance)
	self.Janitor:Destroy()

	if self.Classy.Nuke then
		Util.SafeDestroy(self.Data)
	end

	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

--[=[
	@class ClassyObject

	What [Classy.new] and [Classy.newClass] return. A ClassyObject manages every
	instance that carries its tag: it applies them, tracks them, and cleans them
	up when they're revoked.

```lua
	local DoorClassy = Classy.newClass("Door", DoorClass, {
		ClassNames = { "Model" },
		Ancestors = { workspace.Doors },
	})

	DoorClassy:Init()

	DoorClassy:ObserveApplied(function(instance, applied)
		applied:GetData():Open()
	end)
```
]=]
local Classy = {}
Classy.__index = Classy

--[=[
	@prop InstanceAdded Signal<Instance, AppliedObject<T>>
	@within ClassyObject

	Fires when an instance is applied. Only fires for instances applied from now
	on. Use [ClassyObject:ObserveApplied] to also cover existing ones.
]=]

--[=[
	@prop InstanceRevoked Signal<Instance>
	@within ClassyObject

	Fires after an instance is revoked.
]=]

--[=[
	@prop Tag string
	@within ClassyObject

	The CollectionService tag this ClassyObject manages.
]=]

--[=[
	@prop Applied { [Instance]: AppliedObject<T> }
	@within ClassyObject

	Internal lookup of applied objects. Prefer [ClassyObject:GetApplied] and
	[ClassyObject:GetAll].
]=]

export type Classy<T> = typeof(setmetatable(
	{} :: {
		Tag: string,
		Janitor: Janitor,
		Logging: boolean,
		Ancestors: { Instance },
		Nuke: boolean,
		ClassNames: { string },
		NamingConvention: {
			Init: string,
			Destroy: string,
		},
		WaitForMetadata: boolean,
		Context: { any },
		RemoveTagOnCleanup: boolean,
		Constructable: any,
		ConstructorKind: Types.ConstructorKind,
		Predicate: ((Instance) -> boolean)?,
		Applied: { [Instance]: Applied<T> },
		InstanceAdded: Types.Signal<Instance, Applied<T>>,
		InstanceRevoked: Types.Signal<Instance>,
	},
	Classy
	))

--[=[
	Instantiates a new ClassyObject. Use [Classy.new] or [Classy.newClass] instead
	of calling this directly.

	@within ClassyObject
	@private
	@param Tag string
	@param Constructable any
	@param ConstructorKind ConstructorKind
	@param ClassyConfig ClassyConfig?
	@return ClassyObject<T>
]=]
function Classy.new<T>(Tag: string, Constructable: any, ConstructorKind: ConstructorKind, ClassyConfig: ClassyConfig?): Classy<T>
	local Config: ClassyConfig = ClassyConfig or {} :: any

	return setmetatable({
		Tag = Tag,
		Constructable = Constructable,

		ConstructorKind = ConstructorKind,
		ClassNames = Config.ClassNames or {},
		Ancestors = Config.Ancestors or {},
		Logging = Config.Logging or false,
		Predicate = Config.Predicate,
		RemoveTagOnCleanup = if Config.RemoveTagOnCleanup ~= nil then Config.RemoveTagOnCleanup else true,
		Nuke = if Config.Nuke ~= nil then Config.Nuke else true,

		NamingConvention = {
			Init = Config.NamingConvention and Config.NamingConvention.Init or "Init",
			Destroy = Config.NamingConvention and Config.NamingConvention.Destroy or "Destroy",
		},

		WaitForMetadata = Config.WaitForMetadata or false,
		Context = Config.Context or {},

		Applied = {},
		Janitor = Janitor.new(),

		InstanceAdded = Signal.new(),
		InstanceRevoked = Signal.new(),
	}, Classy)
end

--[=[
	Initializes the ClassyObject. Applies every currently tagged instance that
	passes the checks, then starts listening for newly tagged and untagged
	instances. Call this once.

```lua
	KillPartClassy:Init()
```

	@within ClassyObject
]=]
function Classy.Init<T>(self: Classy<T>)
	local function TryApply(Inst: Instance)
		if self:CanBeApplied(Inst) then
			self:Apply(Inst)
		end
	end

	for _, Inst in CollectionService:GetTagged(self.Tag) do
		task.spawn(TryApply, Inst)
	end

	self.Janitor:Add(CollectionService:GetInstanceAddedSignal(self.Tag):Connect(TryApply))

	self.Janitor:Add(CollectionService:GetInstanceRemovedSignal(self.Tag):Connect(function(Inst: Instance)
		self:Revoke(Inst)
	end))
end

--[=[
	Returns whether an instance passes all of the checks to be applied:
	`ClassNames`, `Ancestors`, and `Predicate`.

	@within ClassyObject
	@param Instance Instance
	@return boolean
]=]
function Classy.CanBeApplied<T>(self: Classy<T>, Instance: Instance): boolean
	if not Util.Validate(Instance, self.ClassNames, "IsA") then
		return false
	end

	if not Util.Validate(Instance, self.Ancestors, "IsDescendantOf") then
		return false
	end

	if self.Predicate and not self.Predicate(Instance) then
		return false
	end

	return true
end

--[=[
	Returns the applied object for an instance, if it has one.

	@within ClassyObject
	@param Instance Instance
	@return AppliedObject<T>?
]=]
function Classy.GetApplied<T>(self: Classy<T>, Instance: Instance): Applied<T>
	return self.Applied[Instance]
end

--[=[
	Returns every applied object, keyed by instance.

	@within ClassyObject
	@return { [Instance]: AppliedObject<T> }
]=]
function Classy.GetAll<T>(self: Classy<T>): { [Instance]: Applied<T> }
	return self.Applied
end

--[=[
	Bypasses the [ClassyObject:CanBeApplied] check and applies an instance.
	If the instance is already applied, the existing object is returned.

	If `Metadata` is given, it's passed to your constructor as its fourth
	argument and saved on the instance as a JSON attribute named
	`_<lowercase tag>_metadata`. With `WaitForMetadata = true` and no metadata
	passed, this waits up to 7 seconds for that attribute to exist.

```lua
	local AppliedObject = ClassyObject:Apply(SomeInstance)
	AppliedObject:GetData():DoSomething()
```

	@within ClassyObject
	@yields
	@param Inst Instance
	@param Metadata { [string]: any }? -- Must be JSON-serializable
	@return AppliedObject<T>
]=]
function Classy.Apply<T>(self: Classy<T>, Inst: Instance, Metadata: { [string]: any }?): Applied<T>
	if self.WaitForMetadata and not Metadata then
		Metadata = Util.WaitForMetadata(Inst, self.Tag, METADATA_TIMEOUT)
	end

	if Metadata then
		Inst:SetAttribute(`_{string.lower(self.Tag)}_metadata`, HttpService:JSONEncode(Metadata))
	end

	local Existing = self:GetApplied(Inst)
	if Existing then
		return Existing
	end

	if self.Logging then
		print(`[Classy] Applied instance: {Inst:GetFullName()}`)
	end

	local AppliedObject = Applied.new(Inst, self, Metadata)
	self.Applied[Inst] = AppliedObject

	Registry.InstanceRegistry[Inst] = Registry.InstanceRegistry[Inst] or {}
	Registry.InstanceRegistry[Inst][self.Tag] = AppliedObject

	AppliedObject.AncestryConnection = Inst.AncestryChanged:Connect(function()
	if not self:CanBeApplied(Inst) then
		self:Revoke(Inst)
	end
end)

	self.InstanceAdded:Fire(Inst, AppliedObject)
	
	return AppliedObject
end

--[=[
	Revokes an instance from Classy. Destroys its applied object, removes it from
	the registry, removes the tag (unless `RemoveTagOnCleanup` is `false`), and
	fires `InstanceRevoked`.

	:::info Note
	This will nullify the object's metatable, so you will not be able to use its
	object after revoking it from Classy.
	:::

```lua
	if ClassyObject:GetApplied(SomeInstance) then
		ClassyObject:Revoke(SomeInstance)
	end
```

	@within ClassyObject
	@param Inst Instance
]=]
function Classy.Revoke<T>(self: Classy<T>, Inst: Instance)
	
	local AppliedObject = self:GetApplied(Inst)
	if not AppliedObject then
		return
	end

	local CollectedRegistry = Registry.InstanceRegistry[Inst]
	
	if CollectedRegistry then
		CollectedRegistry[self.Tag] = nil
		
		if not next(CollectedRegistry) then
			Registry.InstanceRegistry[Inst] = nil
		end
	end

	if self.Logging then
		print(`[Classy] Revoked instance: {Inst:GetFullName()}`)
	end

	AppliedObject:Destroy()
	self.Applied[Inst] = nil

	if self.RemoveTagOnCleanup then
		Inst:RemoveTag(self.Tag)
	end

	self.InstanceRevoked:Fire(Inst)
end

--[=[
	Runs a callback for every already-applied object, and hooks into the
	`InstanceAdded` signal so it also runs for every future one.

```lua
	local Connection = ClassyObject:ObserveApplied(function(Instance, Applied)
		Applied:GetData():DoSomething()
	end)

	-- Later
	Connection:Disconnect()
```

	@within ClassyObject
	@param Callback (Instance: Instance, Applied: AppliedObject<T>) -> ()
	@return Connection
]=]
function Classy.ObserveApplied<T>(
	self: Classy<T>,
	Callback: (Instance: Instance, Applied: Applied<T>) -> ()
): Types.Connection
	for Inst, AppliedObject in self:GetAll() do
		task.spawn(function()
			Callback(Inst, AppliedObject :: Applied<T>)
		end)
	end

	return self.InstanceAdded:Connect(Callback)
end

--[=[
	Destroys all tracked objects, cleans the Janitor, and destroys the signals,
	rendering this object unusable. Also clears its global registration if it was
	registered under its tag.

	:::warning Metatable Removal
	Running this will make any further attempts to call a method of ClassyObject
	error.
	:::

```lua
	ClassyObject:Destroy()
```

	@within ClassyObject
]=]
function Classy.Destroy<T>(self: Classy<T>)
	for Inst in self:GetAll() do
		self:Revoke(Inst)
	end

	if self.Logging then
		print(`[Classy] Cleaned classy for: {self.Tag}`)
	end

	self.Janitor:Destroy()
	self.InstanceAdded:Destroy()
	self.InstanceRevoked:Destroy()

	if Registry.GlobalRegistry[self.Tag] == self then
		Registry.GlobalRegistry[self.Tag] = nil
	end

	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

return {
	ClassyObject = Classy,
	AppliedObject = Applied,
}