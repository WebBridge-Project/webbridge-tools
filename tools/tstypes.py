#!/usr/bin/env python3
# Supported C++ containers (nlohmann::json)
#
# Sequence containers (converted to JSON arrays):
#
# std::vector<T>
# std::deque<T>
# std::list<T>
# std::array<T, N>
# - as well as all iterable containers - are directly compatible for
#  serialization and deserialization. [deepwiki.com], [json.nlohmann.me]
#
# Associative containers (converted to JSON objects):
#
# std::map<std::string, T>
# std::unordered_map<std::string, T>
#
# - keys must be std::string, since JSON objects only allow string keys.
# [github.com], [deepwiki.com]
#
# Primitive types: int, double, bool, std::string, nullptr_t etc., all mapped natively.
# [github.com], [deepwiki.com]
#
# User-defined types are also fully integrated via to_json / from_json
# serializers, but that's beyond C++ itself. [json.nlohmann.me]


SCALAR_MAP = {
    'bool': 'boolean',
    'char': 'number',
    'signed char': 'number',
    'unsigned char': 'number',
    'short': 'number',
    'short int': 'number',
    'signed short': 'number',
    'signed short int': 'number',
    'unsigned short': 'number',
    'unsigned short int': 'number',
    'int': 'number',
    'signed': 'number',
    'signed int': 'number',
    'unsigned': 'number',
    'unsigned int': 'number',
    'long': 'number',
    'long int': 'number',
    'signed long': 'number',
    'signed long int': 'number',
    'unsigned long': 'number',
    'unsigned long int': 'number',
    'long long': 'number',
    'long long int': 'number',
    'signed long long': 'number',
    'signed long long int': 'number',
    'unsigned long long': 'number',
    'unsigned long long int': 'number',
    'uint8_t': 'number',
    'uint16_t': 'number',
    'uint32_t': 'number',
    'uint64_t': 'number',
    'int8_t': 'number',
    'int16_t': 'number',
    'int32_t': 'number',
    'int64_t': 'number',
    'size_t': 'number',
    'ssize_t': 'number',
    'float': 'number',
    'double': 'number',
    'long double': 'number',
    'std::string': 'string',
    'nullptr_t': 'null',
}

SEQ_CONTAINER_MAP = {
    'std::vector': 'Array',
    'std::deque': 'Array',
    'std::list': 'Array',
    'std::array': 'Array',
}

ASSOC_CONTAINER_MAP = {
    'std::map': 'Record',
    'std::unordered_map': 'Record',
}


def cpp_to_ts_type(cpp_type: str) -> str:
    """Converts C++ types to TypeScript types."""
    cpp_type = cpp_type.strip()
    cpp_type = cpp_type.replace('const ', '').replace('&', '').replace('*', '').strip()

    if cpp_type in SCALAR_MAP:
        return SCALAR_MAP[cpp_type]

    for container_name in SEQ_CONTAINER_MAP:
        if cpp_type.startswith(container_name + '<'):
            start = cpp_type.index('<') + 1
            end = cpp_type.rindex('>')
            inner = cpp_type[start:end].strip()

            if container_name == 'std::array' and ',' in inner:
                inner = inner[:inner.index(',')].strip()

            inner_ts = cpp_to_ts_type(inner)
            return f'{inner_ts}[]'

    for container_name in ASSOC_CONTAINER_MAP:
        if cpp_type.startswith(container_name + '<'):
            start = cpp_type.index('<') + 1
            end = cpp_type.rindex('>')
            types = cpp_type[start:end].strip()

            depth = 0
            comma_pos = -1
            for i, c in enumerate(types):
                if c == '<':
                    depth += 1
                elif c == '>':
                    depth -= 1
                elif c == ',' and depth == 0:
                    comma_pos = i
                    break

            if comma_pos != -1:
                key_type = types[:comma_pos].strip()
                value_type = types[comma_pos+1:].strip()

                if key_type != 'std::string':
                    return 'unknown'

                value_ts = cpp_to_ts_type(value_type)
                return f'Record<string, {value_ts}>'

    return 'unknown'
