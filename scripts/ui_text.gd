class_name UiText
extends RefCounted

## Fits real font metrics inside an explicit text rectangle. Game labels and
## paragraphs share this path, including Cyrillic, numbers and manual breaks.
static func layout(face: Font, text: String, rect: Rect2, requested_size: int, wrap: bool = false, centered: bool = false) -> Dictionary:
	var minimum: int = mini(requested_size, 14)
	if rect.size.y < 24.0:
		minimum = mini(minimum, 12)
	var chosen: int = maxi(1, requested_size)
	var lines: Array[String] = []
	var fits: bool = false
	for size in range(chosen, minimum - 1, -1):
		var trial: Array[String] = _wrap(face, text, rect.size.x, size) if wrap else _explicit_lines(text)
		if _fits(face, trial, rect.size, size):
			chosen = size
			lines = trial
			fits = true
			break
	if not fits and not wrap:
		# Buttons may use two readable lines instead of spilling into neighbours.
		var trial: Array[String] = _wrap(face, text, rect.size.x, minimum)
		if _fits(face, trial, rect.size, minimum):
			chosen = minimum
			lines = trial
			fits = true
	if not fits:
		chosen = minimum
		lines = _wrap(face, text, rect.size.x, chosen)
		var count: int = maxi(1, floori((rect.size.y + 2) / (face.get_height(chosen) + 2)))
		lines.resize(mini(lines.size(), count))
		if lines.is_empty():
			lines.append("")
		lines[-1] = _elide(face, lines[-1] + "…", rect.size.x, chosen)
	var line_height: float = ceilf(face.get_height(chosen)) + 2.0
	var height: float = face.get_height(chosen) + maxi(0, lines.size() - 1) * line_height
	var top: float = rect.position.y + (rect.size.y - height) / 2.0 if centered else rect.position.y
	var runs: Array[Dictionary] = []
	for index in range(lines.size()):
		var width: float = face.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x
		var left: float = rect.position.x + (rect.size.x - width) / 2.0 if centered else rect.position.x
		runs.append({"text": lines[index], "at": Vector2(left, top + index * line_height + face.get_ascent(chosen)), "rect": Rect2(left, top + index * line_height, width, face.get_height(chosen))})
	return {"runs": runs, "font_size": chosen, "truncated": not fits, "bounds": rect, "text": text, "height": height}


static func _explicit_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for line in text.split("\n"):
		lines.append(line)
	return lines


static func _wrap(face: Font, text: String, width: float, size: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in text.split("\n"):
		var line: String = ""
		for word in paragraph.split(" ", false):
			var candidate: String = word if line.is_empty() else line + " " + word
			if face.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
				line = candidate
				continue
			if not line.is_empty():
				lines.append(line)
				line = ""
			# Long identifiers still wrap safely without relying on spaces.
			for character in word:
				if not line.is_empty() and face.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
					lines.append(line)
					line = ""
				line += character
		lines.append(line)
	return lines


static func _fits(face: Font, lines: Array[String], size: Vector2, font_size: int) -> bool:
	var line_height: float = ceilf(face.get_height(font_size)) + 2.0
	var height: float = face.get_height(font_size) + maxi(0, lines.size() - 1) * line_height
	if height > size.y + 0.01:
		return false
	for line in lines:
		if face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x + 0.01:
			return false
	return true


static func _elide(face: Font, text: String, width: float, size: int) -> String:
	var result: String = text.trim_suffix("…")
	while not result.is_empty() and face.get_string_size(result + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		result = result.left(-1)
	return result + "…"
