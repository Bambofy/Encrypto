encrypto = {}
encrypto.available = false

function CheckGmSvCryptInstalled()
	return (file.Exists("lua/bin/gmsv_crypt_win32.dll", "MOD"))
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

				local privateKeyReady = false
				local publicKeyReady = false

				local privateKey, privateKeyError = encrypto.Crypter:GeneratePrimaryKey(256)
				if (privateKey == nil) then 
					print(privateKeyError)
					encyrpto.available = false -- disable the addon if not functioning
				else
					privateKeyReady = true
				end

				local publicKey, publicKeyError = encrypto.Crypter:GenerateSecondaryKey(privateKey)
				if (publicKey == nil) then 
					print(publicKeyError)
					encyrpto.available = false -- disable the addon if not functioning
				else
					publicKeyReady = true
				end

				-- add to the database
				if (privateKeyReady and publicKeyReady) then
					local privateKeyHexString = encrypto.Crypter:ToHexString(privateKey)
					local publicKeyHexString = encrypto.Crypter:ToHexString(publicKey)

					local insertNewKeys = sql.Query("INSERT INTO server_keys (ID, PrivateKey, PublicKey) VALUES ('outbound', '" .. privateKeyHexString .."', '" .. publicKeyHexString .. "')")
					print(sql.LastError())
					
					encrypto.serverKeys["outbound"] = {}
					encrypto.serverKeys["outbound"]["public_key"] = publicKeyHexString
					encrypto.serverKeys["outbound"]["private_key"] = privateKeyHexString
				end
			else

				print("[ENCRYPTO] Loading outbound keys from database...")

				encrypto.serverKeys["outbound"] = {}
				encrypto.serverKeys["outbound"]["public_key"] = outboundDBServerKeys["PublicKey"]
				encrypto.serverKeys["outbound"]["private_key"] = outboundDBServerKeys["PrivateKey"]

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

				local privateKeyReady = false
				local publicKeyReady = false

				local privateKey, privateKeyError = encrypto.Crypter:GeneratePrimaryKey(256)
				if (privateKey == nil) then 
					print(privateKeyError)
					encyrpto.available = false -- disable the addon if not functioning
				else
					privateKeyReady = true
				end

				local publicKey, publicKeyError = encrypto.Crypter:GenerateSecondaryKey(privateKey)
				if (publicKey == nil) then 
					print(publicKeyError)
					encyrpto.available = false -- disable the addon if not functioning
				else
					publicKeyReady = true
				end

				-- add to the database
				if (privateKeyReady and publicKeyReady) then
					local privateKeyHexString = encrypto.Crypter:ToHexString(privateKey)
					local publicKeyHexString = encrypto.Crypter:ToHexString(publicKey)
					
					local insertNewKeys = sql.Query("INSERT INTO server_keys (ID, PrivateKey, PublicKey) VALUES ('inbound', '" .. privateKeyHexString .."', '" .. publicKeyHexString .. "')")
					print(sql.LastError())
					
					encrypto.serverKeys["outbound"] = {}
					encrypto.serverKeys["outbound"]["public_key"] = publicKeyHexString
					encrypto.serverKeys["outbound"]["private_key"] = privateKeyHexString
				end

				print("[ENCRYPTO] Successfully generated and inserted new server inbound pub/priv keys.")

			else

				print("[ENCRYPTO] Loading inbound keys from database...")

				encrypto.serverKeys["inbound"] = {}
				encrypto.serverKeys["inbound"]["public_key"] = inboundDBServerKeys["PublicKey"]
				encrypto.serverKeys["inbound"]["private_key"] = inboundDBServerKeys["PrivateKey"]

			end
		end

		print("[ENCRYPTO] Completed loading inbound server keys.")

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
	if (CheckGmSvCryptInstalled()) then

		encrypto.available = true

		encrypto.serverKeys = {}
		-- encrypto.serverKeys["outbound"]["public"] = "RSA pub key"
		-- encrypto.serverKeys["outbound"]["private"] = "RSA priv key"
		-- encrypto.serverKeys["inbound"]["public"] = "RSA pub key"
		-- encrypto.serverKeys["inbound"]["private"] = "RSA priv key"



		require("crypt")

		encrypto.Crypter = crypt.RSA() -- this is a class. eg. crypter = new RSA(), crypter->SetPrivateKey(), crypter->Encrypt()
		encrypto.Hasher = crypt.SHA256()


		print("[ENCRYPTO] Loaded gm_crypt", crypt.Version, encrypto.Crypter:AlgorithmName(), encrypto.Hasher:AlgorithmName())

		local serverTableExists = sql.TableExists("server_keys")

		if (!serverTableExists) then
			sql.Query("CREATE TABLE server_keys (ID TEXT, PrivateKey TEXT, PublicKey TEXT)")
		end


		encrypto.loadServerKeys()
	end

end