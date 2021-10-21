JSON = (loadfile "/usr/local/freeswitch/scripts/src/lua/utils/JSON.lua")();
env = (loadfile "/usr/local/freeswitch/scripts/src/lua/env.lua")();

api = freeswitch.API();

caller_id = session:getVariable("caller_id_number");
callee_id = session:getVariable("destination_number");
uuid = session:getVariable("uuid");

session_call_id = session:getVariable("call_id")
if (session_call_id == nil) then
  session_call_id = "";
end
freeswitch.consoleLog("info", "{session_call_id=" .. session_call_id .. "}");

local redis = require "redis";
client_redis = redis.connect("127.0.0.1", 6379);
local pong = client_redis:ping();
freeswitch.consoleLog("info", "check redis ping-pong: " .. tostring(pong));

-- variables
domain_aicc = env.domain_aicc;
url_callback = "";
call_id = "";
agent_caller_id = "";
agent_callee_id = "";
file_ext = ".wav";
sip_number = env.sip_number_call_out;
server_ip = env.server_ip_call_out;

url_api_vbee_dtmf = env.domain_pbx_zone;
session:setVariable("url_api_vbee_dtmf", url_api_vbee_dtmf);

local time_path = os.date("%Y/%m/%d");
record_path = time_path .. "/" .. string.sub(caller_id, 2) .. "-" .. uuid .. file_ext;
fsname = "AGENT CALL OUT: [" .. caller_id .. "]>>>>>>>>>>>> [" ..callee_id.. "]";

-- constants
AGENT_OFFLINE = 0;
AGENT_DENY = 1;
AGENT_READY = 2;


function getAgentOnline(str, callee_id_number)
  local raws = JSON:decode(str)
  local count = raws.row_count
  if count == 0 then return nil end
  local registrations = raws.rows
  for k, registration in ipairs(registrations) do
    if (callee_id_number == registration.reg_user) then
      return registration.url
    end
  end
  return nil
end

function includes(tables, value)
  for _, v in ipairs(tables) do
      if (v == value) then
          return true;
      end
  end
  return false;
end

function getSipInfo(content, callee_id_number, field)
  local raws = JSON:decode(content);
  local row_count = raws.row_count;
  if (row_count == 0) then
      return nil;
  end

  local registrations = raws.rows;
  for _, registration in ipairs(registrations) do
      if (callee_id_number == registration.reg_user) then
          return registration[field];
      end
  end

  return nil;
end

function getSofiaContact(extension, domain_name, profile)
  local sofia_contact = "";
  freeswitch.consoleLog( "info", "sofia_contact internal: extension=" .. tostring(extension) .. ",domain_name=" .. tostring(domain_name) .. ".\n" );
  if (profile == "auto") then
    profile = "internal";
    session:execute("set", "sofia_contact_" .. tostring(extension) .. "=${sofia_contact(" .. profile .. "/" .. tostring(extension) .. "@" .. tostring(domain_name) .. ")}");
    sofia_contact = session:getVariable("sofia_contact_" .. tostring(extension));
     
    -- define additional profiles here
    if (sofia_contact == "error/user_not_registered") then
      profile = "lan";
      session:execute("set", "sofia_contact_" .. tostring(extension) .. "=${sofia_contact(" .. profile .. "/" .. tostring(extension) .. "@" .. tostring(domain_name) .. ")}");
      sofia_contact = session:getVariable("sofia_contact_" .. tostring(extension));
      freeswitch.consoleLog( "info", "sofia_contact lan: " .. sofia_contact .. ".\n" );
    end
  else
    session:execute("set", "sofia_contact_" .. tostring(extension) .. "=${sofia_contact(" .. profile .. "/" .. tostring(extension) .. "@" .. tostring(domain_name) .. ")}");
    sofia_contact = session:getVariable("sofia_contact_" .. tostring(extension));
    freeswitch.consoleLog( "info", "sofia_contact else: " .. sofia_contact .. ".\n" );
  end
  return sofia_contact;
end

function checkRealReg(token)
  local check_external = string.match(api:executeString("sofia status profile external reg"), token);
  freeswitch.consoleLog("info", "check real reg external: " .. tostring(check_external) .. "\n");
  if (check_external) then
      return true;
  end

  local check_internal = string.match(api:executeString("sofia status profile internal reg"), token);
  freeswitch.consoleLog("info", "check real reg internal: " .. tostring(check_internal) .. "\n");
  if (check_internal) then
      return true;
  end

  return false;
