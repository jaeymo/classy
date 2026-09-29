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

local Classy = {
	Version = "2.1.3",
	ClassName = "Classy",
	ClassyObject = ClassyObject.ClassyObject,
	AppliedObject = ClassyObject.AppliedObject,	
} :: Static

function Classy.new<T>(Tag: string, Constructable: FunctionConstructable<T>, Config: ClassyConfig?): Classy<T>
	return Classy.ClassyObject.new(Tag, Constructable, "Function", Config)
end

function Classy.newClass<T>(Tag: string, Constructable: ClassConstructable<T>, Config: ClassyConfig?): Classy<T>
	return Classy.ClassyObject.new(Tag, Constructable, "Class", Config)
end

function Classy.registerGlobal(Tag: string, ClassyInstance: any)
	Registry.GlobalRegistry[Tag] = ClassyInstance
end

function Classy.getGloballyRegistered(Tag: string): Classy<any>?
	return Registry.GlobalRegistry[Tag]
end

function Classy.getComponent(Inst: Instance, Tag: string): Applied<any>?
	return Registry.InstanceRegistry[Inst] and Registry.InstanceRegistry[Inst][Tag]
end

function Classy.getComponents(Inst: Instance): { [string]: Applied<any> }?
	return Registry.InstanceRegistry[Inst]
end

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

function Classy.applyComponents(Inst: Instance, Components: { [string]: { [string]: any } })
	for Tag, Metadata in Components do
		local ClassyInstance = Alias.ResolveClassyForTag(Tag, Metadata)
		if not ClassyInstance then
			continue
		end

		Inst:AddTag(Tag)
		ClassyInstance:Apply(Inst, Metadata)
	end
end

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