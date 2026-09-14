# Makes this a regular (not implicit-namespace) package so the editable-install
# finder resolves it correctly: webbridge_tools.cmake is mapped in here from
# outside src/webbridge_tools/ (see pyproject.toml package-dir), and setuptools'
# editable-install finder doesn't reliably resolve dotted package-dir mappings
# for namespace (no __init__.py) packages.
