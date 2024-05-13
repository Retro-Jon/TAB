extends Node

func validate_file(file_path : String, type : String) -> bool:
	return file_path.ends_with(type)