end

function executeBrigdeSoftphone(caller_id_number, callee_id_number)
  freeswitch.consoleLog("info", "Check Register Account " .. callee_id_number .. "\n");
  local check = checkRealReg(callee_id_number);
  if (check == false) then
      return AGENT_OFFLINE;
  end

  local registrations_json = api:executeString("show registrations as json");
  local url_sip = getSipInfo(registrations_json, callee_id_number, "url");
  freeswitch.consoleLog("info", "check show registrations: " .. tostring(url_sip) .. "\n");
  if (url_sip == nil) then
      return AGENT_OFFLINE;
  end

  freeswitch.consoleLog("info", "SIP Account " .. callee_id_number .. " : " .. tostring(url_sip));
  session:execute("set","ignore_early_media=true");
  session:execute("set","instant_ringback=true");
  -- session:execute("set", "transfer_ringback=local_stream://default")
  -- session:execute("set", "transfer_ringback=file_string:///etc/freeswitch/make_audio_template/ponce-preludio-in-e-major.wav");
  session:execute("set", "ringback=file_string:///etc/freeswitch/make_audio_template/ponce-preludio-in-e-major.wav");
  session:execute("set","hangup_after_bridge=true");
  -- session:execute("set","media_bug_answer_req=true");
  session:execute("set","ignore_display_updates=true");
  session:execute("set","call_direction=outbound");
  session:execute("set","continue_on_fail=true");
  session:execute("set", "call_timeout=20");
  session:execute("set","Caller-Caller-ID-Name="..caller_id_number);
  session:execute("set","Caller-Caller-ID-Number="..caller_id_number);
  session:execute("set","origination_caller_id_number="..caller_id_number);
  session:execute("set","effective_caller_id_number="..caller_id_number);
  -- session:execute("set","Caller-Callee-ID-Name="..caller_id_number);
  -- session:execute("set","Caller-Callee-ID-Number="..caller_id_number);
  -- session:execute("set","callee_id_number="..callee_id_number);
  session:execute("set","agent_id="..agent_callee_id);
  session:execute("set","call_id="..call_id);
  session:execute("export", "execute_on_answer=record_session " .. env.record_dir .. record_path);
  
  local string_bridge = "{callee_id_number=" .. callee_id_number .. 
    ",agent_id=" .. agent_callee_id ..
    ",call_id=" .. call_id;
  if (session_call_id ~= nil and session_call_id ~= "") then
      string_bridge = string_bridge .. ",connect_operator=true";

      local params = {};
      params['call_id'] = uuid;
      params['key'] = "ACTION_HANGUP";
      params['event_timestamp'] = api:getTime();
      params['action_before_hangup'] = "CONNECTING_CSR";
      params['agent_id'] = agent_callee_id;
      params['agent_phone'] = callee_id_number;

      requestAPIAsyn(url_callback, params);
  end
  string_bridge = string_bridge .. "}";
  -- test call multil devices
  local domain_name = session:getVariable("domain_name");
  local dialed_extension = session:getVariable("dialed_extension");
  if (not dialed_extension) then
    dialed_extension = callee_id_number;
  end
  -- session:execute( "set", "contact_exists=${user_exists(id " .. tostring(dialed_extension) .. " ${domain})}" )
  --  if( session:getVariable( "contact_exists" ) == "false" ) then
  --      session:execute( "playback", "file_string:///etc/freeswitch/make_audio_template/ponce-preludio-in-e-major.wav" )
  --  else
  --      session:execute( "set", "contact_available=${sofia_contact(external/" .. tostring(dialed_extension) .. "@${domain})}" )
  --      contact_available = session:getVariable( "contact_available" )
  --      freeswitch.consoleLog("info", "contact_available= " .. contact_available);
  --      if( string.find( contact_available, "error" ) ) then
  --      else
  --       freeswitch.consoleLog("info", "bridge= " .. string_bridge .. contact_available);
  --         session:execute("bridge", string_bridge .. contact_available);
  --      end
  --  end
  sofia_contact = getSofiaContact(dialed_extension, domain_name, "external");
  session:execute("bridge", string_bridge .. sofia_contact);

  -- session:execute("bridge", string_bridge .. url_sip);

  local originate_disposition = session:getVariable("originate_disposition");

  freeswitch.consoleLog("++++++++++++++++++++++++++++++++++++++++++= info",fsname.."  Bridged caller_id_number :"..caller_id_number..", callee_id_number"..callee_id_number);

  local STOP_RETRY_CAUSES = {"NORMAL_CLEARING", "ORIGINATOR_CANCEL", "SUCCESS"};
    local originate_disposition = session:getVariable("originate_disposition"); -- get code return hangup cause
    freeswitch.consoleLog("info", fsname .. " Bridged originate_disposition: " .. originate_disposition .. "\n")
    if (includes(STOP_RETRY_CAUSES, originate_disposition)) then
        freeswitch.consoleLog("info", "bridge softphone successfull or legA origin cancel");
        return AGENT_READY
    end
    
    freeswitch.consoleLog("info", "bridge softphone deny");
    -- TODO callback log agent reject call
    return AGENT_DENY;
