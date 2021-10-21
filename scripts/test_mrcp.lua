package.path = "/usr/share/lua/5.2/?.lua;./utils/?.lua;/usr/local/freeswitch/scripts/src/lua/utils/?.lua;" .. package.path
pcall(require, "luarocks.require")
env = (loadfile "/usr/local/freeswitch/scripts/src/lua/env.lua")();

local utils = require 'utils'
local redis = require 'redis'

JSON = (loadfile "/usr/local/freeswitch/scripts/JSON.lua")()

local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local urldecode = function(url)
  if url == nil then
    return
  end
  url = url:gsub("+", " ")
  url = url:gsub("%%(%x%x)", hex_to_char)
  return url
end



-- This is the input callback used by dtmf or any other events on this session such as ASR.
function onInput(s, type, obj)
   freeswitch.consoleLog("info", "Callback with type " .. type .. "\n");
end

api = freeswitch.API();
local private_key='ba64cb48-00dc-4d34-a100-e8f19100fe65';
local app_id="5b7a441c164671424f63d624";
local time=api:getTime();
local md5 = require 'md5'
local keytts=md5.sumhexa(private_key..":"..app_id..":"..time);
local user_id=46174
local rate=1
local voice="hn_male_xuantin_vdts_48k-hsmm"
local encodedText="Cảm ơn bạn đã nhấn phím "
local dung_khong = " đúng không. "
local url = "http://gate.vbeecore.com/api/v1/tts?app_id="..app_id.."&key="..keytts.."&time="..time.."&user_id="..user_id.."&rate="..rate.."&bit_rate=16000&priority=10&sample_rate=8000&voice="..voice.."&input_text="
uuid =  session:get_uuid();

function get_id_cmnd()
	local i = 0;
	local max_retry = 2;
	while i < max_retry do
		i  = i + 1;
		session:execute("playback", "/usr/local/freeswitch/make_audio_template/vais_cmt.wav");      
		session:setVariable("playback_terminators","any");
	    session:setVariable("play_and_detect_speech_close_asr","true");
	    session:execute("play_and_detect_speech","/mnt/nfsdir63/ivr/beep.wav detect:unimrcp:vvmrcp-37-record {start-input-timers=false,no-input-timeout="..noinputtimeout..",speech_complete_timeout=1,recognition-timeout="..recogtimeout.."}builtin:grammar/text"..get_params_request("number"))
	    local cmnd = session:getVariable('detect_speech_result');
	    freeswitch.consoleLog("info","cmnd"..cmnd);
	    -- 184158755
	    if cmnd ~= nil then
	  	 	if cmnd == "6800" then
	  	 		session:execute("playback","/usr/local/freeswitch/make_audio_template/vais_thong_bao_tien.wav");
	  	 		return 1;
	  	 	else
	  			if i < max_retry then
		  	 		session:execute("playback","/usr/local/freeswitch/make_audio_template/vais_sai_thong_tin.wav");
		  	 	else
		  	 		session:execute("playback","/usr/local/freeswitch/make_audio_template/thong_tin_khong_dung_xin_cam_on.wav");
		  	 	end;
	  	 	end
	  	else
	  		if i < max_retry then
		  	 		session:execute("playback","/usr/local/freeswitch/make_audio_template/vais_sai_thong_tin.wav");
		  	 	else
		  	 		session:execute("playback","/usr/local/freeswitch/make_audio_template/thong_tin_khong_dung_xin_cam_on.wav");
		  	 	end;
	  		return 0;
	  	end;

	end;
end

local is_int = function(n)
  local  d = tonumber(n);
  if d ~= nil then 
  	return (type(d) == "number") and (math.floor(d) == d)
  else
  	return false;
  end 
end
function get_params_request(type_speech)
	local msisdn_phone = session:getVariable("caller_id_number");
	local uuid =  session:get_uuid();
	local params_request = "_"..type_speech.."_"..msisdn_phone.."_"..uuid;
	return params_request;
end

function process (i)
	if(not session:ready()) then
		return 1;
	end
	recogtimeout = 10000
	noinputtimeout = 2000
	local params = {};
	params["msisdn"] = "0"..msisdn;
	
	local fullname = "Quý khách";
	
	session:execute("playback","/usr/local/freeswitch/make_audio_template/moi_ban_nhap_lan_thu_x.wav");
	session:execute("playback","/usr/local/freeswitch/make_audio_template/"..tostring(i)..".wav");
	session:execute("play_and_detect_speech","/mnt/nfsdir63/ivr/beep.wav detect:unimrcp:vvmrcp-37-record {start-input-timers=false,no-input-timeout="..noinputtimeout..",speech_complete_timeout=1,recognition-timeout="..recogtimeout.."}builtin:grammar/text"..get_params_request("general"))
	local answer_yes_no = session:getVariable('detect_speech_result');
	freeswitch.consoleLog("info",answer_yes_no);
	session:execute("playback","/usr/local/freeswitch/make_audio_template/ban_vua_noi.wav");
	local url = "http://gate.vbeecore.com/api/tts?rate=1&time="..os.time().."&service_type=1&priority=10&sample_rate=8000&bit_rate=16000&input_text="
	session:execute("playback",url..urlencode(answer_yes_no));
	freeswitch.consoleLog("info",url..urlencode(answer_yes_no));
	process(i+1)
end

--Used to map returned names to extension numbers
extensions = {
   ["anthony"] = 3000,
   ["michael"] = 3001,
   ["brian"] = 3002
}

local client = redis.connect('127.0.0.1', 6379)
client:set('usr:nrk', 10)
local value_redis = client:get('usr:nrk')

utils.writelog("DEBUG", value_redis);
-- Create the empty results table.
results = {};
-- Answer the call.
session:answer();
-- Define TTS Engine
session:set_tts_params("unimrcp:vvmrcp", "");
-- session:set_tts_params("unimrcp:cpqd­mrcp­v1", "rosana­highquality.voice")
-- Register the input callback 
session:setInputCallback("onInput");
-- Sleep a little bit to give media time to be fully up.
session:sleep(200);
-- session:speak("Welcome to the directory.");
local durationNum = 10000
-- Start the detect_speech app.  This attaches the bug to fire events
-- session:execute("detect_speech", "unimrcp:vvmrcp builtin:speech/transcribe");

-- Magic happens here.
-- It would be ok to loop like 3 times and error to the operator if this doesn't work or revert to reading names off with TTS.
i = 1;


durationNum = 1000
-- session:sleep(1000);
session:setVariable("play_and_detect_speech_close_asr","true");
-- session:sleep(0,1);
--session:execute("play_and_detect_speech","/mnt/nfsdir63/ivr/beep.wav detect:unimrcp:vvmrcp-37 {start-input-timers=true,no-input-timeout="..durationNum..",recognition-complete-timeout="..durationNum..",recognition-timeout="..durationNum.."}builtin:speech/transcribe "..uuid)

g_RecordDir = "/mnt/nfsdir63/recording/";
recordPath= "";
fileExt = ".wav";

local timeRecord = os.date("%H%M%S");
local dateRecord = os.date("%Y%m%d");
local timePath = os.date("%Y/%m");
os.execute("mkdir -p --mode=755 "..g_RecordDir..timePath);
--local recordPath = g_RecordDir..timePath.."/"..msisdn.."_"..dateRecord.."_"..timeRecord..fileExt;
msisdn = session:getVariable("caller_id_number");
recordPath = g_RecordDir..timePath.."/"..msisdn.."_"..timeRecord.."_"..dateRecord..fileExt; 
session:execute("record_session", recordPath);

process()
