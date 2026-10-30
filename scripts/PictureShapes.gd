class_name PictureShapes
extends RefCounted
## Hand-drawn picture outlines (heart, apple, fish, house, tree...) for the board.
##
## Every odd level (and each chapter finale) is filled in the shape of a real thing, so
## the arrows draw a picture the player recognises. They run from bold, simple shapes on
## the small early boards to detailed ones (eyes, windows, handles) on the big late boards.
## The levels in between keep ShapeFactory's random outlines.
##
## Coordinates: about [-1, 1] on both axes, y pointing down. ShapeFactory fits each
## picture to the board, so only the proportions matter. Parts use ShapeFactory's kinds
## (circle, box, ngon, poly, heart, flower, ring); holes cut eyes and windows, and are
## filled back in on boards too small to show them.

## Picture per level, simple -> detailed.
const SCHEDULE := {
	1: "heart", 3: "apple", 5: "fish", 7: "house", 9: "tree",
	11: "cat", 13: "mushroom", 15: "star", 17: "ice_cream", 19: "pine",
	21: "rocket", 23: "butterfly", 25: "bear", 27: "ghost", 29: "pear",
	31: "cloud", 33: "crown", 35: "bird", 37: "snowman", 39: "bulb",
	41: "gem", 43: "bunny", 45: "car", 47: "cactus", 49: "owl",
	51: "sailboat", 53: "moon", 55: "duck", 57: "guitar", 59: "turtle",
	61: "mug", 63: "flower", 65: "whale", 67: "umbrella", 69: "trophy",
	71: "dog", 73: "snail", 75: "teapot", 77: "castle", 79: "robot",
	81: "lock", 83: "strawberry", 85: "balloon", 87: "cupcake", 89: "plane",
	91: "penguin", 93: "pineapple", 95: "key", 97: "hot_air_balloon", 99: "arrow",
	100: "trophy_big",
	101: "leaf", 103: "parrot", 105: "palm", 107: "frog", 109: "elephant", 110: "lion",
}

## Name shown to the player ("You drew a Fish!").
const NAMES := {
	"heart": "Heart", "apple": "Apple", "fish": "Fish", "house": "House", "tree": "Tree",
	"cat": "Cat", "mushroom": "Mushroom", "star": "Star", "ice_cream": "Ice Cream", "pine": "Pine Tree",
	"rocket": "Rocket", "butterfly": "Butterfly", "bear": "Teddy Bear", "ghost": "Ghost", "pear": "Pear",
	"cloud": "Cloud", "crown": "Crown", "bird": "Bird", "snowman": "Snowman", "bulb": "Light Bulb",
	"gem": "Diamond", "bunny": "Bunny", "car": "Car", "cactus": "Cactus", "owl": "Owl",
	"sailboat": "Sailboat", "moon": "Moon", "duck": "Duck", "guitar": "Guitar", "turtle": "Turtle",
	"mug": "Mug", "flower": "Flower", "whale": "Whale", "umbrella": "Umbrella", "trophy": "Trophy",
	"dog": "Puppy", "snail": "Snail", "teapot": "Teapot", "castle": "Castle", "robot": "Robot",
	"lock": "Lock", "strawberry": "Strawberry", "balloon": "Balloon", "cupcake": "Cupcake", "plane": "Plane",
	"penguin": "Penguin", "pineapple": "Pineapple", "key": "Key", "hot_air_balloon": "Hot Air Balloon",
	"arrow": "Arrow", "trophy_big": "Golden Cup", "leaf": "Leaf", "parrot": "Parrot", "palm": "Palm Tree",
	"frog": "Frog", "elephant": "Elephant", "lion": "Lion",
}


static func name_for(level: int) -> String:
	return NAMES.get(SCHEDULE.get(level, ""), "")


## Recipe for a level's picture, or {} if the level has none. ShapeFactory adds `fit`.
static func recipe_for(level: int) -> Dictionary:
	if not SCHEDULE.has(level):
		return {}
	return build(SCHEDULE[level])


