obs = obslua
ffi = require("ffi")

ffi.cdef[[

struct video_output;
typedef struct video_output video_t;

double video_output_get_frame_rate(const video_t *video);

video_t *obs_get_video(void);
]]

local obsffi = ffi.load("obs")

local width = 640
local height = 360
local bitrate = 1000
local fps = 30

local resolution_options = {
	{640, 360},
	{969, 392},
	{768, 432},
	{852, 480},
	{960, 540},
	{1096, 616},
	{1152, 648},
	{1280, 720},
	{1140, 810},
	{1536, 864},
	{1600, 900},
	{1920, 1080}
}

local fps_options = {10, 15, 20, 30}

function dump_obs()
	local keys = {}
	for key,value in pairs(obs) do
		keys[#keys+1] = key
	end
	table.sort(keys)
	local output = {}
	for i,key in ipairs(keys) do
		local value = type(obs[key])
		if value == 'number' then
			value = obs[key]
		elseif value == 'string' then
			value = '"' .. obs[key] .. '"'
		end
		output[i] = key .. " : " .. value
	end
	obs.script_log(1, table.concat(output, "\n"))
end

function bad_try_enum_outputs()
	local outputs = {}
	local function capture_output(nothing, output)
		outputs[#outputs+1] = output
		return true
	end
	obs.obs_enum_outputs(capture_output, nil)
	script_log("Got " .. #outputs)
end

function inspect_output()
	local output = obs.obs_get_output_by_name("simple_stream")
	if output then
		obs.script_log(1, "got it")
		--local settings = obs.obs_output_get_settings(output)
		--obs.script_log(1, obs.obs_data_get_json(settings))
		--local video = obs.obs_output_video(output)
		--obs.script_log(1, video or "nil")
		obs.obs_data_release(settings)
		obs.obs_output_release(output)
	else
		obs.script_log(1, "no output")
	end

	--local output_types = {}
	--obs.obs_enum_output_types(100, output_types)
end

function script_description()
	return "Calculate bitrate tradeoffs, and maybe someday update settings in once place"
end

function script_properties()
	obs.script_log(1, "props")

	local props = obs.obs_properties_create()

	local r = obs.obs_properties_add_list(props, "height", "Resolution", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, res in ipairs(resolution_options) do
		obs.obs_property_list_add_int(r, res[1] .. "x" .. res[2], res[2])
	end

	local f = obs.obs_properties_add_list(props, "fps", "FPS", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, frames in ipairs(fps_options) do
		obs.obs_property_list_add_int(f, tostring(frames), frames)
	end

	obs.obs_properties_add_int(props, "bitrate", "Bitrate", 1, 6000, bitrate)

	return props
end

function script_defaults(settings)
	obs.script_log(1, "defaults")

	obs.obs_data_set_default_int(settings, "height", height)
	obs.obs_data_set_default_int(settings, "fps", fps)
	obs.obs_data_set_default_int(settings, "bitrate", bitrate)
end

function script_update(settings)
	height = obs.obs_data_get_int(settings, "height")
	for _, res in ipairs(resolution_options) do
		if res[2] == height then
			width = res[1]
			break
		end
	end
	fps = obs.obs_data_get_int(settings, "fps")
	bitrate = obs.obs_data_get_int(settings, "bitrate")
	obs.script_log(1, width .. "x" .. height .. " " .. fps .. "fps @ " .. bitrate)
end

function script_save(settings)
	obs.script_log(1, "save")
end

function script_load(settings)
	--dump_obs()
	local encoder = obs.obs_get_encoder_by_name("simple_h264_stream")
	if encoder then
		width = obs.obs_encoder_get_width(encoder)
		height = obs.obs_encoder_get_height(encoder)
		local settings = obs.obs_encoder_get_settings(encoder)
		--obs.script_log(1, obs.obs_data_get_json(settings))
		bitrate = obs.obs_data_get_int(settings, "bitrate")
		obs.obs_data_release(settings)
		obs.obs_encoder_release(encoder)
	else
		obs.script_log(1, "no encoder")
	end

	local video = obsffi.obs_get_video()
	if video then
		fps = obsffi.video_output_get_frame_rate(video)
	else
		obs.script_log(1, "no video")
	end

	obs.script_log(1, width .. "x" .. height .. " " .. fps .. "fps @ " .. bitrate)
	obs.obs_data_set_int(settings, "height", height)
	obs.obs_data_set_int(settings, "fps", fps)
	obs.obs_data_set_int(settings, "bitrate", bitrate)
end
