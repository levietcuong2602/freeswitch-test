--
--	FusionPBX
--	Version: MPL 1.1
--
--	The contents of this file are subject to the Mozilla Public License Version
--	1.1 (the "License"); you may not use this file except in compliance with
--	the License. You may obtain a copy of the License at
--	http://www.mozilla.org/MPL/
--
--	Software distributed under the License is distributed on an "AS IS" basis,
--	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
--	for the specific language governing rights and limitations under the
--	License.
--
--	The Original Code is FusionPBX
--
--	The Initial Developer of the Original Code is
--	Mark J Crane <markjcrane@fusionpbx.com>
--	Copyright (C) 2010
--	the Initial Developer. All Rights Reserved.
--
--	Contributor(s):
--	Mark J Crane <markjcrane@fusionpbx.com>

max_tries = "3";
digit_timeout = "5000";

extension = argv[1];

--database
	--connect to the database
		--local dbh = freeswitch.Dbh("dsn","user","pass"); -- when using ODBC
		local dbh = freeswitch.Dbh("core:core"); -- when using sqlite

	--exits the script if we didn't connect properly
		assert(dbh:connected());

if ( session:ready() ) then
	session:answer( );
	pin_number = session:getVariable("pin_number");
	sounds_dir = session:getVariable("sounds_dir");
	domain_name = session:getVariable("domain_name");

	--set the sounds path for the language, dialect and voice
		default_language = session:getVariable("default_language");
		default_dialect = session:getVariable("default_dialect");
		default_voice = session:getVariable("default_voice");
		if (not default_language) then default_language = 'en'; end
		if (not default_dialect) then default_dialect = 'us'; end
		if (not default_voice) then default_voice = 'callie'; end

	--set defaults
		if (digit_min_length) then
			--do nothing
		else
			digit_min_length = "2";
		end

		if (digit_max_length) then
			--do nothing
		else
			digit_max_length = "11";
		end

	--if the pin number is provided then require it
		if (pin_number) then
			min_digits = string.len(pin_number);
			max_digits = string.len(pin_number)+1;
			digits = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/custom/please_enter_the_pin_number.wav", "", "\\d+");
			if (digits == pin_number) then
				--pin is correct
			else
				session:streamFile(sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/custom/your_pin_number_is_incorect_goodbye.wav");
				session:hangup("NORMAL_CLEARING");
				return;
			end
		end

	--check the database to get the uuid
		--eavesdrop
			sql = "select uuid from channels where presence_id = '"..extension.."@"..domain_name.."' ";
		dbh:query(sql, function(result)
			for key, val in pairs(result) do
				freeswitch.consoleLog("NOTICE", "result "..key.." "..val.."\n");
			end
			uuid = result.uuid;
		end);

end

--eavesdrop
	if (uuid) then
		session:execute("eavesdrop", uuid); --call barge
	end

--notes
	--originate a call
		--cmd = "originate user/1007@voip.example.com &eavesdrop("..uuid..")";
		--cmd = "uuid_bridge "..caller_uuid.." "..uuid;
		--api = freeswitch.API();
		--result = api:executeString(cmd);