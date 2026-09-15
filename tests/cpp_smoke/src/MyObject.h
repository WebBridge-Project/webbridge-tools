#pragma once
#include <webbridge/object.h>
#include <string>

// Minimal fixture class exercising the parts of the pipeline that matter for
// this smoke test: a property (parser + registration codegen) and a sync
// method (parser + registration codegen). Not meant to cover every feature -
// see tests/test_parser.py for that at the parser level.
class MyObject : public webbridge::object {
public:
    property<bool> a_bool{false};
    bool bar() const { return true; }
};
