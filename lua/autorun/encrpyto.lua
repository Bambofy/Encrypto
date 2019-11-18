encrypto = {}
encrypto.available = false


if SERVER then

	encrypto.toByteListString = function(pByteString)
		local byteArray = {string.byte(pByteString, 1, string.len(pByteString))} -- convert vararg to table
		return table.concat(byteArray, ",")
	end

	encrypto.fromByteListString = function(pByteList)
		local byteArray = string.Explode(",", pByteList)

		local byteString = ""
		for k,v in ipairs(byteArray) do
			byteString = byteString .. string.format("%c", v)
		end

		return byteString
	end

	encrypto.loadServerKeys = function()

		print("[ENCRYPTO] Loading outbound server keys..")

		local outboundKeys = encrypto.serverKeys["outbound"]

		if (!outboundKeys) then

			-- do keys exist in db?
			local outboundDBServerKeys = sql.QueryRow("SELECT * FROM server_keys WHERE ID='outbound'")
			print(sql.LastError())

			if (outboundDBServerKeys == nil) then

				print("[ENCRYPTO] Generating new server keys..")

				-- generate a key value pair

				local privateKeyReady = false
				local publicKeyReady = false
				local sessionKeyReady = false
				local sessionKeyIVReady = false

				local privateKey, privateKeyError = encrypto.Crypter:GeneratePrimaryKey(1024)
				if (privateKey == nil) then 
					print(privateKeyError)
					encrypto.available = false -- disable the addon if not functioning
				else
					privateKeyReady = true
				end

				local publicKey, publicKeyError = encrypto.Crypter:GenerateSecondaryKey(privateKey)
				if (publicKey == nil) then 
					print(publicKeyError)
					encrypto.available = false -- disable the addon if not functioning
				else
					publicKeyReady = true
				end

				local sessionKey, sessionKeyError = encrypto.SessionCrypter:GeneratePrimaryKey(256)
				if (sessionKeyError) then
					print(sessionKey)
					encrypto.available = false
				else
					sessionKeyReady = true
				end

				local sessionKeyIV, sessionKeyIVError = encrypto.SessionCrypter:GenerateSecondaryKey(256)
				if (sessionKeyIVError) then
					print(sessionKeyIVError)
					encrypto.available = false
				else
					sessionKeyIVReady = true
				end

				-- add to the database
				if (privateKeyReady and publicKeyReady and sessionKeyReady and sessionKeyIVReady) then

					local insertNewKeys = sql.Query("INSERT INTO server_keys (PrivateKey, PublicKey) VALUES ('" .. encrypto.toByteListString(privateKey) .."', '" .. encrypto.toByteListString(publicKey) .. "')")
					print(sql.LastError())
					
					encrypto.serverKeys = {}
					encrypto.serverKeys["public_key"] = publicKey
					encrypto.serverKeys["private_key"] = privateKey
					encrypto.serverKeys["session_key"] = sessionKey
					encrypto.serverKeys["session_key_iv"] = sessionKeyIV
				end
			else

				print("[ENCRYPTO] Loading outbound keys from database...")

				local sessionKeyReady = false
				local sessionKeyIVReady = false

				local sessionKey, sessionKeyError = encrypto.SessionCrypter:GeneratePrimaryKey(256)
				if (sessionKeyError) then
					print(sessionKey)
					encrypto.available = false
				else
					sessionKeyReady = true
				end

				local sessionKeyIV, sessionKeyIVError = encrypto.SessionCrypter:GenerateSecondaryKey(256)
				if (sessionKeyIVError) then
					print(sessionKeyIVError)
					encrypto.available = false
				else
					sessionKeyIVReady = true
				end

				encrypto.serverKeys = {}
				encrypto.serverKeys["public_key"] = outboundDBServerKeys["PublicKey"]
				encrypto.serverKeys["private_key"] = outboundDBServerKeys["PrivateKey"]
				encrypto.serverKeys["session_key"] = sessionKey
				encrypto.serverKeys["session_key_iv"] = sessionKeyIV

			end
		end

		print("[ENCRYPTO] Completed loading outbound server keys.")
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
		local inboundPublicKeyHexString = encrypto.serverKeys["inbound"]["public_key"]
		local inboundPublicKey = encrypto.Crypter:FromHexString(inboundPublicKeyHexString)

		 -- set the crypters public key to the inbound public key
		encrypto.Crypter:SetSecondaryKey(inboundPublicKey)

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
	if file.Exists("lua/bin/gmsv_crypt_win32.dll", "MOD") then


		require("crypt")
		
		encrypto.available = true

		encrypto.serverKeys = {}

		encrypto.Crypter = crypt.RSA() -- this is a class. eg. crypter = new RSA(), crypter->SetPrivateKey(), crypter->Encrypt()
		encrypto.SessionCrypter = crypt.AES() -- this is a class. eg. crypter = new RSA(), crypter->SetPrivateKey(), crypter->Encrypt()


		print("[ENCRYPTO] Loaded gm_crypt", crypt.Version, encrypto.Crypter:AlgorithmName(),  encrypto.SessionCrypter:AlgorithmName())

		local serverTableExists = sql.TableExists("server_keys")

		if (!serverTableExists) then
			sql.Query("CREATE TABLE server_keys (ID TEXT, PrivateKey TEXT, PublicKey TEXT)")
		else
			sql.Query("DROP TABLE server_keys")
			sql.Query("CREATE TABLE server_keys (ID TEXT, PrivateKey TEXT, PublicKey TEXT)")
		end



		encrypto.loadServerKeys()
	end

end