end

function requestAPI(request_function, request_params, method)
  local request_url = request_function;
  if (not session:ready()) then
      freeswitch.consoleLog("info", "not session request api: " .. request_function);
      return;
  end

  if (request_params ~= nil and type(request_params) == "table") then
      local params_url = ""
      for k, v in pairs(request_params) do
          if (params_url == "") then
              params_url = k .. "=" .. v;
          else
              params_url = params_url .. "&" .. k .. "=" .. v;
          end
      end
      if (params_url ~= "" and method == nil) then
          request_url = request_url .. "?";
      end

      request_url = request_url .. params_url;
      request_url = request_url .. "&event_timestamp=" .. api:getTime();
  end

  freeswitch.consoleLog("info", "Request API URL: " .. request_url);
  local response = api:execute("curl", request_url);
  return response;
end

function requestAPIAsyn(request_function, request_params, has_call_back)
  local request_url = request_function;
  if string.sub(request_url, -4) ~= "post" then
      request_url = request_url .. " post ";
  end

  if (request_params ~= nil and type(request_params) == "table") then
      local params_url = ""
      for k, v in pairs(request_params) do
          if (params_url == "") then
              params_url = k .. "=" .. v;
          else
              params_url = params_url .. "&" .. k .. "=" .. v;
          end
      end
      request_url = request_url .. params_url;
  end

  freeswitch.consoleLog("info", "Request API URL: " .. request_url);
  local response = api:execute("curl", request_url);
  return response;
end

function requestWakeupApp(callee_id)
  local params = {};
  params["domain"] = env.domain_freeswitch;
  params["username"] = callee_id;
  params["displayName"] = caller_id;

  local url_request = env.domain_notification .. "/api/v1/wakeup-app";
  local response = requestAPIAsyn(url_request, params);
  freeswitch.consoleLog("info", fsname .. " >>> Response Request Wakeup: " .. response);

  response = JSON:decode(response)
  if (response["status"] == 1) then
      return true;
  end

  return false;
end

function getAgent(caller_id, callee_id)
  local params = {}
  params["caller_number_id"] = caller_id;
  params["callee_number_id"] = callee_id;
  params["call_id"] = uuid;
  params["event_timestamp"] = api:getTime();

  local url_request = domain_aicc .. "/api/v1/calls/init-call-agents";
  local response = requestAPIAsyn(url_request, params);
  freeswitch.consoleLog("info", "AGENT CALL OUT ==> GET AGENT INFO: " .. response)
  response = JSON:decode(response)
  if (response["status"] == 1) then
    url_callback = response["result"]["callback_logs"];
    call_id = response["result"]["call_id"];
    agent_caller_id = response["result"]["agent_caller_id"];
    agent_callee_id = response["result"]["agent_callee_id"];
    if (response["result"]["hotline"]) then
      sip_number = response["result"]["hotline"]["phone_number"];
      server_ip = response["result"]["hotline"]["sip_ip_port"];
    end
    
    if (session_call_id ~= nil and session_call_id ~= "") then
      session:setVariable("call_id", call_id);
    end

    return true;
  end

  return false;
end

