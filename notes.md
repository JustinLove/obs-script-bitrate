- make optimization optional, or choose target?
- description should state that no changes are made to obs settings

- FFI
- `obs_property_set_modified_callback`
- property callbacks return true to refresh property values from setings
- however text controls send modified on each character, and returning true removes focus from the control
