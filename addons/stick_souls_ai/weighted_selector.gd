extends RefCounted
class_name WeightedSelector

static func pick_weighted_index(items: Array, weight_getter: Callable) -> int:
	if items.is_empty():
		return -1
	var total_weight := 0.0
	for item in items:
		var weight := maxf(0.0, float(weight_getter.call(item)))
		total_weight += weight
	if total_weight <= 0.0:
		return randi_range(0, items.size() - 1)
	var roll := randf() * total_weight
	for i in range(items.size()):
		roll -= maxf(0.0, float(weight_getter.call(items[i])))
		if roll <= 0.0:
			return i
	return items.size() - 1

static func pick_best_index(items: Array, score_getter: Callable) -> int:
	if items.is_empty():
		return -1
	var best_index := 0
	var best_score := -INF
	for i in range(items.size()):
		var score := float(score_getter.call(items[i]))
		if score > best_score:
			best_score = score
			best_index = i
	return best_index
