if SERVER then
	encrypto = {}

	encrypto.toByteListString = function(pByteString)
		local byteArray = {string.byte(pByteString, 1, string.len(pByteString)+1 )} -- convert vararg to table
		return table.concat(byteArray, ",")
	end

	encrypto.fromByteListString = function(pByteList)
		local byteArray = string.Explode(",", pByteList)

		local byteString = ""
		for k,v in ipairs(byteArray) do
			byteString = byteString .. string.char(v)
		end

		return byteString
	end

	encrypto.loadServerKeys = function()

		print("[ENCRYPTO] Loading server keys..")

		if (!encrypto.serverKeysLoaded) then

			-- do keys exist in db?
			local DBServerKeys = sql.QueryRow("SELECT * FROM server_keys")
			print(sql.LastError())

			if (DBServerKeys == nil) or (!DBServerKeys) then

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

				local sessionKey, sessionKeyError = encrypto.EncryptionSessionCrypter:GeneratePrimaryKey(256)
				if (sessionKeyError) then
					print(sessionKey)
					encrypto.available = false
				else
					sessionKeyReady = true
				end


				local sessionKeyIV, sessionKeyIVError = encrypto.EncryptionSessionCrypter:GenerateSecondaryKey(256)
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
					encrypto.serverKeysLoaded = true
				else
					encrypto.available = false
				end
			else

				print("[ENCRYPTO] Loading keys from database...")

				local sessionKeyReady = false
				local sessionKeyIVReady = false

				local sessionKey, sessionKeyError = encrypto.EncryptionSessionCrypter:GeneratePrimaryKey(256)
				if (sessionKeyError) then
					print(sessionKey)
					encrypto.available = false
				else
					sessionKeyReady = true
				end

				local sessionKeyIV, sessionKeyIVError = encrypto.EncryptionSessionCrypter:GenerateSecondaryKey(256)
				if (sessionKeyIVError) then
					print(sessionKeyIVError)
					encrypto.available = false
				else
					sessionKeyIVReady = true
				end

				if (sessionKeyReady and sessionKeyIVReady) then
					encrypto.serverKeys = {}
					encrypto.serverKeys["public_key"] = encrypto.fromByteListString(DBServerKeys["PublicKey"])
					encrypto.serverKeys["private_key"] = encrypto.fromByteListString(DBServerKeys["PrivateKey"])
					encrypto.serverKeys["session_key"] = sessionKey
					encrypto.serverKeys["session_key_iv"] = sessionKeyIV
					encrypto.serverKeysLoaded = true
				else
					encrypto.available = false
				end

			end
		end

		print("[ENCRYPTO] Completed loading server keys.")
	end


	encrypto.encrypt = function(pRawData)
		if (!encrypto.available) then
			print("[ENCRYPTO] ERROR ENCRYPTING!")
			return
		end
		-- crypts primary key is the private key
		-- crypt's secondary  key is the public key

		-- encrypt data with session key
		local sessionKey = encrypto.serverKeys["session_key"]
		local sessionKeyIV = encrypto.serverKeys["session_key_iv"]

		local sessionKeyIVSuccess, sessionKeyIVErr = encrypto.EncryptionSessionCrypter:SetSecondaryKey(sessionKeyIV)
		if (!sessionKeyIVSuccess) then
			print("Session Key IV Error", sessionKeyIVErr)
			encrypto.available = false
			return
		end

		local sessionKeySuccess, sessionKeyErr = encrypto.EncryptionSessionCrypter:SetPrimaryKey(sessionKey)
		if (!sessionKeySuccess) then
			print("Session Key Error", sessionKeyErr)
			encrypto.available = false
			return
		end
		
		local encryptedData, encryptedDataErr = encrypto.EncryptionSessionCrypter:Encrypt(pRawData)
		if (encryptedData == nil) then
			print("Encrypted Data Error", encryptedDataErr)
			encrypto.available = false
			return
		end

		-- encrypt session key with RSA keys
		local publicKey = encrypto.serverKeys["public_key"]

		local publicKeySuccess, publicKeyErr = encrypto.Crypter:SetSecondaryKey(publicKey)

		if (!publicKeySuccess) then
			print("Public Key Error", publicKeyErr)
			encrypto.available = false
			return
		end

		local completeSessionKey = sessionKeyIV .. sessionKey -- 64 bytes
		local encryptedSessionKey = encrypto.Crypter:Encrypt(completeSessionKey) -- ups to 128 bytes

		--print("session key length", encryptedSessionKey:len())

		local encryptedDataPacket = encryptedSessionKey .. encryptedData

		return encryptedDataPacket
	end

	encrypto.decrypt = function(pEncryptedData)
		if (!encrypto.available) then 
			print("[ENCRYPTO] ERROR ENCRYPTING!")
			return
		end

		-- the encrypted data is the encrypted session key and the encrypted data together.

		-- encrypted session key equals the session key IV + sessionKey which totals 64 bytes and then encrypted makes 128 bytes
		local encryptedCombinedSessionKeyIV = string.sub(pEncryptedData, 1, 128)-- first 128 bytes are the encrypted key and IV
		local encryptedData = string.sub(pEncryptedData, 129) 			-- remainig bytes are the encrypted data

		-- decrypt the session key and iv using the RSA crypter
		local privateKey = encrypto.serverKeys["private_key"]

		local primaryKeySuccess, privateKeyErr = encrypto.Crypter:SetPrimaryKey(privateKey)
		if (!primaryKeySuccess) then
			print("Decrypting Private Key Error", privateKeyErr)
			encrypto.available = false
			return
		end

		local publicKey = encrypto.serverKeys["public_key"]
		local publicKeySuccess, publicKeyErr = encrypto.Crypter:SetSecondaryKey(publicKey)
		if (!publicKeySuccess) then
			print(publicKeyErr)
			encrypto.available = false
			return
		end

		local decryptedCombinedSessionKey, sessionCombinedKeyDecryptionErr = encrypto.Crypter:Decrypt(encryptedCombinedSessionKeyIV)
		if (decryptedCombinedSessionKey == nil) then
			print(sessionCombinedKeyDecryptionErr)
			encrypto.available = false
			return
		end

		-- decode the combined session key into 2
		-- 64 bytes long decrypted, 32 bytes IV then 32 bytes key
		local sessionKeyIV = string.sub(decryptedCombinedSessionKey, 1, 32)
		local sessionKey = string.sub(decryptedCombinedSessionKey, 33)

		-- set up session crypter and decrypted the encrypted data part

		local sessionKeyIVSuccess, sessionKeyIVErr = encrypto.DecryptionSessionCrypter:SetSecondaryKey(sessionKeyIV) 		-- WARNING: the must be the decryption session crypter NOT encryption session crypter
		if (!sessionKeyIVSuccess) then
			print(sessionKeyIVErr)
			encrypto.available = false
			return
		end

		local sessionKeySuccess, sessionKeyErr = encrypto.DecryptionSessionCrypter:SetPrimaryKey(sessionKey)
		if (!sessionKeySuccess) then
			print(sessionKeyErr)
			encrypto.available = false
			return
		end


		-- use the session key to decrypt the data part.

		local decryptedData = encrypto.DecryptionSessionCrypter:Decrypt(encryptedData)
		
		return decryptedData
	end


	-- Check that the binary is available.
	if file.Exists("lua/bin/gmsv_crypt_win32.dll", "MOD") then

		require("crypt")
		
		encrypto.available = true

		encrypto.serverKeys = {}
		encrypto.serverKeysLoaded = false

		encrypto.Crypter = crypt.RSA() -- this is a class. eg. crypter = new RSA(), crypter->SetPrivateKey(), crypter->Encrypt()
		encrypto.EncryptionSessionCrypter = crypt.AES() -- this is a class. eg. crypter = new RSA(), crypter->SetPrivateKey(), crypter->Encrypt()
		encrypto.DecryptionSessionCrypter = crypt.AES() -- this oneis used to decrypt, since the paramters are given in the encrypted data.

		print("[ENCRYPTO] Loaded gm_crypt", crypt.Version, encrypto.Crypter:AlgorithmName(),  encrypto.EncryptionSessionCrypter:AlgorithmName(),  encrypto.DecryptionSessionCrypter:AlgorithmName())

		local serverTableExists = sql.TableExists("server_keys")

		if (!serverTableExists) then
			sql.Query("CREATE TABLE server_keys (ID TEXT, PrivateKey TEXT, PublicKey TEXT)")
		end

		encrypto.loadServerKeys()



		--[[ Example use]]
		local encryptedData = encrypto.encrypt("hello world")
		print(encryptedData)
		local decryptedData = encrypto.decrypt(encryptedData)
		print(decryptedData)
	end

end