option(WEBBRIDGE_TOOLS_PYTHON_EXECUTABLE
	"Path to the Python interpreter that has webbridge-tools installed (defaults to the interpreter found by find_package(Python))"
	"")

unset(_WEBBRIDGE_TOOLS_CHECKED CACHE)

function(_webbridge_ensure_tools)
	if(_WEBBRIDGE_TOOLS_CHECKED)
		return()
	endif()
	set(_WEBBRIDGE_TOOLS_CHECKED TRUE CACHE INTERNAL "")

	if(WEBBRIDGE_TOOLS_PYTHON_EXECUTABLE)
		set(python_exe "${WEBBRIDGE_TOOLS_PYTHON_EXECUTABLE}")
	else()
		find_package(Python REQUIRED COMPONENTS Interpreter)
		set(python_exe "${Python_EXECUTABLE}")
	endif()
	set(WEBBRIDGE_PYTHON_EXECUTABLE "${python_exe}" CACHE INTERNAL "")

	execute_process(
		COMMAND "${python_exe}" -c "import webbridge_tools.tools, pathlib; print(pathlib.Path(next(iter(webbridge_tools.tools.__path__))).as_posix())"
		OUTPUT_VARIABLE tools_dir
		OUTPUT_STRIP_TRAILING_WHITESPACE
		RESULT_VARIABLE import_result
		ERROR_VARIABLE import_error
	)

	if(NOT import_result EQUAL 0)
		message(FATAL_ERROR
			"webbridge: the 'webbridge_tools' Python package is not importable with "
			"'${python_exe}'. Install it with 'pip install webbridge-tools' (or "
			"'conda install webbridge-tools' if available from your channel), or "
			"point WEBBRIDGE_TOOLS_PYTHON_EXECUTABLE at an interpreter that has it "
			"installed.\n${import_error}")
	endif()

	set(WEBBRIDGE_TEMPLATES_DIR "${tools_dir}/templates" CACHE INTERNAL "")
endfunction()

function(_parse_discoverer_output discoverer_output out_var)
	set(result)
	if(discoverer_output)
		string(REPLACE "\n" ";" lines "${discoverer_output}")
		foreach(line ${lines})
			if(line)
				string(REPLACE "|" ";" parts "${line}")
				list(GET parts 0 file)
				list(GET parts 1 class_name)
				list(APPEND result "${file}|${class_name}")
			endif()
		endforeach()
	endif()
	set(${out_var} ${result} PARENT_SCOPE)
endfunction()

