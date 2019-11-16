encrypto = {}

-- PrintTable(crypt)
encrypto = {}
encrypto.available = false

function CheckGmSvCryptInstalled()
	return (file.Exists("lua/bin/gmsv_crypt_win32.dll", "MOD"))
end
function CheckGmClCryptInstalled()
	return (file.Exists("lua/bin/gmcl_crypt_win32.dll", "MOD"))
end


if SERVER then

	encrypto.loadServerKeys = function()

		print("[ENCRYPTO] Loading outbound server keys..")

		local outboundKeys = encrypto.serverKeys["outbound"]

		if (!outboundKeys) then

			-- do keys exist in db?
			local outboundDBServerKeys = sql.QueryRow("SELECT * FROM server_keys WHERE ID='outbound'")
			print(sql.LastError())

			if (outboundDBServerKeys == nil) then

				print("[ENCRYPTO] Generating new outbound server keys..")

				-- generate a key value pair

				local privateKey, privateKeyError = encrypto.Crypter:GeneratePrimaryKey(1024)
				if (privateKey == nil) then print(privateKeyError) end

				local publicKey, publicKeyError = encrypto.Crypter:GenerateSecondaryKey(privateKey)
				if (publicKey == nil) then print(privateKeyError) end
				-- add to the database

				local insertNewKeys = sql.Query("INSERT INTO server_keys (ID, PrivateKey, PublicKey) VALUES ('outbound', '" .. privateKey .."', '" .. publicKey .. "'')")
				print(sql.LastError())
				
				encrypto.serverKeys["outbound"] = {}
				encrypto.serverKeys["outbound"]["public_key"] = publicKey
				encrypto.serverKeys["outbound"]["private_key"] = privateKey


				print("[ENCRYPTO] Successfully generated and inserted new server outbound pub/priv keys.")

			else

				print("[ENCRYPTO] Loading outbound keys from database...")

				encrypto.serverKeys["outbound"] = {}
				encrypto.serverKeys["outbound"]["public_key"] = outboundDBServerKeys["PublicKey"]
				encrypto.serverKeys["outbound"]["private_key"] = outboundDBServerKeys["PrivateKey"]


				print("[ENCRYPTO] Generating new outbound server keys..")

			end
		end

		print("[ENCRYPTO] Completed loading outbound server keys.")


		print("[ENCRYPTO] Loading inbound server keys..")

		local inboundKeys = encrypto.serverKeys["inbound"]

		if (!inboundKeys) then

			-- do keys exist in db?
			local inboundDBServerKeys = sql.QueryRow("SELECT * FROM server_keys WHERE ID='inbound'")
			print(sql.LastError())

			if (inboundDBServerKeys == nil) then

				print("[ENCRYPTO] Generating new inbound server keys..")

				-- generate a key value pair
				local privateKey, privateKeyError = encrypto.Crypter:GeneratePrimaryKey(1024)
				if (privateKey == nil) then print(privateKeyError) end
				
				local publicKey, publicKeyError = encrypto.Crypter:GenerateSecondaryKey(privateKey)
				if (publicKey == nil) then print(privateKeyError) end

				-- add to the database

				local insertNewKeys = sql.Query("INSERT INTO server_keys (ID, PrivateKey, PublicKey) VALUES ('inbound', '" .. privateKey .."', '" .. publicKey .. "'')")
				print("SQL", sql.LastError())
				
				encrypto.serverKeys["inbound"] = {}
				encrypto.serverKeys["inbound"]["public_key"] = publicKey
				encrypto.serverKeys["inbound"]["private_key"] = privateKey


				print("[ENCRYPTO] Successfully generated and inserted new server inbound pub/priv keys.")

			else

				print("[ENCRYPTO] Loading inbound keys from database...")

				encrypto.serverKeys["inbound"] = {}
				encrypto.serverKeys["inbound"]["public_key"] = inboundDBServerKeys["PublicKey"]
				encrypto.serverKeys["inbound"]["private_key"] = inboundDBServerKeys["PrivateKey"]


				print("[ENCRYPTO] Generating new inbound server keys..")

			end
		end

		print("[ENCRYPTO] Completed loading inbound server keys.")

	end


	encrypto.loadPlayerKeys = function(pPlayer)

		local steamId = pPlayer:SteamID()

		local playerKeys = encrypto.playerKeys[pPlayer:SteamID()]

		-- if the players keys is not in the local table cache
		if (!playerKeys) then

			local safeSteamID = sql.SQLStr(steamId)

			local dbPlayerKeys = sql.QueryRow("SELECT * FROM player_keys WHERE SteamID=" .. safeSteamID)
			print(sql.LastError())

			-- if we don't have the keys in the database.
			if (dbPlayerKeys == nil) then

				-- generate a key value pair

				local privateKey = encrypto.Crypter:GeneratePrimaryKey(1024)
				local publicKey = encrypto.Crypter:GenerateSecondaryKey(1024)

				-- add to the database

				local insertNewKeys = sql.Query("INSERT INTO player_keys (SteamID, PrivateKey, PublicKey) VALUES (" .. safeSteamID .. ", '" .. privateKey .."', '" .. publicKey .. "'')")
				print(sql.LastError())
				
				encrypto.playerKeys[safeSteamID] = {}
				encrypto.playerKeys[safeSteamID]["public_key"] = publicKey
				encrypto.playerKeys[safeSteamID]["private_key"] = privateKey

			else

				-- load the keys from the database to the RAM table.
				encrypto.playerKeys[safeSteamID] = {}
				encrypto.playerKeys[safeSteamID]["public_key"] = dbPlayerKeys["PublicKey"]
				encrypto.playerKeys[safeSteamID]["private_key"] = dbPlayerKeys["PrivateKey"]

			end

		end

		return encrypto.playerKeys[pPlayer:SteamID()]

	end

