package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/src/lua/utils/?.lua;" .. package.path
JSON = (loadfile "/usr/local/freeswitch/scripts/src/lua/utils/JSON.lua")();

pcall(require, "luarocks.require");
env = (loadfile "/usr/local/freeswitch/scripts/src/lua/env.lua")();
api = freeswitch.API();

local redis = require "redis";
client_redis = redis.connect("127.0.0.1", 6379);

client_redis:set('usr:nrk', 'cuongnv')
local value_redis = client_redis:get('usr:nrk')
freeswitch.consoleLog("info", value_redis)

callee_id = "/1{4,5}/";
-- local command = string.match(callee_id, "(^[a-zA-Z0-9]{1,6}_[0-9]{4,6}$)|(^[0-9]{4,6}$)")

local char_to_hex = function(c) 
    return string.format("%%%02X", string.byte(c)) 
end

local function urlencode(url)
    if url == nil then return end
    url = url:gsub("\n", "BREAKSYMBOL")
    url = url:gsub("([^%w ])", char_to_hex)
    url = url:gsub("BREAKSYMBOL", "%%5Cn")
    url = url:gsub(" ", "+")
    return url
end

function uriencode(vals)
    function escape(s)
        s = string.gsub(s, '([\r\n"#%%&+:;<=>?@^`{|}%\\%[%]%(%)$!~,/\'])',
                        function(c)
            return '%' .. string.format("%02X", string.byte(c));
        end);
        s = string.gsub(s, "%s", "+");
        return s;
    end

    function encode(t)
        local s = "";
        for k, v in pairs(t) do
            s = s .. "&" .. escape(k) .. "=" .. escape(v);
        end
        return string.sub(s, 2);
    end

    if type(vals) == 'table' then
        return encode(vals);
    else
        local t = {};
        for k, v in  string.gmatch(vals, ",?([^=]+)=([^,]+)") do
            t[k]=v;
        end
        return encode(t);
    end
end

actions = {
    {
        ["action"] = "TYPE_TEXT",
        ["audio_path"] = "https://dev-upload-api.aicallcenter.vn/audios/2021/05/19/4GNIpcHrdq47BKOO.wav",
        ["repeat"] = 1,
        ["timeout"] = 5000
    },
    {
        ["action"] = "UPLOAD",
        ["audio_path"] = "https://dev-upload-api.aicallcenter.vn/audios/2021/05/19/4GNIpcHrdq47BKOO.wav",
    }
};
params = {};
params["event_timestamp"] = api:getTime();
params["key"] = "ACTION_HANGUP";
params["action_before_hangup"] = "IVR";
params["node_id"] = "12314121WWWW";
params["actions"] = '[{"action":"CONNECT_AGENT","connect_queue_id":"6063db14cbb8691ca2c1fa98","connection_type":"QUEUE","content_init_bot":"Bắt đầu","content_not_connected":"Đây là lời thoại khi kết nối bot không thành công","mobiles":["0968078124"]}]';
params = uriencode(params);

-- for idx, action in ipairs(actions) do
--     freeswitch.consoleLog("info", "start action: " .. JSON:encode(action) .. "idx=".. idx);
--     local value = JSON:encode(action) .. "";
--     freeswitch.consoleLog("info", "uriencode value: type(vals)=" .. type(value));
--     params = params .. "&actions[]=" .. value;
-- end

local request_url = "https://dc7e0612ed27.ngrok.io/api/v1/calls/60ab6cea69862a604f20a794/logs post ";

request_url = request_url .. params;
freeswitch.consoleLog("info", "request_url=" .. request_url);

-- local url_request = "https://b8eabeca22b0.ngrok.io/api/v1/calls/609df8c73b116b1dd312762c/logs post eventTimestamp=" .. tonumber(api:getTime()) .. "&key=start";
api:executeString("luarun src/lua/utils/http_async.lua " .. request_url);
