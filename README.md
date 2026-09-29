<div align="center">

<img src="assets/Classy.png" alt="Classy" width="420">

### A lifecycle manager for tagged instances in Luau

Make composition **and** OOP architecture feel good in Roblox.

<p>
  <a href="https://wally.run/package/jaeymo/classy"><img alt="Wally" src="https://img.shields.io/badge/wally-jaeymo%2Fclassy-orange?style=for-the-badge&logo=roblox&logoColor=white"></a>
  <a href="https://opensource.org/licenses/MIT"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge"></a>
  <a href="https://luau.org/"><img alt="Luau" src="https://img.shields.io/badge/Luau-strict-00A2FF?style=for-the-badge"></a>
</p>

<p>
  <img alt="Version" src="https://img.shields.io/badge/version-2.1.4-blue?style=flat-square">
  <a href="https://github.com/jaeymo/classy/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/jaeymo/classy?style=flat-square&color=gold"></a>
  <a href="https://github.com/jaeymo/classy/issues"><img alt="Issues" src="https://img.shields.io/github/issues/jaeymo/classy?style=flat-square"></a>
  <a href="https://github.com/jaeymo/classy/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/jaeymo/classy?style=flat-square"></a>
  <img alt="PRs welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square">
</p>

[**Quick Start**](#-quick-start) · [**Examples**](#-examples) · [**Settings**](#%EF%B8%8F-settings) · [**API**](#-api) · [**Contributing**](#-contributing)

</div>

---

> [!IMPORTANT]
> Classy is actively being worked on and features are constantly being added!

## ✨ What Is Classy?

`Classy` is a lifecycle manager built on top of `CollectionService` that makes both **composition** and **OOP architecture** more appealing in [Luau](https://luau.org/).

It is the cleaner, strictly-typed, smarter iteration of the original package, [Wrapper](https://github.com/jaeymo/wrapper), which is now archived. If you're using Wrapper, switch to `Classy`.

## 🚀 Why Use Classy?

| | Feature | What you get |
|---|---|---|
| 🧩 | **Two construction styles** | Track instances with plain functions *or* full classes |
| 🧹 | **Automatic cleanup** | Handles the class object's metatable and the provided [Janitor](https://github.com/howmanysmall/Janitor) |
| 🔒 | **Full type safety** | Generics are preserved when accessing applied objects |
| 🏛️ | **OOP-friendly** | Write classes for game objects, then track them with tags |
| 🧱 | **Composition-friendly** | Register and fetch attached components (ClassyObjects) from an instance |
| ⚡ | **Tiny API** | A whole system can fit in a few lines |

## 👀 A Taste

Isn't this great? A quick shorthand:

```lua
-- All parts with the "KillPart" tag will now kill anything with a humanoid!
Classy.new("KillPart", function(instance: BasePart, janitor: Classy.Janitor)
	janitor:Add(instance.Touched:Connect(function(hit: BasePart)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then
			return
		end

		humanoid.Health = 0
	end))
end, {
	ClassNames = { "BasePart" },
	Ancestors = { workspace },
}):Init()
```

## 📦 Quick Start

### Install

<details open>
<summary><b>Wally</b> (recommended)</summary>

Add Classy to your `wally.toml`:

```toml
[dependencies]
Classy = "jaeymo/classy@2.1.4"
```

Then run:

```bash
wally install
```

Or grab it from the [Wally package page](https://wally.run/package/jaeymo/classy?version=2.1.4).

</details>

### Dependencies

| Package | Purpose |
|---|---|
| [Janitor](https://github.com/howmanysmall/Janitor) | Cleanup of connections and objects |
| [Signal](https://github.com/Sleitnick/RbxUtil/blob/main/modules/signal/init.luau) | Events like `InstanceAdded` |

## 🧪 Examples

Classy's best feature is that you can use **function-based** or **class-based** construction, and both build the same underlying system. Here's the class used in the examples below:

<details>
<summary><b>📄 KillPartClass (click to expand)</b></summary>

```lua
--!strict

local Classy = require(path.to.classy)

local KillPartClass = {}
KillPartClass.__index = KillPartClass

export type KillPart = typeof(setmetatable({} :: {
	Part: BasePart,
	Janitor: Classy.Janitor,
}, KillPartClass))

function KillPartClass.new(part: Instance, janitor: Classy.Janitor): KillPart
	return setmetatable({
		Part = part :: BasePart,
		Janitor = janitor,
	}, KillPartClass)
end

function KillPartClass.Init(self: KillPart)
	self.Janitor:Add(self.Part.Touched:Connect(function(hit: BasePart)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid")

		if not humanoid then
			return
		end

		humanoid.Health = 0
	end))
end

function KillPartClass.DoSomething(self: KillPart)
	print(self)
end

function KillPartClass.Destroy(self: KillPart)
	print("This object has been destroyed!")
end
```

</details>

### 🏛️ Class-based construction

```lua
local KillPartClassy = Classy.newClass("KillPart", KillPartClass, {
	ClassNames = { "BasePart" },
	Ancestors = { workspace },
	Logging = true,
})
```

### 🧩 Function-based construction

```lua
local AnotherExample = Classy.new("KillPart", function(instance: Instance, janitor: Classy.Janitor)
	return KillPartClass.new(instance, janitor)
end, {
	ClassNames = { "BasePart" },
	Ancestors = { workspace },
	Logging = true,
})
```

### ▶️ Initialize

```lua
KillPartClassy:Init()
AnotherExample:Init()
```

### 🔌 Interact with applied objects

Once initialized, you can interact with applied objects directly. `ObserveApplied` covers both instances that are already applied and ones added later:

```lua
KillPartClassy:ObserveApplied(function(instance, applied)
	applied:GetData():DoSomething()
end)
```

Prefer a raw signal? `KillPartClassy.InstanceAdded` fires only for instances applied from now on, and `InstanceRevoked` fires when they are removed.

> [!TIP]
> Building something simple that doesn't need a class? Use the shorthand from [A Taste](#-a-taste). It's the same system with less boilerplate.

## ⚙️ Settings

Both `Classy.new` and `Classy.newClass` accept an optional `Config` table (`ClassyConfig`) as their last argument. Every option is optional:

| Option | Type | Default | Description |
|---|---|---|---|
| `ClassNames` | `{ string }` | `{}` | Instances must pass `IsA` for **at least one** listed class name. Empty means no restriction |
| `Ancestors` | `{ Instance }` | `{}` | Instances must be a descendant of **at least one** listed ancestor. Empty means no restriction |
| `Predicate` | `(Instance) -> boolean` | `nil` | Custom check. Return `false` to skip an instance |
| `Logging` | `boolean` | `false` | Prints when instances are applied, revoked, and cleaned up |
| `RemoveTagOnCleanup` | `boolean` | `true` | Removes the tag from the instance when it is revoked (including when the Classy is destroyed) |
| `Nuke` | `boolean` | `true` | When an applied object is destroyed, also clears the table your constructor returned and removes its metatable |
| `NamingConvention` | `{ Init: string, Destroy: string }` | `{ Init = "Init", Destroy = "Destroy" }` | Method names Classy calls on your object for its lifecycle |
| `WaitForMetadata` | `boolean` | `false` | Waits up to 7 seconds for an instance's [metadata attribute](#metadata) before applying it |
| `Context` | `{ any }` | `{}` | Table handed to your constructor as its third argument |

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

> [!NOTE]
> **Lifecycle methods are automatic.** After your object is constructed, Classy calls its `Init` method (if it has one), and calls `Destroy` when the instance is revoked. Rename them with `NamingConvention`. `Init` runs *before* the object is registered, so inside `Init` the object can't yet be found with `getComponent` or `GetApplied`. Use `ObserveApplied` for that.

> [!NOTE]
> **When checks run.** `ClassNames`, `Ancestors`, and `Predicate` are checked when an instance gets the tag (or joins the game with it) and again whenever an applied instance's ancestry changes. An instance that stops passing is revoked, and it is **not** re-applied automatically if it passes again later. Re-tag it or call `:Apply` yourself.

## 📚 API

### Constructors

| Function | Returns | Description |
|---|---|---|
| `Classy.new(Tag, Constructable, Config?)` | `Classy<T>` | Function-based construction |
| `Classy.newClass(Tag, Constructable, Config?)` | `Classy<T>` | Class-based construction |

Your function (or your class's `new`) is called with the same four arguments:

| # | Argument | Description |
|---|---|---|
| 1 | `Instance` | The tagged instance |
| 2 | `Janitor` | A Janitor that is cleaned up when the instance is revoked |
| 3 | `Context` | The `Context` table from your config |
| 4 | `Metadata?` | The metadata the instance was applied with, if any |

```lua
Classy.new("Door", function(instance, janitor, context, metadata)
	-- ...
end)

function DoorClass.new(instance, janitor, context, metadata)
	-- ...
end
```

### Working with components

Every applied object is registered on its instance, so you can fetch and drive an instance's components from anywhere.

| Function | Returns | Description |
|---|---|---|
| `Classy.getComponent(Inst, Tag)` | `Applied<any>?` | Get the component applied to `Inst` under `Tag` |
| `Classy.getComponents(Inst)` | `{ [string]: Applied<any> }?` | Get every component applied to `Inst`, keyed by tag |
| `Classy.callOnAllComponents(Inst, MethodName, ...)` | | Calls `MethodName` (with `...`) on every component of `Inst` that has that method |
| `Classy.applyComponents(Inst, Components)` | | Applies each listed component to `Inst` (and tags it), passing its metadata. Each tag must be [registered globally](#global-registry) |
| `Classy.emit(Inst, TriggerName, Context?)` | | Fires a trigger; components that map `TriggerName` to a method get that method called with `Context` |

```lua
-- Grab a specific component and use it
local killPart = Classy.getComponent(workspace.Lava, "KillPart")
if killPart then
	killPart:GetData():DoSomething()
end

-- Call a method on every component the instance has
Classy.callOnAllComponents(workspace.Lava, "DoSomething")

-- Attach components at runtime, with per-component metadata.
-- The tag must be registered globally first!
Classy.registerGlobal("KillPart", KillPartClassy)

Classy.applyComponents(workspace.Lava, {
	KillPart = { Damage = 25 },
})

-- Fire a trigger
Classy.emit(workspace.Lava, "Activated", { Source = "Lever" })
```

#### Triggers

A component can declare triggers in its metadata under `Triggers`, mapping a trigger name to one of its methods. `Classy.emit` then calls that method with the context you pass:

```lua
Classy.registerGlobal("Door", DoorClassy)

Classy.applyComponents(door, {
	Door = {
		Triggers = { Activated = "Open" },
	},
})

-- Calls door's Door component: Data:Open({ Source = "Lever" })
Classy.emit(door, "Activated", { Source = "Lever" })
```

#### Component aliases

Metadata can include `UseComponent` (or `useComponent`) naming another globally registered component. Classy builds a copy of that component's Classy for the new tag, so one constructor can power many differently-configured components:

```lua
Classy.registerGlobal("Inventory", InventoryClassy)
Classy.registerGlobal("Resource", ResourceClassy)

Classy.applyComponents(player, {
	Inventory = { MaxItemAmount = 20 },

	-- Built from the Resource component instead of an "Ammo" Classy
	Ammo = {
		UseComponent = "Resource",
		StartingAmount = 0,
		MaxCount = 0,
	},
})
```

The alias reuses the base's constructor and config (`ClassNames`, `Ancestors`, `Predicate`, `NamingConvention`, `Logging`, `RemoveTagOnCleanup`, `Nuke`, `WaitForMetadata`) and gets its own tag. Its `Context` is a copy of the base's with `tag` set to the alias tag. If the base isn't registered, Classy warns and skips the component.

#### Metadata

Metadata passed to `Apply` or `applyComponents` is handed to your constructor as its fourth argument and saved on the instance as a JSON attribute named `_<lowercase tag>_metadata` (for example `_door_metadata`), so it must only contain JSON-serializable values (no functions or Instances). With `WaitForMetadata = true`, Classy waits up to 7 seconds for that attribute to exist before applying, which lets you tag an instance first and set its metadata attribute (as a JSON string) afterwards.

### Global registry

| Function | Returns | Description |
|---|---|---|
| `Classy.registerGlobal(Tag, ClassyInstance)` | | Register a Classy object globally under `Tag`. Required for `applyComponents` and `UseComponent` |
| `Classy.getGloballyRegistered(Tag)` | `Classy<any>?` | Look up a globally registered Classy object |

### Classy objects

What `Classy.new` and `Classy.newClass` return.

| Member | Returns | Description |
|---|---|---|
| `:Init()` | | Applies all currently tagged instances that pass the checks and starts listening for new and removed ones. Call it once |
| `:CanBeApplied(Inst)` | `boolean` | Whether `Inst` passes `ClassNames`, `Ancestors`, and `Predicate` |
| `:Apply(Inst, Metadata?)` | `Applied<T>` | Applies `Inst`, bypassing `CanBeApplied`. Returns the existing one if already applied |
| `:Revoke(Inst)` | | Destroys the applied object, removes it from Classy, and removes the tag (unless `RemoveTagOnCleanup = false`) |
| `:GetApplied(Inst)` | `Applied<T>?` | Get the applied object for `Inst`, if any |
| `:GetAll()` | `{ [Instance]: Applied<T> }` | Every applied object |
| `:ObserveApplied(Callback)` | `Connection` | Runs `Callback(Instance, Applied)` for every existing applied object **and** every future one |
| `:Destroy()` | | Revokes everything, cleans up its Janitor and signals, and makes the Classy unusable |
| `.InstanceAdded` | `Signal<Instance, Applied<T>>` | Fires when an instance is applied |
| `.InstanceRevoked` | `Signal<Instance>` | Fires after an instance is revoked |

```lua
local connection = KillPartClassy:ObserveApplied(function(instance, applied)
	applied:GetData():DoSomething()
end)

-- Later
connection:Disconnect()
```

> [!WARNING]
> Revoking clears the `Applied` wrapper, and `Classy:Destroy()` clears the Classy, so don't use either afterwards. With `Nuke = true` (the default), revoking also clears your object's table and removes its metatable. Set `Nuke = false` if you need your object to stay intact after it's revoked.

### Applied objects

The wrapper Classy keeps for each instance.

| Member | Description |
|---|---|
| `:GetData()` | Returns what your constructor or class produced |
| `:Destroy()` | Runs your `Destroy` method, cleans its Janitor, and clears the object. Called by `Revoke`, so prefer `Classy:Revoke(Inst)` over calling this yourself |
| `.Instance` | The instance it's attached to |
| `.Classy` | The Classy that owns it |
| `.Janitor` | The Janitor handed to your constructor |
| `.Data` | Same as `:GetData()` |
| `.Triggers` | The trigger map from its metadata, if any |

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. Fork the repo
2. Create your branch: `git checkout -b feature/cool-thing`
3. Commit your changes: `git commit -m "Add cool thing"`
4. Push and open a Pull Request

Check the [issues page](https://github.com/jaeymo/classy/issues) for things to work on.

## 📄 License

Released under the [MIT License](https://opensource.org/licenses/MIT).

---

<div align="center">

If Classy helps you, consider leaving a ⭐. It really helps!

</div>