
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
  <img alt="Version" src="https://img.shields.io/badge/version-2.1.2-blue?style=flat-square">
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
Classy = "jaeymo/classy@2.1.2"
```

Then run:

```bash
wally install
```

Or grab it from the [Wally package page](https://wally.run/package/jaeymo/classy?version=2.1.2).

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
	self:_watchTouchedEvent()
end

function KillPartClass.DoSomething(self: KillPart)
	print(self)
end

function KillPartClass.Destroy(self: KillPart)
	print("This object has been destroyed!")
end

function KillPartClass._watchTouchedEvent(self: KillPart)
	self.Janitor:Add(self.Part.Touched:Connect(function(hit: BasePart)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid")

		if not humanoid then
			return
		end

		humanoid.Health = 0
	end))
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

Once initialized, you can interact with applied objects directly:

```lua
KillPartClassy.InstanceAdded:Connect(function(instance, applied)
	applied:GetData():DoSomething()
end)
```

> [!TIP]
> Building something simple that doesn't need a class? Use the shorthand from [A Taste](#-a-taste). It's the same system with less boilerplate.

## ⚙️ Settings

Both `Classy.new` and `Classy.newClass` accept a settings table as their last argument:

| Setting | Type | Description |
|---|---|---|
| `ClassNames` | `{ string }` | Only instances that are one of these classes (via `IsA`) are applied |
| `Ancestors` | `{ Instance }` | Only instances inside these ancestors are applied |
| `Logging` | `boolean` | Prints lifecycle information for debugging |

<!-- Add any other settings here, with their type and description -->

## 📚 API

| Member | Description |
|---|---|
| `Classy.new(tag, constructor, settings)` | Function-based construction |
| `Classy.newClass(tag, class, settings)` | Class-based construction |
| `:Init()` | Start tracking tagged instances |
| `.InstanceAdded` | Signal fired when an instance gets an applied object |
| `applied:GetData()` | Returns the object your constructor/class produced |

<!-- Fill in the rest of your API (InstanceRemoved, Destroy, etc.) here -->

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