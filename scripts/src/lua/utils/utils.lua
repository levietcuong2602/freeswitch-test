local utils = {
    _VERSION     = 'redis-lua 2.0.5-dev',
    _DESCRIPTION = 'A Lua client library for the redis key value storage system.',
    _COPYRIGHT   = 'Copyright (C) 2009-2012 Daniele Alessandri',
}
function utils.writelog(level, content)
	freeswitch.consoleLog(level, "CC_VAIS =========>>>> "..content.."\n");
end

-- goi api 
function utils.requestAPI(session, requestFunction, requestParams)
	local jsonData = nil;
--	if(not session:ready()) then
--		return jsonData;
--	end
	
	local requestUrl = requestFunction;
	if(requestParams ~= nil and type(requestParams) == "table") then
		local paramsUrl = "";
		for k,v in pairs(requestParams) do 
			if(paramsUrl == "") then
				paramsUrl = k.."="..v;
			else
				paramsUrl = paramsUrl.."&"..k.."="..v;
			end
		end
		if(paramsUrl ~= "") then
			requestUrl = requestUrl.."?";
		end
		requestUrl = requestUrl..paramsUrl;
	end
	
	writelog("info","Requesting API: "..requestUrl);
	
	--Call API by Curl
	session:setVariable("curl_timeout", "30")
	session:execute("curl", requestUrl);
	local curl_response = session:getVariable("curl_response_data");	

	if(curl_response ~= nil and curl_response ~= "") then
		writelog("debug", "requestAPI >>>>>>>>>>>>>> :"..curl_response);
		jsonData = JSON:decode(curl_response);
		if(jsonData == nil) then
			--Du lieu gap loi, hangup cuoc goi
			playFileWithOutGetDigits("/home/recordings/1080/1080_loi_he_thong.wav");
			processHangUp("Du lieu API tra ve bi loi:"..requestUrl);
		end
	else
		writelog("debug", "requestAPI>>>>>>>>>>>>>>>>>>>>> : No Response");
		--He thong gap loi, hangup cuoc goi
		playFileWithOutGetDigits("/home/recordings/1080/1080_loi_he_thong.wav");
		processHangUp("loi khi goi API:"..requestUrl);
	end
	
	return jsonData;
end


function utils.char_to_hex(c)
  return string.format("%%%02X", string.byte(c))
end

function utils.urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

function utils.hex_to_char (x)
  return string.char(tonumber(x, 16))
end

function utils.urldecode (url)
  if url == nil then
    return
  end
  url = url:gsub("+", " ")
  url = url:gsub("%%(%x%x)", hex_to_char)
  return url
end

-- Used in parse_xml
function utils.parseargs_xml(s)
   local arg = {}
   string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
					    arg[w] = a
					 end)
   return arg
end

-- Turns XML into a lua table.
function utils.parse_xml(s)
   local stack = {};
   local top = {};
   table.insert(stack, top);
   local ni,c,label,xarg, empty;
   local i, j = 1, 1;
   while true do
      ni,j,c,label,xarg, empty = string.find(s, "<(%/?)(%w+)(.-)(%/?)>", i);
      if not ni then
	 break
      end
      local text = string.sub(s, i, ni-1);
      if not string.find(text, "^%s*$") then
	 table.insert(top, text);
      end
      if empty == "/" then
	 table.insert(top, {label=label, xarg=parseargs_xml(xarg), empty=1});
      elseif c == "" then
	 top = {label=label, xarg=parseargs_xml(xarg)};
	 table.insert(stack, top);
      else
	 local toclose = table.remove(stack);
	 top = stack[#stack];
	 if #stack < 1 then
	    error("nothing to close with "..label);
	 end
	 if toclose.label ~= label then
	    error("trying to close "..toclose.label.." with "..label);
	 end
	 table.insert(top, toclose);
      end
      i = j+1;
   end
   local text = string.sub(s, i);
   if not string.find(text, "^%s*$") then
      table.insert(stack[stack.n], text);
   end
   if #stack > 1 then
      error("unclosed "..stack[stack.n].label);
   end
   return stack[1];
end

function utils.dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
	 if type(k) ~= 'number' then k = '"'..k..'"' end
	 s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Used to parse the XML results.
function utils.getResults(s) 
   local xml = parse_xml(s);
   local stack = {}
   local top = {}

   -- freeswitch.consoleLog("crit", "\n" .. dump(xml) .. "\n");
   table.insert(stack, top)
   top = {grammar=xml[2].xarg.grammar, score=xml[2].xarg.confidence, text=xml[2][1][1][1]}
   table.insert(stack, top)
   return top;
end

-- This is the input callback used by dtmf or any other events on this session such as ASR.
function utils.onInput(s, type, obj)
   freeswitch.consoleLog("info", "Callback with type " .. type .. "\n");
end
--Ham xu ly play file khong can nhan phim nhung co the break file
function utils.playFileWithOutGetDigits(file_path, session, time_out)
  if(not session:ready() or file_path == nil) then
    return;
  end 
  local digit = "";
  --session:playAndGetDigits(1, 1, 1, 1, "",soundDir..fileName..fileExt,"","");
  session:sleep(0,1);
  digit = session:playAndGetDigits(1, 1, 1, time_out, "",file_path,"","");
  return digit;
end

function utils.utf8toansi(text)
  text=text:gsub("??","u")
  text=text:gsub("??","u")
  text=text:gsub("???","u")
  text=text:gsub("??","u")
  text=text:gsub("???","u")
  text=text:gsub("??","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("??","u")
  text=text:gsub("??","u")
  text=text:gsub("???","u")
  text=text:gsub("??","u")
  text=text:gsub("???","u")
  text=text:gsub("??","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("???","u")
  text=text:gsub("??","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("??","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("??","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("???","a")
  text=text:gsub("??","d")
  text=text:gsub("??","d")
  text=text:gsub("??","e")
  text=text:gsub("??","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("??","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("??","e")
  text=text:gsub("??","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("??","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("???","e")
  text=text:gsub("??","i")
  text=text:gsub("??","i")
  text=text:gsub("???","i")
  text=text:gsub("??","i")
  text=text:gsub("???","i")
  text=text:gsub("??","i")
  text=text:gsub("??","i")
  text=text:gsub("???","i")
  text=text:gsub("??","i")
  text=text:gsub("???","i")
  text=text:gsub("??","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("??","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("??","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("???","o")
  text=text:gsub("??","y")
  text=text:gsub("???","y")
  text=text:gsub("???","y")
  text=text:gsub("???","y")
  text=text:gsub("???","y")
  text=text:gsub("??","y")
  text=text:gsub("???","y")
  text=text:gsub("???","y")
  text=text:gsub("???","y")
  text=text:gsub("???","y")
  return string.lower(text);
end
return utils
