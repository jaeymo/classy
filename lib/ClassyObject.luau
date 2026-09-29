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
	@class Applied
	The Applied class is what Classy manages and attaches instances to
]=]
local Applied = {}
Applied.__index = Applied

export type Applied<T> = typeof(setmetatable(
	{} :: {
		Classy: Classy<T>,
		Instance: Instance,
		Janitor: Janitor,
		Data: T,
		Triggers: { [string]: string }?,
	},
	Applied
	))

--[=[
	Instantiates a new Applied object.
    @param Instance Instance
    @param ClassyObject Classy<T>
    @param ... any?
	@return Applied<T>
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
	}, Applied)
end

--[=[
	@return T
	Returns the T of an Applied object, either referring to a custom
    return from a function constructable or a object from a class
]=]
function Applied.GetData<T>(self: Applied<T>): T
	return self.Data
end

--[=[
	Destroys the Janitor and the attached data of an Applied object

	:::warning Metatable Removal
	Running this will make any further attempts to call a method of Applied
	error
	:::
]=]
function Applied.Destroy<T>(self: Applied<T>)
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
	@class Classy
	A Classy is useful for instantiating and managing instances of
	based on tags
]=]
local Classy = {}
Classy.__index = Classy

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
	Instantiates a new Classy object
    @param Tag string
    @param Constructable Constructable<T>
    @param ClassyConfig ClassyConfig<U>
	@return Classy<T>
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
	Initializes a Classy object
]=]
function Classy.Init<T>(self: Classy<T>)
	for _, Inst in CollectionService:GetTagged(self.Tag) do
		if self:CanBeApplied(Inst) then
			local Metadata = self.WaitForMetadata and Util.WaitForMetadata(Inst, self.Tag, METADATA_TIMEOUT) or nil
			self:Apply(Inst, Metadata)
		end
	end

	self.Janitor:Add(CollectionService:GetInstanceAddedSignal(self.Tag):Connect(function(Inst: Instance)
		if self:CanBeApplied(Inst) then
			local Metadata = self.WaitForMetadata and Util.WaitForMetadata(Inst, self.Tag, METADATA_TIMEOUT) or nil
			self:Apply(Inst, Metadata)
		end
	end))

	self.Janitor:Add(CollectionService:GetInstanceRemovedSignal(self.Tag):Connect(function(Inst: Instance)
		self:Revoke(Inst)
	end))
end

--[=[
	Returns if an Instance passes all of the checks to be applied
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
	Returns if an Instance passes all of the checks to be applied
    @param Instance Instance
    @return boolean
]=]
function Classy.GetApplied<T>(self: Classy<T>, Instance: Instance): Applied<T>
	return self.Applied[Instance]
end

--[=[
	Returns all applied instances
    @return { [Instance]: Applied<T> }
]=]
function Classy.GetAll<T>(self: Classy<T>): { [Instance]: Applied<T> }
	return self.Applied
end

--[=[
	Bypasses the `CanBeApplied` check and applies an instance
    
    ```lua
    local AppliedObject = ClassyObject:Apply(SomeInstance)
    AppliedObject:GetData():DoSomething()
    ```

    @param Instance Instance
    @param Metadata: {[string]: any}?
    @return Applied<T>
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

	local Connection: RBXScriptConnection
	Connection = Inst.AncestryChanged:Connect(function()
		if not self:CanBeApplied(Inst) then
			self:Revoke(Inst)
			Connection:Disconnect()
		end
	end)

	self.InstanceAdded:Fire(Inst, AppliedObject)
	
	return AppliedObject
end

--[=[
	Revokes an Instance from Classy
    
    :::info Note
	This will nullify the object's metatable, so you will not be able to use it's
	object after revoking it from Classy
	:::

    ```lua
    if ClassyObject:GetApplied(SomeInstance) then
        ClassyObject:Revoke(SomeInstance)
    end
    ```

    @param Instance Instance
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
	Runs a callback for all applied objects and hooks into the `InstanceAdded` signal

    ```lua
    local Connection = ClassyObject:ObserveApplied(function(Instance, Applied)
        Applied:GetData():DoSomething()
    end)

    Connection:Disconnect()
    ```

    @param Callback (Instance: Instance, Applied: Applied<T>)
    @return Connection Connection
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
	Destroys all tracked objects, cleans the Janitor and destroys signals, rendering
    this object unusable.

	:::warning Metatable Removal
	Running this will make any further attempts to call a method of Classy
	error.
	:::

	```lua
	ClassyObject:Destroy()
	```
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

	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

return {
	ClassyObject = Classy,
	AppliedObject = Applied,
}