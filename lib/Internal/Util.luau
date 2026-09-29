--!strict
local HttpService = game:GetService("HttpService")

local Util = {}

function Util.Validate<T>(Inst: Instance, List: {T}, Fn: string): boolean
	if not next(List) then
		return true
	end

	for _, v in List do
		if (Inst :: any)[Fn](Inst, v) then
			return true
		end
	end

	return false
end

function Util.SafeCall<T>(Data: T, Fn: string, ...: any): ...any
	if typeof(Data) == "table" and typeof((Data :: any)[Fn]) == "function" then
		return (Data :: any)[Fn](...)
	end

	return
end

function Util.SafeDestroy<T>(Data: T)
	if typeof(Data) == "table" then
		table.clear(Data :: any)
		setmetatable(Data :: any, nil)
	end
end

function Util.WaitForMetadata(Inst: Instance, Tag: string, Timeout: number)
	local Attribute = `_{string.lower(Tag)}_metadata`
	local StartTime = os.clock()

	while not Inst:GetAttribute(Attribute) and os.clock() - StartTime < Timeout do
		task.wait()
	end

	local Raw = Inst:GetAttribute(Attribute)
	if typeof(Raw) == "string" then
		local Success, Decoded = pcall(HttpService.JSONDecode, HttpService, Raw)
		if Success then
			return Decoded
		end
	end

	return nil
end

return Util