function processSoftphone()
  local is_request_wakeup = false;
  a = 0;
  local result = AGENT_OFFLINE;
  while ( a < 30) do
    if (not session:ready()) then
      freeswitch.consoleLog("info", "wakeup session not ready");
      return;
    end
    freeswitch.consoleLog("info", caller_id .. " =>  " .. callee_id .. ". ping account and execute bridge " .. (a + 1) .. " ... \n")
    result = executeBrigdeSoftphone(caller_id, callee_id);
    freeswitch.consoleLog("info", "result execute bridge softphone: " .. result);
    if (result == AGENT_READY) then
      break
    elseif(result == AGENT_DENY) then
      break;
    elseif result == AGENT_OFFLINE then
      freeswitch.consoleLog("info", caller_id .. " =>  " .. callee_id .. ". sleeping 500ms ... \n")
      if (is_request_wakeup == false) then
         local is_request_wakeup = requestWakeupApp(callee_id);
         if (is_request_success == false) then
            return false;
         end
         is_request_wakeup = true;
      end
      session:execute("sleep", 500)
    end
    a = a + 1
  end
  if (result == AGENT_OFFLINE) then
    local url_request = domain_aicc .. "/api/v1/members/" .. agent_callee_id .. "/call-system-status POST " .. "call_system_status=AVAILABLE";
    api:executeString("luarun src/lua/utils/http_async.lua " .. url_request);
  end
  -- executeTranfer(session:getVariable("caller_id_number"), session:getVariable("destination_number"));
end

function processMobile()
  -- bắn sự kiện kết nối tổng đài viên để bên nhận sự kiện nghe máy biết
  freeswitch.consoleLog("info", "PREPARING OPEN BRIDGE CONNECT TO PHONE NUMBER: " .. callee_id .. "\n")
  session:execute("set", "ignore_early_media=true")
  session:execute("set", "instant_ringback=true")
  --	session:execute("set","transfer_ringback=local_stream://default");
  --	session:execute("set","ringback=local_stream://default");
  -- session:execute("set", "transfer_ringback=" .. session:getVariable("hold_music"))
  session:execute("set", "ringback=file_string:///etc/freeswitch/make_audio_template/ponce-preludio-in-e-major.wav");
  -- session:execute("set", "ringback=" .. session:getVariable("us-ring"))
  session:execute("set", "hangup_after_bridge=true")
  session:execute("set", "inherit_codec=true")
  session:execute("set", "ignore_display_updates=true")
  session:execute("set", "call_direction=outbound")
  session:execute("set", "continue_on_fail=true")
  session:execute("unset", "call_timeout")
  session:execute("set", "Caller-Caller-ID-Name=" .. sip_number)
  session:execute("set", "Caller-Caller-ID-Number=" .. sip_number)
  session:execute("set", "origination_caller_id_number=" .. sip_number)
  session:execute("set", "effective_caller_id_number=" .. sip_number)
  session:execute("set", "Caller-Callee-ID-Name=" .. sip_number)
  session:execute("set", "Caller-Callee-ID-Number=" .. sip_number)
  session:execute("set", "callee_id_number=" .. callee_id)
  session:execute("export", "execute_on_answer=record_session " .. env.record_dir .. record_path);
  -- session:execute("bridge","sofia/internal/"..callee_id.."@"..server_ip);

  local string_bridge = "{callee_id_number=" .. callee_id .. 
    ",call_id=" .. call_id;

  if (session_call_id ~= nil and session_call_id ~= "") then
    string_bridge = string_bridge .. ",connect_operator=true";

    local params = {};
    params['call_id'] = uuid;
    params['key'] = "ACTION_HANGUP";
    params['event_timestamp'] = api:getTime();
    params['action_before_hangup'] = "CONNECTING_CSR";
    params['agent_phone'] = callee_id;

    requestAPIAsyn(url_callback, params);
  end
  string_bridge = string_bridge .. "}";

  session:execute("bridge", string_bridge .. "sofia/external/" .. callee_id .. "@" .. server_ip)
end

-- process script
local is_success = getAgent(caller_id, callee_id);
if (is_success) then
  -- redis
  local url_callback_redis = "url_callback_" .. uuid;
  local record_path_redis = "record_path_" .. uuid;
  
  freeswitch.consoleLog("info", "redis {url_callback_redis=" .. url_callback_redis .. 
    ", uuid=" .. uuid .. 
    ", call_id=" .. call_id .. 
    ", session_call_id=" .. session_call_id .."}");
  client_redis:set(record_path_redis, record_path);
  client_redis:set(url_callback_redis, url_callback);
  client_redis:set("pbx_callback_redis", url_api_vbee_dtmf);
  
  if (string.match(callee_id, "_") ~= nil) then
    processSoftphone();
  else 
    processMobile();
  end
else
  session:execute("hangup", 484);
  freeswitch.consoleLog("info", "get agent is failure!");
end


