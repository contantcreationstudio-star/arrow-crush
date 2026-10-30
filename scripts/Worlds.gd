class_name Worlds
extends RefCounted
## The 25 worlds of levels 1-500 (20 levels each), shared by the map, Home and music.
## Each world: name, card colours (top / bottom of the header gradient), accent (finished
## level tiles), deco family (Affinity props on the card) and a shade of the music.

const LEVELS_PER_WORLD := 20

const LIST: Array[Dictionary] = [
	{"name": "Sunny Meadow", "top": Color("#4ade80"), "bottom": Color("#16a34a"), "accent": Color("#16a34a"), "deco": "tree"},
	{"name": "Bubble Bay", "top": Color("#38bdf8"), "bottom": Color("#0369a1"), "accent": Color("#0284c7"), "deco": "bubble"},
	{"name": "Arrowland", "top": Color("#f472b6"), "bottom": Color("#be185d"), "accent": Color("#db2777"), "deco": "candy"},
	{"name": "Sunset Dunes", "top": Color("#fb923c"), "bottom": Color("#c2410c"), "accent": Color("#ea580c"), "deco": "cactus"},
	{"name": "Star Galaxy", "top": Color("#818cf8"), "bottom": Color("#3730a3"), "accent": Color("#6d28d9"), "deco": "space"},
	{"name": "Snake Jungle", "top": Color("#34d399"), "bottom": Color("#047857"), "accent": Color("#059669"), "deco": "tree"},
	{"name": "Coral Reef", "top": Color("#2dd4bf"), "bottom": Color("#0f766e"), "accent": Color("#0d9488"), "deco": "bubble"},
	{"name": "Sugar Peaks", "top": Color("#e879f9"), "bottom": Color("#a21caf"), "accent": Color("#c026d3"), "deco": "candy"},
	{"name": "Red Canyon", "top": Color("#f87171"), "bottom": Color("#b91c1c"), "accent": Color("#dc2626"), "deco": "cactus"},
	{"name": "Nebula Drift", "top": Color("#a78bfa"), "bottom": Color("#5b21b6"), "accent": Color("#7c3aed"), "deco": "space"},
	{"name": "Maple Woods", "top": Color("#fbbf24"), "bottom": Color("#b45309"), "accent": Color("#d97706"), "deco": "tree"},
	{"name": "Lagoon Isles", "top": Color("#22d3ee"), "bottom": Color("#0e7490"), "accent": Color("#0891b2"), "deco": "bubble"},
	{"name": "Cookie Castle", "top": Color("#fda4af"), "bottom": Color("#e11d48"), "accent": Color("#e11d48"), "deco": "candy"},
	{"name": "Pyramid Sands", "top": Color("#facc15"), "bottom": Color("#a16207"), "accent": Color("#ca8a04"), "deco": "cactus"},
	{"name": "Comet Coast", "top": Color("#60a5fa"), "bottom": Color("#1e40af"), "accent": Color("#2563eb"), "deco": "space"},
	{"name": "Misty Forest", "top": Color("#86efac"), "bottom": Color("#15803d"), "accent": Color("#16a34a"), "deco": "tree"},
	{"name": "Pearl Shores", "top": Color("#7dd3fc"), "bottom": Color("#0284c7"), "accent": Color("#0ea5e9"), "deco": "bubble"},
	{"name": "Jelly Hills", "top": Color("#c084fc"), "bottom": Color("#7e22ce"), "accent": Color("#9333ea"), "deco": "candy"},
	{"name": "Mesa Ridge", "top": Color("#fdba74"), "bottom": Color("#9a3412"), "accent": Color("#ea580c"), "deco": "cactus"},
	{"name": "Moon Base", "top": Color("#94a3b8"), "bottom": Color("#334155"), "accent": Color("#475569"), "deco": "space"},
	{"name": "Bamboo Grove", "top": Color("#a3e635"), "bottom": Color("#4d7c0f"), "accent": Color("#65a30d"), "deco": "tree"},
	{"name": "Tide Pools", "top": Color("#5eead4"), "bottom": Color("#115e59"), "accent": Color("#14b8a6"), "deco": "bubble"},
	{"name": "Cupcake Town", "top": Color("#f9a8d4"), "bottom": Color("#db2777"), "accent": Color("#ec4899"), "deco": "candy"},
	{"name": "Sunstone Valley", "top": Color("#fcd34d"), "bottom": Color("#d97706"), "accent": Color("#f59e0b"), "deco": "cactus"},
	{"name": "Rainbow Summit", "top": Color("#f472b6"), "bottom": Color("#6d28d9"), "accent": Color("#8b5cf6"), "deco": "space"},
]


## World index (0-based) of a level.
static func of(level: int) -> int:
	return clampi((level - 1) / LEVELS_PER_WORLD, 0, LIST.size() - 1)


static func name_of(w: int) -> String:
	return String(LIST[clampi(w, 0, LIST.size() - 1)].name)


## First level of world `w`.
static func first_level(w: int) -> int:
	return w * LEVELS_PER_WORLD + 1
