- poke at `obs_properties_add_frame_rate`

- FFI
- `obs_property_set_modified_callback`
- property callbacks return true to refresh property values from setings
- however text controls send modified on each character, and returning true removes focus from the control
