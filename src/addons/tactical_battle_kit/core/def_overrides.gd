class_name DefOverrides
extends RefCounted

## Patches exported script properties on a Resource from a dictionary, with
## the value coerced to the property's current type. Validates against the
## script's own property list, so subclass fields sweep with no kit change and
## a typo in a sweep is an error rather than a silent no-op.


static func apply(target: Resource, overrides: Dictionary, label: String) -> void:
	var exported := exported_property_names(target)
	for key_variant: Variant in overrides.keys():
		var key := str(key_variant)
		if key not in exported:
			push_error("%s has no exported property '%s'." % [label, key])
			continue
		target.set(key, coerce(target.get(key), overrides.get(key_variant)))


static func exported_property_names(target: Object) -> Array[String]:
	var names: Array[String] = []
	for info_variant: Variant in target.get_property_list():
		var info: Dictionary = info_variant
		var usage := int(info.get("usage", 0))
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			names.append(str(info.get("name")))
	return names


## Coerce [param value] to the runtime type of [param current].
static func coerce(current: Variant, value: Variant) -> Variant:
	match typeof(current):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return bool(value)
		TYPE_STRING:
			return str(value)
		TYPE_COLOR:
			return Color.html(str(value)) if value is String else value
		TYPE_VECTOR2I:
			if value is Array:
				return Vector2i(int(value[0]), int(value[1]))
			return value
		TYPE_ARRAY:
			var current_array: Array = current
			var next: Array = current_array.duplicate()
			next.clear()
			for item: Variant in value:
				if current_array.is_typed() and current_array.get_typed_builtin() == TYPE_VECTOR2I and item is Array:
					next.append(Vector2i(int(item[0]), int(item[1])))
				elif current_array.is_typed() and current_array.get_typed_builtin() == TYPE_STRING:
					next.append(str(item))
				else:
					next.append(item)
			return next
		TYPE_DICTIONARY:
			var current_dict: Dictionary = current
			var next_dict: Dictionary = current_dict.duplicate()
			next_dict.clear()
			for k: Variant in value.keys():
				next_dict[k] = value[k]
			return next_dict
	return value


## Every exported property as a dictionary, JSON-friendly.
static func to_dict(target: Resource) -> Dictionary:
	var data := {}
	for name: String in exported_property_names(target):
		data[name] = jsonify(target.get(name))
	return data


static func jsonify(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I:
			var v: Vector2i = value
			return [v.x, v.y]
		TYPE_COLOR:
			var c: Color = value
			return c.to_html()
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(jsonify(item))
			return items
		TYPE_DICTIONARY:
			var result := {}
			for k: Variant in value.keys():
				result[str(k)] = jsonify(value[k])
			return result
	return value