static func build(id: String) -> Dictionary:
	var parts: Array = []
	var holes: Array = []
	var mirror := false
	match id:
		"heart":
			# Two round lobes and a point: a deep notch keeps it a heart on the tiny first board.
			parts = [_c(-0.48, -0.32, 0.52, 0.52), _poly([[-0.98, -0.2], [0, 1.0], [0, -0.1], [-0.5, -0.1]])]
			holes = [_poly([[0, -0.82], [-0.14, -0.9], [0, -0.3]])]
			mirror = true
		"apple":
			parts = [_c(-0.38, 0.08, 0.62, 0.74), _c(0.38, 0.08, 0.62, 0.74),
				_b(0, -0.74, 0.1, 0.26, 0.15), _c(0.3, -0.86, 0.26, 0.12, -0.4)]
			holes = [_c(0, 0.92, 0.14, 0.14)]
		"fish":
			parts = [_c(-0.2, 0, 0.82, 0.58), _poly([[0.45, 0], [1.1, -0.6], [0.95, 0], [1.1, 0.6]]),
				_poly([[-0.4, -0.5], [0.1, -0.85], [0.25, -0.45]])]
			holes = [_c(-0.62, -0.14, 0.11, 0.11)]
		"house":
			parts = [_b(0, 0.35, 0.72, 0.62), _poly([[-1, -0.15], [0, -1.05], [1, -0.15]]),
				_b(0.52, -0.62, 0.13, 0.3)]
			holes = [_b(0, 0.7, 0.17, 0.3), _b(-0.42, 0.22, 0.14, 0.14), _b(0.42, 0.22, 0.14, 0.14)]
		"tree":
			parts = [_c(0, -0.5, 0.58, 0.5), _c(-0.5, -0.12, 0.46, 0.42), _c(0.5, -0.12, 0.46, 0.42),
				_c(0, 0.0, 0.55, 0.42), _b(0, 0.68, 0.17, 0.45),
				_poly([[-0.17, 0.85], [-0.45, 1.15], [0.45, 1.15], [0.17, 0.85]])]
			mirror = true
		"cat":
			parts = [_c(0, 0.18, 0.88, 0.75), _poly([[-0.85, 0.0], [-0.72, -0.95], [-0.15, -0.5]])]
			holes = [_c(-0.34, 0.08, 0.12, 0.17), _poly([[-0.1, 0.38], [0.1, 0.38], [0, 0.5]])]
			mirror = true
		"mushroom":
			parts = [_poly(_dome(0, 0.05, 1.0, 0.95, 0.12)), _b(0, 0.55, 0.32, 0.48, 0.0, 0.35)]
			holes = [_c(-0.5, -0.35, 0.15, 0.15), _c(0.15, -0.6, 0.13, 0.13), _c(0.45, -0.2, 0.12, 0.12)]
		"star":
			var s := _poly(_star(5, 0.52))
			s.pos = Vector2(0, 0.08)
			parts = [s]
			mirror = true
		"ice_cream":
			parts = [_poly([[-0.55, 0.05], [0.55, 0.05], [0, 1.2]]), _c(0, -0.38, 0.78, 0.62),
				_b(0, 0.05, 0.72, 0.12, 0.0, 1.0)]
			holes = [_poly([[-0.1, 0.35], [0.1, 0.35], [0, 0.75]])]
			mirror = true
		"pine":
			parts = [_poly([[0, -1.1], [-0.5, -0.35], [0.5, -0.35]]), _poly([[0, -0.75], [-0.75, 0.15], [0.75, 0.15]]),
				_poly([[0, -0.3], [-1.0, 0.72], [1.0, 0.72]]), _b(0, 0.88, 0.17, 0.22)]
			mirror = true
		"rocket":
			parts = [_b(0, 0.15, 0.38, 0.7, 0.0, 0.5), _poly([[-0.38, -0.3], [0, -1.15], [0.38, -0.3]]),
				_poly([[-0.36, 0.15], [-0.85, 0.9], [-0.3, 0.75]]), _poly([[-0.2, 0.8], [0, 1.15], [0.2, 0.8]])]
			holes = [_c(0, -0.2, 0.17, 0.17)]
			mirror = true
		"butterfly":
			parts = [_c(-0.55, -0.42, 0.48, 0.5, -0.5), _c(-0.42, 0.48, 0.34, 0.4, 0.4),
				_b(0, 0.05, 0.13, 0.8, 0.0, 1.0)]
			holes = [_c(-1.05, 0.12, 0.35, 0.22), _c(-0.55, -0.45, 0.15, 0.15)]
			mirror = true
		"bear":
			parts = [_c(0, 0.15, 0.82, 0.78), _c(-0.66, -0.55, 0.3, 0.3)]
			holes = [_c(-0.3, -0.02, 0.11, 0.13), _c(-0.66, -0.55, 0.12, 0.12)]
			mirror = true
		"ghost":
			parts = [_c(0, -0.3, 0.82, 0.78), _b(0, 0.35, 0.82, 0.65)]
			holes = [_c(-0.4, 1.02, 0.2, 0.2), _c(0.4, 1.02, 0.2, 0.2), _c(0, 1.02, 0.2, 0.2),
				_c(-0.3, -0.3, 0.13, 0.19)]
			mirror = true
		"pear":
			parts = [_c(0, 0.38, 0.72, 0.62), _c(0, -0.3, 0.45, 0.5), _b(0.05, -0.88, 0.09, 0.2, 0.0, 0.2),
				_c(0.32, -0.9, 0.25, 0.12, -0.5)]
		"cloud":
			parts = [_c(-0.58, 0.12, 0.42, 0.4), _c(-0.1, -0.22, 0.55, 0.52), _c(0.48, -0.02, 0.45, 0.44),
				_b(0, 0.3, 0.85, 0.28, 0.0, 0.95)]
		"crown":
			parts = [_poly([[-1, 0.55], [1, 0.55], [1, -0.7], [0.5, -0.05], [0, -0.85], [-0.5, -0.05], [-1, -0.7]]),
				_c(-1, -0.72, 0.15, 0.15), _c(0, -0.88, 0.15, 0.15)]
			holes = [_c(0, 0.25, 0.14, 0.14), _c(-0.5, 0.25, 0.11, 0.11)]
			mirror = true
		"bird":
			parts = [_c(-0.05, 0.12, 0.72, 0.52, -0.25), _c(0.5, -0.42, 0.38, 0.38),
				_poly([[0.82, -0.56], [1.2, -0.38], [0.82, -0.26]]), _poly([[-0.6, 0.15], [-1.15, -0.35], [-1.05, 0.3]]),
				_b(-0.05, 0.75, 0.08, 0.2), _b(0.2, 0.75, 0.08, 0.2)]
			holes = [_c(0.6, -0.5, 0.09, 0.09)]
		"snowman":
			parts = [_c(0, 0.58, 0.7, 0.5), _c(0, -0.08, 0.48, 0.36), _c(0, -0.58, 0.32, 0.26),
				_b(0, -0.92, 0.22, 0.16), _b(0, -0.78, 0.4, 0.05)]
			holes = [_c(0, 0.48, 0.08, 0.08), _c(-0.6, 0.15, 0.25, 0.14), _c(-0.45, -0.38, 0.18, 0.1)]
			mirror = true
		"bulb":
			parts = [_c(0, -0.28, 0.78, 0.72), _b(0, 0.52, 0.34, 0.3), _b(0, 0.9, 0.24, 0.12, 0.0, 0.6)]
			holes = [_b(0, 0.55, 0.36, 0.04)]
			mirror = true
		"gem":
			parts = [_poly([[-1, -0.32], [-0.58, -0.82], [0.58, -0.82], [1, -0.32], [0, 1.0]])]
			holes = [_poly([[-0.2, -0.82], [0.2, -0.82], [0, -0.55]])]
			mirror = true
		"bunny":
			parts = [_c(0, 0.45, 0.66, 0.6), _c(-0.3, -0.45, 0.2, 0.58, -0.12)]
			holes = [_c(-0.25, 0.35, 0.1, 0.12), _c(-0.3, -0.45, 0.07, 0.38, -0.12)]
			mirror = true
		"car":
			parts = [_b(0, 0.1, 1.0, 0.36, 0.0, 0.35), _poly([[-0.6, -0.2], [-0.35, -0.75], [0.4, -0.75], [0.7, -0.2]]),
				_c(-0.55, 0.45, 0.3, 0.3), _c(0.55, 0.45, 0.3, 0.3)]
			holes = [_poly([[-0.45, -0.3], [-0.28, -0.62], [-0.02, -0.62], [-0.02, -0.3]]),
				_poly([[0.08, -0.3], [0.08, -0.62], [0.33, -0.62], [0.52, -0.3]]),
				_c(-0.55, 0.45, 0.1, 0.1), _c(0.55, 0.45, 0.1, 0.1)]
		"cactus":
			parts = [_b(0, 0.08, 0.27, 1.0, 0.0, 1.0), _b(-0.62, -0.25, 0.2, 0.42, 0.0, 1.0), _b(-0.35, 0.12, 0.35, 0.18),
				_b(0.6, 0.05, 0.2, 0.36, 0.0, 1.0), _b(0.35, 0.35, 0.35, 0.18), _b(0, 1.0, 0.5, 0.14)]
		"owl":
			parts = [_c(0, 0.15, 0.82, 0.92), _poly([[-0.75, -0.35], [-0.72, -1.05], [-0.25, -0.65]])]
			holes = [_ring(-0.35, -0.22, 0.25, 0.4), _poly([[-0.08, 0.05], [0.08, 0.05], [0, 0.22]])]
			mirror = true
		"sailboat":
			parts = [_poly([[-1, 0.5], [1, 0.5], [0.7, 0.95], [-0.7, 0.95]]),
				_poly([[-0.08, -1.05], [-0.08, 0.38], [-0.85, 0.38]]), _poly([[0.06, -0.8], [0.06, 0.38], [0.7, 0.38]]),
				_b(0, 0.42, 0.12, 0.12)]
		"moon":
			parts = [_c(0, 0, 1, 1)]
			holes = [_c(0.5, -0.28, 0.78, 0.78)]
		"duck":
			parts = [_c(-0.05, 0.38, 0.95, 0.52), _c(0.42, -0.42, 0.42, 0.42),
				_poly([[0.75, -0.42], [1.2, -0.3], [0.78, -0.18]]), _poly([[-0.75, 0.2], [-1.12, -0.12], [-0.95, 0.42]])]
			holes = [_c(0.5, -0.52, 0.09, 0.09), _c(-0.15, 0.32, 0.4, 0.14, -0.2)]
		"guitar":
			parts = [_c(0, 0.52, 0.62, 0.52), _c(0, -0.05, 0.46, 0.4), _b(0, -0.72, 0.12, 0.42),
				_b(0, -1.12, 0.2, 0.14, 0.0, 0.4)]
			holes = [_c(0, 0.18, 0.16, 0.16)]
			mirror = true
		"turtle":
			parts = [_poly(_dome(-0.1, 0.35, 0.9, 0.95, 0.0)), _c(0.92, 0.15, 0.3, 0.26),
				_b(-0.55, 0.5, 0.18, 0.2), _b(0.35, 0.5, 0.18, 0.2), _poly([[-0.9, 0.15], [-1.2, 0.35], [-0.9, 0.35]])]
			holes = [_c(-0.1, -0.15, 0.22, 0.22), _c(1.0, 0.08, 0.07, 0.07)]
		"mug":
			parts = [_b(-0.2, 0.1, 0.7, 0.85, 0.0, 0.15), _ring(0.6, 0.05, 0.42, 0.55)]
			holes = [_b(-0.2, -0.5, 0.45, 0.06)]
		"flower":
			var fl := _part("flower", Vector2(0, -0.4), Vector2(0.65, 0.65))
			fl.n = 6
			fl.a = 0.35
			parts = [fl, _b(0, 0.55, 0.1, 0.55), _c(-0.35, 0.6, 0.3, 0.14, -0.5), _c(0.35, 0.4, 0.3, 0.14, 0.5)]
			holes = [_c(0, -0.4, 0.2, 0.2)]
		"whale":
			parts = [_c(-0.2, 0.2, 0.9, 0.6), _poly([[0.55, 0.15], [1.15, -0.55], [1.0, -0.05], [1.2, 0.0], [0.65, 0.5]]),
				_b(-0.45, -0.6, 0.06, 0.25), _c(-0.6, -0.85, 0.18, 0.1), _c(-0.3, -0.85, 0.18, 0.1)]
			holes = [_c(-0.7, 0.05, 0.09, 0.09), _c(-0.35, 0.5, 0.55, 0.06)]
		"umbrella":
			parts = [_poly(_dome(0, -0.1, 1.0, 0.9, 0.0)), _b(0, 0.4, 0.13, 0.55), _ring(-0.22, 0.92, 0.12, 0.35),
				_c(0, -1.0, 0.1, 0.15)]
			holes = [_c(-0.5, 0.0, 0.28, 0.16), _c(0.5, 0.0, 0.28, 0.16), _b(-0.38, 0.78, 0.22, 0.14)]
		"trophy":
			parts = [_poly([[-0.62, -0.85], [0.62, -0.85], [0.5, -0.1], [0.12, 0.25], [-0.12, 0.25], [-0.5, -0.1]]),
				_ring(-0.62, -0.45, 0.25, 0.55), _b(0, 0.45, 0.12, 0.25), _b(0, 0.8, 0.5, 0.15)]
			holes = [_poly(_star(5, 0.5)).merged({"pos": Vector2(0, -0.48), "size": Vector2(0.24, 0.24)}, true)]
			mirror = true
		"dog":
			parts = [_c(0, 0.0, 0.7, 0.72), _c(-0.72, 0.05, 0.25, 0.55, 0.25), _c(0, 0.5, 0.42, 0.35)]
			holes = [_c(-0.28, -0.15, 0.1, 0.13), _c(0, 0.36, 0.13, 0.09)]
			mirror = true
		"snail":
			parts = [_c(0.2, -0.15, 0.72, 0.72), _b(-0.15, 0.62, 1.05, 0.22, 0.0, 1.0),
				_b(-0.95, 0.25, 0.1, 0.35, 0.3), _c(-1.05, -0.12, 0.13, 0.13)]
			holes = [_ring(0.2, -0.15, 0.3, 0.45)]
		"teapot":
			parts = [_c(0, 0.25, 0.72, 0.62), _poly([[0.55, 0.3], [1.2, -0.45], [1.25, -0.3], [0.65, 0.55]]),
				_ring(-0.75, 0.2, 0.3, 0.55), _b(0, -0.42, 0.45, 0.1), _c(0, -0.6, 0.15, 0.12), _b(0, 0.85, 0.5, 0.08)]
			holes = [_b(0, 0.2, 0.55, 0.05)]
		"castle":
			parts = [_b(0, 0.35, 0.65, 0.65), _b(-0.75, 0.1, 0.25, 0.9), _b(0.75, 0.1, 0.25, 0.9),
				_poly([[-1.05, -0.8], [-0.75, -1.2], [-0.45, -0.8]]), _poly([[0.45, -0.8], [0.75, -1.2], [1.05, -0.8]])]
			holes = [_c(0, 0.8, 0.25, 0.4), _b(-0.25, -0.3, 0.1, 0.06), _b(0.25, -0.3, 0.1, 0.06),
				_b(-0.75, -0.25, 0.08, 0.14), _b(0.75, -0.25, 0.08, 0.14)]
			mirror = true
		"robot":
			parts = [_b(0, 0.15, 0.78, 0.68, 0.0, 0.2), _b(0, -0.65, 0.06, 0.2), _c(0, -0.88, 0.14, 0.14),
				_b(-0.88, 0.1, 0.12, 0.25)]
			holes = [_c(-0.35, -0.05, 0.16, 0.16), _b(0, 0.5, 0.42, 0.08)]
			mirror = true
		"lock":
			parts = [_b(0, 0.35, 0.82, 0.65, 0.0, 0.15), _ring(0, -0.3, 0.38, 0.58)]
			holes = [_c(0, 0.22, 0.15, 0.15), _b(0, 0.45, 0.06, 0.2)]
			mirror = true
		"strawberry":
			parts = [_poly([[-0.85, -0.45], [-0.5, -0.65], [0.5, -0.65], [0.85, -0.45], [0.8, 0.0], [0.45, 0.65],
				[0, 1.0], [-0.45, 0.65], [-0.8, 0.0]]),
				_poly([[-0.6, -0.55], [-0.35, -0.95], [0, -0.7], [0.35, -0.95], [0.6, -0.55]])]
			holes = [_c(-0.35, -0.05, 0.07, 0.09), _c(0.35, -0.05, 0.07, 0.09), _c(0, 0.25, 0.07, 0.09),
				_c(-0.25, 0.5, 0.07, 0.09), _c(0.25, 0.5, 0.07, 0.09), _c(0, -0.3, 0.07, 0.09)]
		"balloon":
			parts = [_c(0, -0.3, 0.72, 0.82), _poly([[-0.15, 0.6], [0.15, 0.6], [0, 0.45]]), _b(0.05, 0.85, 0.06, 0.3, 0.2)]
			holes = [_c(-0.3, -0.6, 0.12, 0.2, 0.5)]
		"cupcake":
			parts = [_poly([[-0.75, 0.1], [0.75, 0.1], [0.55, 1.0], [-0.55, 1.0]]), _c(0, -0.1, 0.85, 0.42),
				_c(0, -0.45, 0.55, 0.38), _c(0, -0.9, 0.18, 0.18)]
			holes = [_b(-0.3, 0.55, 0.05, 0.35), _b(0.3, 0.55, 0.05, 0.35), _b(0, 0.55, 0.05, 0.38)]
			mirror = true
		"plane":
			parts = [_b(0, 0.0, 0.18, 1.0, 0.0, 1.0), _poly([[-0.12, -0.25], [-1.0, 0.15], [-1.0, 0.32], [-0.12, 0.15]]),
				_poly([[-0.1, 0.72], [-0.45, 0.95], [-0.45, 1.05], [-0.1, 0.9]])]
			holes = [_c(0, -0.6, 0.07, 0.12)]
			mirror = true
		"penguin":
			parts = [_c(0, 0.2, 0.65, 0.82), _c(0, -0.6, 0.42, 0.38), _c(-0.72, 0.3, 0.18, 0.5, 0.6),
				_c(-0.25, 1.0, 0.25, 0.1), _poly([[-0.1, -0.5], [0.1, -0.5], [0, -0.3]])]
			holes = [_c(-0.15, -0.65, 0.07, 0.08), _b(-0.42, 0.25, 0.04, 0.35)]
			mirror = true
		"pineapple":
			parts = [_c(0, 0.35, 0.65, 0.68),
				_poly([[-0.35, -0.25], [-0.65, -0.9], [-0.2, -0.55], [0, -1.15], [0.2, -0.55], [0.65, -0.9], [0.35, -0.25]])]
			holes = [_b(-0.2, 0.15, 0.08, 0.08, PI / 4), _b(0.2, 0.15, 0.08, 0.08, PI / 4), _b(0, 0.45, 0.08, 0.08, PI / 4),
				_b(-0.35, 0.65, 0.08, 0.08, PI / 4), _b(0.35, 0.65, 0.08, 0.08, PI / 4), _b(0, 0.8, 0.08, 0.08, PI / 4)]
			mirror = true
		"key":
			parts = [_ring(0, -0.55, 0.4, 0.5), _b(0, 0.3, 0.13, 0.72), _b(0.25, 0.62, 0.18, 0.08), _b(0.22, 0.88, 0.15, 0.08)]
		"hot_air_balloon":
			parts = [_c(0, -0.35, 0.85, 0.78), _poly([[-0.7, 0.05], [0.7, 0.05], [0.25, 0.6], [-0.25, 0.6]]),
				_b(-0.2, 0.75, 0.05, 0.15), _b(0.2, 0.75, 0.05, 0.15), _b(0, 0.98, 0.32, 0.16, 0.0, 0.2)]
			holes = [_b(0, 0.75, 0.13, 0.1), _b(-0.4, -0.35, 0.04, 0.6, 0.0, 1.0)]
			mirror = true
		"arrow":
			parts = [_poly([[0, -1.05], [1, -0.05], [0.42, -0.05], [0.42, 1.0], [-0.42, 1.0], [-0.42, -0.05], [-1, -0.05]])]
			mirror = true
		"trophy_big":
			parts = [_poly([[-0.62, -0.85], [0.62, -0.85], [0.5, -0.1], [0.12, 0.25], [-0.12, 0.25], [-0.5, -0.1]]),
				_ring(-0.62, -0.45, 0.25, 0.55), _b(0, 0.45, 0.12, 0.25), _b(0, 0.82, 0.55, 0.18, 0.0, 0.2),
				_poly(_star(5, 0.45)).merged({"pos": Vector2(-0.9, -0.95), "size": Vector2(0.18, 0.18)}, true)]
			holes = [_c(0, -0.45, 0.18, 0.18), _b(0, 0.82, 0.35, 0.04)]
			mirror = true
		"leaf":
			parts = [_c(0, -0.1, 0.55, 1.0, 0.45), _b(0.42, 0.9, 0.06, 0.3, 0.0, 0.45)]
			holes = [_b(0.0, -0.1, 0.035, 0.8, 0.0, 0.45)]
		"parrot":
			parts = [_c(0.1, -0.55, 0.45, 0.42), _poly([[-0.25, -0.7], [-0.6, -0.45], [-0.4, -0.1], [-0.15, -0.35]]),
				_c(0.22, 0.12, 0.52, 0.68, 0.2), _poly([[0.05, 0.6], [0.5, 0.55], [0.75, 1.2], [0.4, 1.2]]),
				_b(-0.2, 0.62, 0.5, 0.1, 0.0, 0.8)]
			holes = [_c(0.0, -0.62, 0.09, 0.09)]
		"palm":
			parts = [_poly([[-0.12, -0.4], [0.0, 1.05], [0.35, 1.05], [0.15, -0.4]]),
				_c(-0.55, -0.62, 0.6, 0.24, 0.35), _c(0.6, -0.62, 0.6, 0.24, -0.35),
				_c(-0.38, -0.92, 0.5, 0.22, -0.35), _c(0.42, -0.95, 0.5, 0.22, 0.35),
				_c(-0.15, -0.35, 0.18, 0.18), _c(0.2, -0.35, 0.18, 0.18), _b(0.15, 1.05, 0.65, 0.12, 0.0, 0.6)]
		"frog":
			parts = [_c(0, 0.25, 0.92, 0.6), _c(-0.5, -0.38, 0.3, 0.3), _c(-0.75, 0.75, 0.32, 0.18)]
			holes = [_c(-0.5, -0.38, 0.12, 0.12), _b(0, 0.35, 0.45, 0.05, 0.0, 1.0)]
			mirror = true
		"elephant":
			parts = [_c(-0.2, 0.05, 0.8, 0.6), _c(0.6, -0.2, 0.45, 0.45), _c(0.38, -0.15, 0.32, 0.45),
				_b(0.95, 0.35, 0.1, 0.45, -0.15), _b(-0.7, 0.7, 0.16, 0.3), _b(-0.15, 0.7, 0.16, 0.3),
				_b(0.3, 0.6, 0.16, 0.25), _b(-1.0, 0.0, 0.05, 0.25, 0.4)]
			holes = [_c(0.75, -0.35, 0.07, 0.07), _c(0.33, -0.15, 0.2, 0.3)]
		"lion":
			var mane := _part("flower", Vector2(0, 0), Vector2(1, 1))
			mane.n = 12
			mane.a = 0.12
			parts = [mane]
			holes = [_ring(0, 0.05, 0.62, 0.68), _c(-0.25, -0.05, 0.09, 0.11), _c(0, 0.25, 0.12, 0.08)]
			mirror = true
	return {"parts": parts, "holes": holes, "mirror": mirror, "rot": 0.0, "name": id}


