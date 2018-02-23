obs = obslua

my_script_properties = nil
my_script_settings = nil

function script_log(message)
	obs.script_log(obs.LOG_INFO, message)
end

ffi = require("ffi")

ffi.cdef[[

struct video_output;
typedef struct video_output video_t;

double video_output_get_frame_rate(const video_t *video);

video_t *obs_get_video(void);



enum video_format {
	VIDEO_FORMAT_NONE,

	/* planar 420 format */
	VIDEO_FORMAT_I420, /* three-plane */
	VIDEO_FORMAT_NV12, /* two-plane, luma and packed chroma */

	/* packed 422 formats */
	VIDEO_FORMAT_YVYU,
	VIDEO_FORMAT_YUY2, /* YUYV */
	VIDEO_FORMAT_UYVY,

	/* packed uncompressed formats */
	VIDEO_FORMAT_RGBA,
	VIDEO_FORMAT_BGRA,
	VIDEO_FORMAT_BGRX,
	VIDEO_FORMAT_Y800, /* grayscale */

	/* planar 4:4:4 */
	VIDEO_FORMAT_I444,
};

enum video_colorspace {
	VIDEO_CS_DEFAULT,
	VIDEO_CS_601,
	VIDEO_CS_709,
};

enum video_range_type {
	VIDEO_RANGE_DEFAULT,
	VIDEO_RANGE_PARTIAL,
	VIDEO_RANGE_FULL
};

enum obs_scale_type {
	OBS_SCALE_DISABLE,
	OBS_SCALE_POINT,
	OBS_SCALE_BICUBIC,
	OBS_SCALE_BILINEAR,
	OBS_SCALE_LANCZOS
};

struct obs_video_info {
	/**
	 * Graphics module to use (usually "libobs-opengl" or "libobs-d3d11")
	 */
	const char          *graphics_module;

	uint32_t            fps_num;       /**< Output FPS numerator */
	uint32_t            fps_den;       /**< Output FPS denominator */

	uint32_t            base_width;    /**< Base compositing width */
	uint32_t            base_height;   /**< Base compositing height */

	uint32_t            output_width;  /**< Output width */
	uint32_t            output_height; /**< Output height */
	enum video_format   output_format; /**< Output format */

	/** Video adapter index to use (NOTE: avoid for optimus laptops) */
	uint32_t            adapter;

	/** Use shaders to convert to different color formats */
	bool                gpu_conversion;

	enum video_colorspace colorspace;  /**< YUV type (if YUV) */
	enum video_range_type range;       /**< YUV range (if YUV) */

	enum obs_scale_type scale_type;    /**< How to scale if scaling */
};

bool obs_get_video_info(struct obs_video_info *ovi);
int obs_reset_video(struct obs_video_info *ovi);
]]

local obsffi = ffi.load("obs")

local width = 640
local height = 360
local fps = 30
local bitrate = 1000000
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

function capture_obs_settings(settings)
	local encoder = obs.obs_get_encoder_by_name("simple_h264_stream")
	if encoder then
		width = obs.obs_encoder_get_width(encoder)
		height = obs.obs_encoder_get_height(encoder)
		local settings = obs.obs_encoder_get_settings(encoder)
		--script_log(obs.obs_data_get_json(settings))
		bitrate = obs.obs_data_get_int(settings, "bitrate") * 1000
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

function apply_settings(props, p)
	my_script_properties = props

	local info = ffi.new("struct obs_video_info")
	obsffi.obs_get_video_info(info)
	info.output_width = width
	info.output_height = height
	info.fps_num = fps
	info.fps_den = 1
	local result = obsffi.obs_reset_video(info)
	if result == -4 then
		script_log("Cannot update while video active")
	elseif result < 0 then
		script_log("Error: " .. result)
	else
		script_log("Succesfully appllied?")
	end

	return true -- true calls QT RefreshProperties ?
end

function optimize_resolution(props, p)
	my_script_properties = props

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
	bpp = bitrate / (width * height * fps)

	obs.obs_data_set_int(my_script_settings, "mbpp", math.floor(bpp * 1000))
	obs.obs_data_set_int(my_script_settings, "height", height)

	return true
end

function optimize_fps(props, p)
	my_script_properties = props

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
	bpp = bitrate / (width * height * fps)

	obs.obs_data_set_int(my_script_settings, "mbpp", math.floor(bpp * 1000))
	obs.obs_data_set_int(my_script_settings, "fps", fps)

	return true
end

function refresh(props, p, set)
	my_script_properties = props
	script_log("refresh")
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
function script_description()
	return "Calculate bitrate tradeoffs, and maybe someday update settings in once place"
end

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	script_log("props")

	local props = obs.obs_properties_create()

	obs.obs_properties_add_int(props, "kbitrate", "KiloBitrate", 1, 6000, 50)
	obs.obs_properties_add_int(props, "target_mbpp", "Target mbpp", 50, 500, 1)
	local b = obs.obs_properties_add_int(props, "mbpp", "MilliBits Per Pixel", 50, 500, 1)
	obs.obs_property_set_enabled(b, false)

	local r = obs.obs_properties_add_list(props, "height", "Resolution", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, res in ipairs(resolution_options) do
		obs.obs_property_list_add_int(r, res[1] .. "x" .. res[2], res[2])
	end
	obs.obs_property_set_modified_callback(r, refresh)

	local f = obs.obs_properties_add_list(props, "fps", "FPS", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
	for _, frames in ipairs(fps_options) do
		obs.obs_property_list_add_int(f, tostring(frames), frames)
	end
	obs.obs_property_set_modified_callback(f, refresh)

	obs.obs_properties_add_button(props, "apply_settings", "Apply Settings", apply_settings)
	obs.obs_properties_add_button(props, "refresh", "Refresh", refresh)
	obs.obs_properties_add_button(props, "optimize_resolution", "Optimize Resolution", optimize_resolution)
	obs.obs_properties_add_button(props, "optimize_fps", "Optimize FPS", optimize_fps)

	my_script_properties = props

	return props
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	script_log("defaults")
	my_script_settings = settings

	obs.obs_data_set_default_int(settings, "kbitrate", bitrate/1000)
	obs.obs_data_set_default_int(settings, "target_mbpp", math.floor(target_bpp * 1000))
	obs.obs_data_set_default_int(settings, "mbpp", math.floor(bpp * 1000))
	obs.obs_data_set_default_int(settings, "height", height)
	obs.obs_data_set_default_int(settings, "fps", fps)
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	script_log("update")
	my_script_settings = settings

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
	obs.obs_data_set_int(settings, "mbpp", math.floor(bpp*1000))

	--obs.obs_properties_apply_settings(my_script_properties, setting)

	display_settings()
end

-- A function named script_save will be called when OBS settings are changed
-- including start and stop streaming.
--
-- NOTE: This function is usually used for saving extra data
-- Settings set via the properties are saved automatically.
function script_save(settings)
	--script_log("save")
	my_script_settings = settings
	capture_obs_settings(settings)
end

-- a function named script_load will be called on startup
function script_load(settings)
	script_log("load")
	my_script_settings = settings
	--dump_obs()
	capture_obs_settings(settings)
	display_settings()
end
