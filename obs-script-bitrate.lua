obs = obslua

function script_log(message)
	obs.script_log(obs.LOG_INFO, message)
end

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
local fps = 30
local bitrate = 1000000
local bpp = 0.075

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

local fps_options = {5, 10, 15, 20, 30, 45, 60}

local video_options = {}

local min_detail = 50
local max_detail = 50

function calculate_detail()
	for r, res in ipairs(resolution_options) do
		for f, frames in ipairs(fps_options) do
			detail = res[1] * res[2] / frames
			min_detail = math.min(detail, min_detail)
			max_detail = math.max(detail, max_detail)
			video_options[#video_options+1] = {
				width = res[1],
				height = res[2],
				fps = frames,
				pps = res[1] * res[2] * frames,
				detail = detail
			}
		end
	end

	table.sort(video_options, function(a, b)
		return a.detail < b.detail
	end)
end

calculate_detail()

function display_settings()
	script_log(string.format("%dx%d %dfps @ %d %0.3fbpp %0.2f",
		width,
		height,
		fps,
		bitrate/1000,
		bpp,
		width * height / fps / 1000))
end

function capture_obs_settings()
	local encoder = obs.obs_get_encoder_by_name("simple_h264_stream")
	if encoder then
		width = obs.obs_encoder_get_width(encoder)
		height = obs.obs_encoder_get_height(encoder)
		local settings = obs.obs_encoder_get_settings(encoder)
		--script_log(obs.obs_data_get_json(settings))
		bitrate = obs.obs_data_get_int(settings, "bitrate") * 1000
		obs.obs_data_release(settings)
		obs.obs_encoder_release(encoder)
	else
		script_log("no encoder")
	end

	local video = obsffi.obs_get_video()
	if video then
		fps = obsffi.video_output_get_frame_rate(video)
	else
		script_log("no video")
	end

	bpp = bitrate / (width * height * fps)

	obs.obs_data_set_int(settings, "kbitrate", bitrate / 1000)
	obs.obs_data_set_int(settings, "height", height)
	obs.obs_data_set_int(settings, "fps", fps)
end

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
	script_log(table.concat(output, "\n"))
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Calculate bitrate tradeoffs, and maybe someday update settings in once place"
end

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	script_log("props")

	local props = obs.obs_properties_create()

	obs.obs_properties_add_int(props, "kbitrate", "KiloBitrate", 1, 6000, 50)

	local r = obs.obs_properties_add_list(props, "height", "Resolution", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, res in ipairs(resolution_options) do
		obs.obs_property_list_add_int(r, res[1] .. "x" .. res[2], res[2])
	end

	local f = obs.obs_properties_add_list(props, "fps", "FPS", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, frames in ipairs(fps_options) do
		obs.obs_property_list_add_int(f, tostring(frames), frames)
	end

	return props
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	script_log("defaults")

	obs.obs_data_set_default_int(settings, "kbitrate", bitrate/1000)
	obs.obs_data_set_default_int(settings, "height", height)
	obs.obs_data_set_default_int(settings, "fps", fps)
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	script_log("update")
	bitrate = obs.obs_data_get_int(settings, "kbitrate") * 1000
	height = obs.obs_data_get_int(settings, "height")
	for _, res in ipairs(resolution_options) do
		if res[2] == height then
			width = res[1]
			break
		end
	end
	fps = obs.obs_data_get_int(settings, "fps")

	obs.obs_data_set_int(settings, "height", height)
	obs.obs_data_set_int(settings, "fps", fps)
	bpp = bitrate / (width * height * fps)

	display_settings()
end

-- A function named script_save will be called when OBS settings are changed
-- including start and stop streaming.
--
-- NOTE: This function is usually used for saving extra data
-- Settings set via the properties are saved automatically.
function script_save(settings)
	script_log("save")
	capture_obs_settings()
end

-- a function named script_load will be called on startup
function script_load(settings)
	script_log("load")
	--dump_obs()
	capture_obs_settings()
	display_settings()
end
