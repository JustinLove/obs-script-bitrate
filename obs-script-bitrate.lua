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

local my_settings = nil
local optimization_target = "resolution"

local optimization_options = {
	"none",
	"bitrate",
	"resolution",
	"fps",
}

local width = 1152
local height = 648
local fps = 30
local bitrate = 2500
local target_bpp = 0.100
local bpp = 0.100

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

local fps_options = {10, 15, 20, 30, 45, 60}

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

function capture_obs_settings(settings)
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
	obs.obs_data_set_int(settings, "mbpp", math.floor(bpp * 1000))
	obs.obs_data_set_int(settings, "height", height)
	obs.obs_data_set_int(settings, "fps", fps)
end

function optimize_bitrate(settings)
	bitrate = width * height * fps * target_bpp

	obs.obs_data_set_int(settings, "kbitrate", bitrate / 1000)
	update_bpp(settings)
end

function optimize_resolution(settings)
	local target_pps = bitrate / target_bpp
	local best_option = video_options[1]
	for _,option in ipairs(video_options) do
		if option.fps == fps then
			if math.abs(target_pps - option.pps) < math.abs(target_pps - best_option.pps) then
				best_option = option
			end
		end
	end

	width = best_option.width
	height = best_option.height
	obs.obs_data_set_int(settings, "height", height)

	update_bpp(settings)
end

function optimize_fps(settings)
	local target_pps = bitrate / target_bpp
	local best_option = video_options[1]
	for _,option in ipairs(video_options) do
		if option.height == height then
			if math.abs(target_pps - option.pps) < math.abs(target_pps - best_option.pps) then
				best_option = option
			end
		end
	end

	fps = best_option.fps
	obs.obs_data_set_int(settings, "fps", fps)

	update_bpp(settings)
end

function optimize(settings)
	if optimization_target == "none" then
		update_bpp(settings)
	elseif optimization_target == "bitrate" then
		optimize_bitrate(settings)
	elseif optimization_target == "resolution" then
		optimize_resolution(settings)
	else
		optimize_fps(settings)
	end
end

function bitrate_modified(props, p, settings)
	return false -- text controls refreshing properties reset focus on each character
end

function target_bpp_modified(props, p, settings)
	return false -- text controls refreshing properties reset focus on each character
end

function height_modified(props, p, settings)
	optimize(settings)
	return true
end

function fps_modified(props, p, settings)
	optimize(settings)
	return true
end

function optimization_target_modified(props, p, settings)
	optimize(settings)
	return true
end

function update_bpp(settings)
	if not settings then
		script_log("update_bpp missing settings")
		return
	end
	bpp = bitrate / (width * height * fps)
	obs.obs_data_set_int(settings, "mbpp", math.floor(bpp*1000))
	display_settings()
end

function capture_obs_settings_button(props, p, set)
	capture_obs_settings(my_settings)
	return true
end

function refresh(props, p, set)
	optimize(my_settings)
	return true
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
local description = [[Calculate best resolution or frame rate for a target bitrate.

- Changing Resolution will try to find the best FPS, and vice-versa.
- Bitrate, Resolution, and FPS should be initialized from OBS, you may need to use Capture OBS Settings as they are not necessarily accurate at startup.
- When editing text controls, you must press Refresh to updated calculated fields.
]]
function script_description()
	return description
end

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties(arg)
	script_log("props")

	local props = obs.obs_properties_create()

	obs.obs_properties_add_button(props, "capture_obs_settings", "Capture OBS Settings", capture_obs_settings_button)

	local kbr = obs.obs_properties_add_int(props, "kbitrate", "KiloBitrate", 1, 6000, 50)
	obs.obs_property_set_modified_callback(kbr, bitrate_modified)

	local tmbpp = obs.obs_properties_add_int(props, "target_mbpp", "Target mbpp", 50, 500, 1)

	obs.obs_property_set_modified_callback(tmbpp, target_bmpp_modified)

	local mbpp = obs.obs_properties_add_int(props, "mbpp", "MilliBits Per Pixel", 0, 999999, 1)
	obs.obs_property_set_enabled(mbpp, false)

	local r = obs.obs_properties_add_list(props, "height", "Resolution", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, res in ipairs(resolution_options) do
		obs.obs_property_list_add_int(r, res[1] .. "x" .. res[2], res[2])
	end
	obs.obs_property_set_modified_callback(r, height_modified)

	local f = obs.obs_properties_add_list(props, "fps", "FPS", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, frames in ipairs(fps_options) do
		obs.obs_property_list_add_int(f, tostring(frames), frames)
	end
	obs.obs_property_set_modified_callback(f, fps_modified)

	local o = obs.obs_properties_add_list(props, "optimization_target", "Optimization Target", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	for _, target in ipairs(optimization_options) do
		obs.obs_property_list_add_string(o, target, target)
	end
	obs.obs_property_set_modified_callback(o, optimization_target_modified)

	obs.obs_properties_add_button(props, "refresh", "Refresh", refresh)

	return props
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	script_log("defaults")

	obs.obs_data_set_default_int(settings, "kbitrate", bitrate/1000)
	obs.obs_data_set_default_int(settings, "target_mbpp", math.floor(target_bpp * 1000))
	obs.obs_data_set_default_int(settings, "mbpp", math.floor(bpp * 1000))
	obs.obs_data_set_default_int(settings, "height", height)
	obs.obs_data_set_default_int(settings, "fps", fps)
	obs.obs_data_set_default_string(settings, "optimization_target", optimization_target)
end

--
-- A function named script_update will be called when settings are changed
function script_update(settings)
	script_log("update")
	my_settings = settings

	bitrate = obs.obs_data_get_int(settings, "kbitrate") * 1000

	target_bpp = obs.obs_data_get_int(settings, "target_mbpp") / 1000
	height = obs.obs_data_get_int(settings, "height")
	for _, res in ipairs(resolution_options) do
		if res[2] == height then
			width = res[1]
			break
		end
	end

	fps = obs.obs_data_get_int(settings, "fps")

	optimization_target = obs.obs_data_get_string(settings, "optimization_target")

	update_bpp(settings)
end

-- A function named script_save will be called when OBS settings are changed
-- including start and stop streaming.
--
-- NOTE: This function is usually used for saving extra data
-- Settings set via the properties are saved automatically.
function script_save(settings)
	--script_log("save")
	capture_obs_settings(settings)
end

-- a function named script_load will be called on startup
function script_load(settings)
	script_log("load")
	--dump_obs()
	capture_obs_settings(settings)
	display_settings()
end
