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

sip_term_cause = event:getHeader("variable_sip_term_cause");
if (sip_term_cause == nil) then
  sip_term_cause = "";
end

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

event_timestamp = math.floor(event:getHeader("Event-Date-Timestamp") / 1000)
if dial_number == nil then
  dial_number = ""
end

if answer_state == "hangup" then
  desc = event:getHeader("Hangup-Cause")
else
  desc = event:getHeader("Call-Direction")
end

freeswitch.consoleLog(
  "info",
  "Hook Hangup Event At : [event_timestamp] = " ..
    event_timestamp .. " => [Event-Date-Local] = " .. event:getHeader("Event-Date-Local") .. "\n"
)

local url_callback_redis = client_redis:get("url_callback_" .. uuid)
local record_path_redis = client_redis:get("record_path_" .. uuid)
local pbx_callback_redis = client_redis:get("pbx_callback_redis")

-- callback khi customer hangup
agent_id = event:getHeader("variable_agent_id")
freeswitch.consoleLog("info", "Hangup call: {connect_operator=" .. tostring(connect_operator) .. ", agent_id=" ..tostring(agent_id) .. "}\n");
-- update status agent
if (agent_id ~= "" and agent_id ~= nil) then
    local url_request = env.domain_aicc .. "/api/v1/members/" .. agent_id .. "/call-system-status POST " .. "call_system_status=AVAILABLE";
    freeswitch.consoleLog("info", "===========> Request Update Status Agent Available: " .. url_request .."===========> \n");
    api:executeString("luarun src/lua/utils/http_async.lua " .. url_request);
end

if (agent_caller_id ~= nil and agent_caller_id ~= "") then
  local url_request = env.domain_aicc .. "/api/v1/members/" .. agent_caller_id .. "/call-system-status POST " .. "call_system_status=AVAILABLE";
    freeswitch.consoleLog("info", "===========> Request Update Status agent_caller_id Available: " .. url_request .."===========> \n");
    api:executeString("luarun src/lua/utils/http_async.lua " .. url_request);
end

if (agent_callee_id ~= nil and agent_callee_id ~= "") then
  local url_request = env.domain_aicc .. "/api/v1/members/" .. agent_callee_id .. "/call-system-status POST " .. "call_system_status=AVAILABLE";
  freeswitch.consoleLog("info", "===========> Request Update Status agent_callee_id Available: " .. url_request .."===========> \n");
  api:executeString("luarun src/lua/utils/http_async.lua " .. url_request);
end

if (connect_operator) then
  local request_url = url_callback_redis .. " post " ..
    "call_id=" .. uuid .. 
    "&key=ACTION_HANGUP" .. 
    "&event_timestamp=" .. event_timestamp .. 
    "&action_before_hangup=END_CONNECT_CSR" ..
    "&cause=" .. desc;
    
  if (agent_id ~= "" and agent_id ~= nil) then
    request_url = request_url .. "&agent_id=" .. agent_id;
  end
  if (callee_id_number ~= nil and callee_id_number ~= "") then
    request_url = request_url .. "&agent_phone=" .. callee_id_number;
  end
  if (sip_term_cause ~= "" and sip_term_cause ~= nil) then
    request_url = request_url .. "&sip_cause=" .. sip_term_cause;
  end
  freeswitch.consoleLog("info", "REQUEST API: " .. request_url);
  api:execute("curl", request_url);
end

if (connect_operator == nil) then
  if (record_path == "" and record_path_redis ~= nil) then
    record_path = record_path_redis
  end
  if (record_path ~= "" and record_path ~= nil) then
    record_path = env.domain_pbx_zone .. "/" .. env.pbx_prefix_audio .. "/" .. record_path;
  end

  if (url_callback_redis ~= nil) then
    local request_url = url_callback_redis .. " post " ..
      "call_id=" .. uuid .. 
      "&key=end" .. 
      "&event_timestamp=" .. event_timestamp.. 
      "&recording_path=" .. record_path ..
      "&cause=" .. desc;
    
    if (sip_term_cause ~= "") then
      request_url = request_url .. "&sip_cause=" .. sip_term_cause;
    end
    freeswitch.consoleLog("info", "REQUEST API: " .. request_url);
    api:execute("curl", request_url);
  end
end