function(webbridge_generate)
	_webbridge_ensure_tools()

	set(options AUTO)
	set(oneValueArgs TARGET OUTPUT_DIR LANGUAGE FILE CLASS_NAME)
	set(multiValueArgs FILES)
	cmake_parse_arguments(PARSE_ARGV 0 arg
		"${options}" "${oneValueArgs}" "${multiValueArgs}"
	)

	if(arg_FILE AND arg_FILES)
		message(FATAL_ERROR "webbridge_generate: Use either FILE or FILES, not both")
	endif()

	if(arg_FILE AND arg_AUTO)
		message(FATAL_ERROR "webbridge_generate: FILE cannot be used with AUTO")
	endif()

	if(arg_AUTO AND arg_FILES)
		message(FATAL_ERROR "webbridge_generate: Use either AUTO or FILES, not both")
	endif()

	if(arg_FILE AND NOT arg_CLASS_NAME)
		message(FATAL_ERROR "webbridge_generate: FILE requires CLASS_NAME")
	endif()

	if(arg_CLASS_NAME AND NOT arg_FILE)
		message(FATAL_ERROR "webbridge_generate: CLASS_NAME requires FILE")
	endif()

	if(NOT arg_AUTO AND NOT arg_FILES AND NOT arg_FILE)
		message(FATAL_ERROR "webbridge_generate: Either AUTO, FILES, or FILE must be specified")
	endif()

	if(NOT arg_OUTPUT_DIR)
		set(arg_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
	endif()

	if(NOT arg_LANGUAGE)
		set(arg_LANGUAGE cpp)
	endif()

	set(all_files)

	if(arg_FILE)
		get_filename_component(abs_file "${arg_FILE}" ABSOLUTE)
		list(APPEND all_files "${abs_file}|${arg_CLASS_NAME}")

	elseif(arg_AUTO)
		set(header_files)
		get_target_property(target_sources ${arg_TARGET} SOURCES)
		if(target_sources)
			foreach(source ${target_sources})

				get_filename_component(abs_source "${source}" ABSOLUTE)

				if(abs_source MATCHES "\\.(h|hpp)$")
					list(APPEND header_files ${abs_source})
				endif()
			endforeach()
		endif()

		if(header_files)
			execute_process(
				COMMAND ${WEBBRIDGE_PYTHON_EXECUTABLE} -m webbridge_tools.tools.discoverer
					${header_files}
				WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
				OUTPUT_VARIABLE discoverer_output
				OUTPUT_STRIP_TRAILING_WHITESPACE
				RESULT_VARIABLE result
			)

			if(result AND NOT result EQUAL 0)
				message(FATAL_ERROR "webbridge_tools.tools.discoverer failed with exit code ${result}")
			endif()

			_parse_discoverer_output("${discoverer_output}" all_files)
		endif()

	elseif(arg_FILES)
		set(abs_files)
		foreach(file ${arg_FILES})
			get_filename_component(abs_file "${file}" ABSOLUTE)
			list(APPEND abs_files ${abs_file})
		endforeach()

		execute_process(
			COMMAND ${WEBBRIDGE_PYTHON_EXECUTABLE} -m webbridge_tools.tools.discoverer
				${abs_files}
			WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
			OUTPUT_VARIABLE discoverer_output
			OUTPUT_STRIP_TRAILING_WHITESPACE
			RESULT_VARIABLE result
		)

		if(result AND NOT result EQUAL 0)
			message(FATAL_ERROR "webbridge_tools.tools.discoverer failed with exit code ${result}")
		endif()

		_parse_discoverer_output("${discoverer_output}" all_files)
	endif()

	if(NOT all_files)
		if(arg_AUTO)
			message(WARNING "webbridge_generate: No files with webbridge::object classes found in target ${arg_TARGET}")
		else()
			message(WARNING "webbridge_generate: No files to process")
		endif()
		return()
	endif()

	set(batch_args)
	set(all_output_files)
	set(all_input_files)

	foreach(pair ${all_files})

		string(REPLACE "|" ";" parts "${pair}")
		list(GET parts 0 file)
		list(GET parts 1 class_name)

		list(APPEND batch_args "${file}|${class_name}")
		list(APPEND all_input_files ${file})

		if(arg_LANGUAGE STREQUAL "cpp")
			list(APPEND all_output_files "${arg_OUTPUT_DIR}/${class_name}_registration.h")
			list(APPEND all_output_files "${arg_OUTPUT_DIR}/${class_name}_registration.cpp")
		elseif(arg_LANGUAGE STREQUAL "ts-impl")
			list(APPEND all_output_files "${arg_OUTPUT_DIR}/${class_name}.ts")
		endif()
	endforeach()

	if(arg_LANGUAGE STREQUAL "cpp")
		set(template_files
			"${WEBBRIDGE_TEMPLATES_DIR}/registration_header.h.j2"
			"${WEBBRIDGE_TEMPLATES_DIR}/registration_impl.cpp.j2"
		)
		set(python_out_arg --cpp_out)
	elseif(arg_LANGUAGE STREQUAL "ts-impl")
		set(template_files "${WEBBRIDGE_TEMPLATES_DIR}/impl.ts.j2")
		set(python_out_arg --ts_impl_out)
	else()
		message(FATAL_ERROR "Invalid LANGUAGE: ${arg_LANGUAGE}. Must be 'cpp' or 'ts-impl'")
	endif()

	list(LENGTH all_files file_count)
	add_custom_command(
		OUTPUT ${all_output_files}
		COMMAND ${WEBBRIDGE_PYTHON_EXECUTABLE} -m webbridge_tools.tools.generate
			--batch
			${batch_args}
			${python_out_arg}
			${arg_OUTPUT_DIR}
		DEPENDS
			${template_files}
			${all_input_files}
		COMMENT "Generating ${arg_LANGUAGE} (batch of ${file_count} files)"
		VERBATIM
	)

	if(arg_LANGUAGE STREQUAL "cpp")
		foreach(output_file ${all_output_files})
			set_source_files_properties(${output_file} PROPERTIES GENERATED TRUE)
		endforeach()
		target_sources(${arg_TARGET} PRIVATE ${all_output_files})

		target_include_directories(${arg_TARGET} PRIVATE ${arg_OUTPUT_DIR})

		set(input_dirs)
		foreach(input_file ${all_input_files})
			get_filename_component(input_dir "${input_file}" DIRECTORY)
			list(APPEND input_dirs "${input_dir}")
		endforeach()
		list(REMOVE_DUPLICATES input_dirs)
		target_include_directories(${arg_TARGET} PRIVATE ${input_dirs})
	endif()
endfunction()