# --- Part helpers ----------------------------------------------------------------------------

static func _part(kind: String, pos: Vector2, size: Vector2, rot: float = 0.0) -> Dictionary:
	return {"kind": kind, "pos": pos, "size": size, "rot": rot}


## Ellipse centred on (x, y) with radii (rx, ry), turned by `rot`.
static func _c(x: float, y: float, rx: float, ry: float, rot: float = 0.0) -> Dictionary:
	return _part("circle", Vector2(x, y), Vector2(rx, ry), rot)


## Box centred on (x, y) with half sizes (hw, hh); `round` 0..1 rounds the corners.
static func _b(x: float, y: float, hw: float, hh: float, rot: float = 0.0, round: float = 0.0) -> Dictionary:
	var p := _part("box", Vector2(x, y), Vector2(hw, hh), rot)
	p.a = round
	return p


## Ring centred on (x, y): `inner` and `outer` radius.
static func _ring(x: float, y: float, inner: float, outer: float) -> Dictionary:
	var p := _part("ring", Vector2(x, y), Vector2(outer, outer))
	p.a = inner / outer
	return p


static func _heart(x: float, y: float, w: float, h: float) -> Dictionary:
	return _part("heart", Vector2(x, y), Vector2(w, h))


static func _poly(pts: Variant) -> Dictionary:
	var p := _part("poly", Vector2.ZERO, Vector2.ONE)
	if pts is PackedVector2Array:
		p.pts = pts
	else:
		var out := PackedVector2Array()
		for q: Array in pts:
			out.append(Vector2(q[0], q[1]))
		p.pts = out
	return p


## Upper half of an ellipse with a slightly curved base (mushroom cap, shell, umbrella).
static func _dome(x: float, base_y: float, rx: float, ry: float, sag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var t := PI + i * PI / 16.0
		pts.append(Vector2(x + cos(t) * rx, base_y + sin(t) * ry))
	for i in range(1, 8):
		var u := 1.0 - i / 4.0
		pts.append(Vector2(x + u * rx, base_y + sag * (1.0 - u * u)))
	return pts


static func _star(n: int, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var rad := 1.0 if i % 2 == 0 else inner
		var ang := -PI / 2.0 + i * PI / n
		pts.append(Vector2(cos(ang), sin(ang)) * rad)
	return pts
