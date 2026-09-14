# webbridge CMake integration - pip/conda package edition.
#
# Everything here is sourced from the installed `webbridge-tools` Python
# package (importable as `webbridge_tools`) - the C++ library source under
# webbridge/, and the code generator (with its templates) under tools/.
# No checkout of the webbridge source repo is required at configure time.
#
# Typical consumer usage:
#
#   find_package(Python REQUIRED COMPONENTS Interpreter)
#   execute_process(
#       COMMAND ${Python_EXECUTABLE} -m webbridge_tools --cmake-dir
#       OUTPUT_VARIABLE WEBBRIDGE_TOOLS_CMAKE_DIR
#       OUTPUT_STRIP_TRAILING_WHITESPACE)
#   list(APPEND CMAKE_MODULE_PATH "${WEBBRIDGE_TOOLS_CMAKE_DIR}")
#   include(webbridge)
#
#   webbridge_add_library()             # creates the webbridge::webbridge target
#   webbridge_generate(TARGET your_target AUTO)

option(WEBBRIDGE_TOOLS_PYTHON_EXECUTABLE
	"Path to the Python interpreter that has webbridge-tools installed (defaults to the interpreter found by find_package(Python))"
	"")

# Resets each time this file is include()'d (i.e. once per configure), so
# _webbridge_ensure_tools() re-checks availability on every configure, but
# only does that check once even if webbridge_generate()/webbridge_add_library()
# are called multiple times within the same configure.
unset(_WEBBRIDGE_TOOLS_CHECKED CACHE)

