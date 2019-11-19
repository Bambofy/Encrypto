# Encrypto - Garrysmod Addon

## WARNING READ THIS FIRST!

This addon is an alpha version, be **careful!!!** if you encrypt data and lose your private key **you will lose that data forever!**

The **private key is held in the sv.db table server_keys**, if you delete this sv.db you will **lose your data forever** so make a backup of your sv.db after you run Encrypto for the first time to backup the keys.

## Introduction

This addon allows serverside encryption. It uses AES (symmetrical) and RSA (asymetric) to encrypt any string given.

In summary, it uses AES to encrypt the data, and then uses RSA to encrypt the AES key. Those two encrypted data sets are then concatinated and saved, then split when decrypting. The technique used to encrypt is detailed here http://www.efgh.com/software/rsa.htm

This repo **includes a built gm_crypt win32 dll** which is included in the root directory

**Example Code:**

    local encryptedData = encrypto.encrypt("hello knockout")
    print(encryptedData)
    local decryptedData = encrypto.decrypt(encryptedData)
    print(decryptedData)



It uses the binary module gm_crypt [https://github.com/danielga/gm_crypt](https://github.com/danielga/gm_crypt) 

