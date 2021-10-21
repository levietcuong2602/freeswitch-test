-- catch event onther
-- freeswitch.consoleLog("info", "Hook ACTIVE: [CHANNEL_CALLSTATE] = " .. event:serialize());
JSON = (loadfile "/usr/local/freeswitch/scripts/src/lua/utils/JSON.lua")();
env = (loadfile "/usr/local/freeswitch/scripts/src/lua/env.lua")();

package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/src/lua/utils/?.lua;" .. package.path

local redis = require "redis"
client_redis = redis.connect("127.0.0.1", 6379)

api = freeswitch.API()

dial_number = event:getHeader("Caller-Destination-Number")
desc = event:getHeader("Call-Direction")
uuid = event:getHeader("Channel-Call-UUID")
answer_state = event:getHeader("Answer-State")
caller_callee_id_number = event:getHeader("Caller-Callee-ID-Number")

call_id = event:getHeader("variable_call_id")
if call_id == nil then
  call_id = ""
end
record_path = event:getHeader("variable_record_path")
if record_path == nil then
  record_path = ""
end

local connect_operator = event:getHeader("variable_connect_operator")
if customer_record_path == nil then
  customer_record_path = ""
end
local callee_id_number = event:getHeader("variable_callee_id_number")
if callee_id_number == nil then
  callee_id_number = ""
end

local agent_caller_id = event:getHeader("variable_agent_caller_id");
if agent_caller_id == nil then
  agent_caller_id = ""
end

local agent_callee_id = event:getHeader("variable_agent_callee_id");
if agent_callee_id == nil then
  agent_callee_id = ""
end

if dial_number == nil then
  dial_number = ""
end

if answer_state == "hangup" then
  desc = event:getHeader("Hangup-Cause")
else
  desc = event:getHeader("Call-Direction")
end

event_timestamp = math.floor(event:getHeader("Event-Date-Timestamp") / 1000)
freeswitch.consoleLog(
  "info",
  "Hook Answer Event At : [event_timestamp] = " ..
    event_timestamp .. " => [Event-Date-Local] = " .. event:getHeader("Event-Date-Local") .. "\n"
)

local url_callback_redis = client_redis:get("url_callback_" .. uuid)
local record_path_redis = client_redis:get("record_path_" .. uuid)
local pbx_callback_redis = client_redis:get("pbx_callback_redis")

if (desc ~= "WRONG_CALL_STATE") then
  if (record_path == "" and record_path_redis ~= nil) then
    record_path = record_path_redis
  end

  local key = "start"
  agent_id = event:getHeader("variable_agent_id")
  freeswitch.consoleLog("info", "Pickup call: {connect_operator=" .. tostring(connect_operator) .. ", agent_id=" ..tostring(agent_id) .. "}\n");
  if (connect_operator ~= nil) then
    key = "connected_operator:" .. callee_id_number
    state = "answered"

    -- call update status operator
    if (agent_id ~= "" and agent_id ~= nil) then
      local url_request = env.domain_aicc .. "/api/v1/members/" .. agent_id .. "/call-system-status POST " .. "call_system_status=ANSWERED";
      freeswitch.consoleLog("info", "===========> Request Update Status Agent Answered: " .. url_request .." ===========>\n");
      api:executeString("luarun src/lua/utils/http_async.lua " .. url_request);
    end

    if (url_callback_redis ~= nil) then
      local url_request = url_callback_redis .. " post " ..
        "call_id=" .. uuid ..
        "&key=ACTION_HANGUP" ..
        "&event_timestamp=" .. event_timestamp .. 
        "&action_before_hangup=CONNECTED_CSR";
      
      if (agent_id ~= "" and agent_id ~= nil) then
        url_request = url_request .. "&agent_id=" .. agent_id;
      end
      if (callee_id_number ~= nil) then
        url_request = url_request .. "&agent_phone=" .. callee_id_number;
      end

      freeswitch.consoleLog("info", "===========> CURL Request Update ActionBeforeHangup: " .. url_request .." ===========>\n");
      local result = api:execute("curl", url_request);
      freeswitch.consoleLog("info", "Result Request Update ActionBeforeHangup: " .. result .." ===========>\n");
    end
  end

  if (agent_caller_id ~= nil and agent_caller_id ~= "") then
    local url_request = env.domain_aicc .. "/api/v1/members/" .. agent_caller_id .. "/call-system-status POST " .. "call_system_status=ANSWERED";
      freeswitch.consoleLog("info", "===========> Request Update Status agent_caller_id Answered: " .. url_request .." ===========>\n");
      api:executeString("luarun src/lua/utils/http_async.lua " .. url_request);
  end
  
  if (agent_callee_id ~= nil and agent_callee_id ~= "") then
    local url_request = env.domain_aicc .. "/api/v1/members/" .. agent_callee_id .. "/call-system-status POST " .. "call_system_status=ANSWERED";
      freeswitch.consoleLog("info", "===========> Request Update Status agent_callee_id Answered: " .. url_request .." ===========>\n");
      api:executeString("luarun src/lua/utils/http_async.lua " .. url_request);
  end

  
  if (url_callback_redis ~= nil) then
    local request_url = url_callback_redis .." post " .. 
      "call_id=" .. uuid .. 
      "&key=" .. key .. 
      "&event_timestamp=" .. event_timestamp .. 
      "&recording_path=" .. record_path;
    freeswitch.consoleLog("info", "REQUEST API: " .. request_url);
    api:execute("curl", request_url);
  end
end