# Verifies that WEBBRIDGE_PYTHON_EXECUTABLE points at an interpreter with the
# webbridge_tools package installed, and resolves the package's bundled
# webbridge/ (C++ source) and tools/templates/ (code generator templates)
# directories.
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

	# .as_posix() (forward slashes) even on Windows: CMake re-embeds
	# CMAKE_MODULE_PATH/list entries into generated scratch CMakeLists.txt
	# files (e.g. try_compile for compiler-ABI detection), where a backslash
	# is parsed as an escape character. Forward slashes are always safe there.
	execute_process(
		COMMAND "${python_exe}" -c "import webbridge_tools, pathlib; print(pathlib.Path(webbridge_tools.__file__).parent.as_posix())"
		OUTPUT_VARIABLE package_dir
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

	set(WEBBRIDGE_TEMPLATES_DIR "${package_dir}/tools/templates" CACHE INTERNAL "")
	# The bundled webbridge/ C++ source tree lives directly inside package_dir.
	set(WEBBRIDGE_INCLUDE_DIR "${package_dir}" CACHE INTERNAL "")
endfunction()

# Creates the webbridge::webbridge STATIC library target from the C++ source
# bundled inside the webbridge-tools package, fetching webbridge's own two
# C++ dependencies (nlohmann_json, webview) via FetchContent.
function(webbridge_add_library)
	set(options)
	set(oneValueArgs TARGET)
	set(multiValueArgs)
	cmake_parse_arguments(PARSE_ARGV 0 arg
		"${options}" "${oneValueArgs}" "${multiValueArgs}"
	)

	if(NOT arg_TARGET)
		set(arg_TARGET webbridge)
	endif()

	if(TARGET ${arg_TARGET})
		message(FATAL_ERROR "webbridge_add_library: target '${arg_TARGET}' already exists")
	endif()

	_webbridge_ensure_tools()

	include(FetchContent)

	set(JSON_BuildTests OFF CACHE INTERNAL "")
	FetchContent_Declare(
		nlohmann_json
		GIT_REPOSITORY https://github.com/nlohmann/json
		GIT_TAG v3.11.3
		GIT_SHALLOW TRUE)
	FetchContent_MakeAvailable(nlohmann_json)

	FetchContent_Declare(
		webview
		GIT_REPOSITORY https://github.com/webview/webview
		GIT_TAG 0.12.0)
	FetchContent_MakeAvailable(webview)

	set(src "${WEBBRIDGE_INCLUDE_DIR}/webbridge")
	add_library(${arg_TARGET} STATIC
		${src}/object.h
		${src}/error.h
		${src}/impl/binding_helpers.h
		${src}/impl/concepts.h
		${src}/impl/dispatcher.h
		${src}/impl/error_handler.h
		${src}/impl/error_handler.cpp
		${src}/impl/event_impl.h
		${src}/impl/object_registry.h
		${src}/impl/property_impl.h
		${src}/impl/thread_pool.h
		${src}/impl/thread_pool.cpp
		${src}/impl/type_registration.h
		${src}/impl/type_registration.cpp
	)
	if(NOT arg_TARGET STREQUAL "webbridge")
		add_library(webbridge::${arg_TARGET} ALIAS ${arg_TARGET})
	else()
		add_library(webbridge::webbridge ALIAS webbridge)
	endif()

	target_include_directories(${arg_TARGET} PUBLIC
		$<BUILD_INTERFACE:${WEBBRIDGE_INCLUDE_DIR}>
	)

	target_compile_features(${arg_TARGET} PUBLIC cxx_std_20)

	# WebView2 (via the webview library) requires a modern Windows SDK target;
	# PUBLIC because consumers including webbridge headers pull in webview.h too.
	target_compile_definitions(${arg_TARGET} PUBLIC _WIN32_WINNT=0x0A00)

	target_link_libraries(${arg_TARGET} PUBLIC
		nlohmann_json::nlohmann_json
		webview::core
	)

	if(MSVC)
		target_compile_options(${arg_TARGET} PRIVATE /W3 /bigobj)
	endif()
endfunction()

# Helper function to parse discoverer output
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

	# Validate parameter combinations
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

	# Default to CMAKE_CURRENT_BINARY_DIR if not specified
	if(NOT arg_OUTPUT_DIR)
		set(arg_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
	endif()

	# Default to cpp if not specified
	if(NOT arg_LANGUAGE)
		set(arg_LANGUAGE cpp)
	endif()

	# Collect files to process
	set(all_files)

	# Explicit FILE + CLASS_NAME mode (no discovery)
	if(arg_FILE)
		get_filename_component(abs_file "${arg_FILE}" ABSOLUTE)
		list(APPEND all_files "${abs_file}|${arg_CLASS_NAME}")
	# Collect auto-detected header files from target if AUTO flag is set
	elseif(arg_AUTO)
		set(header_files)
		get_target_property(target_sources ${arg_TARGET} SOURCES)
		if(target_sources)
			foreach(source ${target_sources})
				# Get absolute path
				get_filename_component(abs_source "${source}" ABSOLUTE)
				# Check if it's a header file
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

			# Parse output using helper function
			_parse_discoverer_output("${discoverer_output}" all_files)
		endif()
	# Process explicit FILES - discover classes in these files
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

		# Parse output using helper function
		_parse_discoverer_output("${discoverer_output}" all_files)
	endif()

	# Check if we have any files to process
	if(NOT all_files)
		if(arg_AUTO)
			message(WARNING "webbridge_generate: No files with webbridge::object classes found in target ${arg_TARGET}")
		else()
			message(WARNING "webbridge_generate: No files to process")
		endif()
		return()
	endif()

	# Prepare batch arguments and output files
	set(batch_args)
	set(all_output_files)
	set(all_input_files)

	foreach(pair ${all_files})
		# Split pair into file and class_name
		string(REPLACE "|" ";" parts "${pair}")
		list(GET parts 0 file)
		list(GET parts 1 class_name)

		# Add to batch arguments in format "file|classname"
		list(APPEND batch_args "${file}|${class_name}")
		list(APPEND all_input_files ${file})

		# Collect output files based on LANGUAGE
		if(arg_LANGUAGE STREQUAL "cpp")
			list(APPEND all_output_files "${arg_OUTPUT_DIR}/${class_name}_registration.h")
			list(APPEND all_output_files "${arg_OUTPUT_DIR}/${class_name}_registration.cpp")
		elseif(arg_LANGUAGE STREQUAL "ts-impl")
			list(APPEND all_output_files "${arg_OUTPUT_DIR}/${class_name}.ts")
		endif()
	endforeach()

	# Determine template files (for DEPENDS tracking) and python args based on LANGUAGE
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

	# Single batch command for all files
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

	# For C++, add generated files to target and set up include paths
	if(arg_LANGUAGE STREQUAL "cpp")
		foreach(output_file ${all_output_files})
			set_source_files_properties(${output_file} PROPERTIES GENERATED TRUE)
		endforeach()
		target_sources(${arg_TARGET} PRIVATE ${all_output_files})

		# Add generated header directory to include path
		target_include_directories(${arg_TARGET} PRIVATE ${arg_OUTPUT_DIR})

		# The generated *_registration.cpp files #include the original class
		# header by name (e.g. "Counter.h"), so its directory must be on the
		# include path too. Don't rely on the caller having set
		# CMAKE_INCLUDE_CURRENT_DIR themselves.
		set(input_dirs)
		foreach(input_file ${all_input_files})
			get_filename_component(input_dir "${input_file}" DIRECTORY)
			list(APPEND input_dirs "${input_dir}")
		endforeach()
		list(REMOVE_DUPLICATES input_dirs)
		target_include_directories(${arg_TARGET} PRIVATE ${input_dirs})
	endif()
endfunction()