--[[
	Usage:

	local encryptedData, signature = encrypto.encryptAsServer("my name")
	local encryptedData = encrypto.encryptAsServer("my name")

	local decryptedData, signatureValid = encrypto.decryptAsServer("ENCRYPTED DATA", "ENCRYPTED DATA SIGNATURE")
	local decrptedData = encrypto.decryptAsServer("ENCRYPTED DATA")
]]
	encrypto.encryptAsServer = function(pRawData)
		-- crypts primary key is the private key
		-- crypt's secondary  key is the public key


		-- get the inbound public key
		local inboundPublicKey = encrypto.serverKeys["inbound"]["public_key"]
		 -- set the crypters public key to the inbound public key
		encrypto.Crypter:SetSecondaryKey(inboundPrivateKey)
		-- encrypt the data using the public key.
		local encryptedData = encrypto.Crypter:Encrypt(pRawData)

		local signature = encrypto.Hasher:CalculateDigest(pRawData)

		print(encryptedData, signature)

	end

	encrypto.decryptAsServer = function(pEncryptedData, pEncryptedDataSignature)
	end


	encrypto.encryptAsPlayer = function(pData, pPlayer)


	end


	-- Check that the binary is available.
	if (CheckGmSvCryptInstalled()) then

		encrypto.available = true

		encrypto.playerKeys = {} -- for securing Net library calls. (CACHE)
		-- encrypto.playerKeys["steamid"] = { "RSA pubkey". "RSA privkey" }
		encrypto.serverKeys = {}
		-- encrypto.serverKeys["outbound"]["public"] = "RSA pub key"
		-- encrypto.serverKeys["outbound"]["private"] = "RSA priv key"
		-- encrypto.serverKeys["inbound"]["public"] = "RSA pub key"
		-- encrypto.serverKeys["inbound"]["private"] = "RSA priv key"



		require("crypt")

		encrypto.Crypter = crypt.RSA() -- this is a class. eg. crypter = new RSA(), crypter->SetPrivateKey(), crypter->Encrypt()
		encrypto.Hasher = crypt.SHA256()


		print("[ENCRYPTO] Loaded gm_crypt", crypt.Version, encrypto.Crypter:AlgorithmName(), encrypto.Hasher:AlgorithmName())



		local playerTableExists = sql.TableExists("player_keys")
		local serverTableExists = sql.TableExists("server_keys")

		if (!playerTableExists) then
			sql.Query("CREATE TABLE player_keys (SteamID TEXT, PrivateKey TEXT, PublicKey TEXT)")
		end

		if (!serverTableExists) then
			sql.Query("CREATE TABLE server_keys (ID TEXT, PrivateKey TEXT, PublicKey TEXT)")
		end


		encrypto.loadServerKeys()
	end

end