
- FFI
- `obs_property_set_modified_callback`
- property callbacks return true to refresh property values from setings
- however text controls send modified on each character, and returning true removes focus from the control
- `obs_properties_add_frame_rate` - requires instances of `media_frames_per_second`. They can be created with ffi, but then are `cdata` instead of the property structure types. Do not know how to convert between cdata and types in base scripting support. If we mapped otu the property functions, we would not have a compatible properties instance to work with.
