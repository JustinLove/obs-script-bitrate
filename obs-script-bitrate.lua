obs = obslua
ffi = require("ffi")

ffi.cdef[[

struct video_output;
typedef struct video_output video_t;

double video_output_get_frame_rate(const video_t *video);

video_t *obs_get_video(void);
]]

local obsffi = ffi.load("obs")

local width = 100
local height = 100
local bitrate = 1000
local fps = 30

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
end
