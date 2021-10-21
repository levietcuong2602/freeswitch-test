base_dir = "/usr/local/freeswitch";

JSON = (loadfile "/usr/local/freeswitch/scripts/src/lua/utils/JSON.lua")();
env = (loadfile "/usr/local/freeswitch/scripts/src/lua/env.lua")();
package.path = "/usr/share/lua/5.2/?.lua;/usr/local/freeswitch/scripts/src/lua/utils/?.lua;" .. package.path

api = freeswitch.API();
uuid = session:getVariable("uuid");

local redis = require "redis";
client_redis = redis.connect("127.0.0.1", 6379);
local pong = client_redis:ping();
freeswitch.consoleLog("info", "check redis ping-pong: " .. tostring(pong));

caller_number = session:getVariable("caller_id_number");
sip_number = session:getVariable("destination_number");

