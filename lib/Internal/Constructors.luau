--!strict
local Internal = script.Parent

local Types = require(Internal.Types)

--[=[
	@class Constructors
	@private

	Internal helpers that turn a `Constructable` into an object for a tagged
	instance.
]=]
return {
	--[=[
		Builds an object from a class table by calling `Constructable.new`.
		Errors if `Constructable` isn't a table with a `new` function.

		@within Constructors
		@private
		@param Constructable ClassConstructable<T>
		@param Instance Instance
		@param JanitorObject Janitor
		@param Metadata { [string]: any }?
		@param Context { any }
		@return T
	]=]
	constructClass = function<T>(
		Constructable: Types.ClassConstructable<T>,
		Instance: Instance,
		JanitorObject: Types.Janitor,
		Metadata: { [string]: any }?,
		Context: { any }
	): T
		if typeof(Constructable) == "table" and typeof(Constructable.new) == "function" then
			return Constructable.new(Instance, JanitorObject, Context, Metadata)
		end

		error(`[{script.Name}] Invalid Constructable`)
	end,
	
	--[=[
		Builds an object by calling a constructor function directly.
		Errors if `Constructable` isn't a function.

		@within Constructors
		@private
		@param Constructable FunctionConstructable<T>
		@param Instance Instance
		@param JanitorObject Janitor
		@param Metadata { [string]: any }?
		@param Context { any }
		@return T
	]=]
	constructFunction = function<T>(
		Constructable: Types.FunctionConstructable<T>,
		Instance: Instance,
		JanitorObject: Types.Janitor,
		Metadata: { [string]: any }?,
		Context: { any }
	): T
		if typeof(Constructable) == "function" then
			return Constructable(Instance, JanitorObject, Context, Metadata)
		end

		error(`[{script.Name}] Invalid Constructable`)
	end,
}