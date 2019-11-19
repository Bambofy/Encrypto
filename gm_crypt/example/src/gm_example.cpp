#include "GarrysMod/Lua/Interface.h"
#include <stdio.h>
#include <string.h>
#include "CryptoPackage/rsa.h"

/*
http://www.efgh.com/software/rsa.htm RSA implementation
http://www.efgh.com/software/mpuint.htm MPU integers
https://github.com/Duthomhas/CSPRNG PRNG 
*/

using namespace GarrysMod::Lua;

/*

	unsigned short* mpuint -> unsigned char* mpuintStr

	unsigned char* mputintStr -> unsigned short* mpuInt
	
*/

void MPUInt_To_String(const mpuint *inMpuInt, char *outString)
{
	for (int i = 0; i < inMpuInt->length; i++)
	{
		unsigned short mpuIntIndex = inMpuInt->value[i];

		// unsigned short is 16 bits wide.
		
		// our string can only hold 8 bits at an index.

		char leftSide = mpuIntIndex >> 8;
		char rightSide = mpuIntIndex & 0x00FF;

		outString[(i * 2)] = leftSide;
		outString[(i * 2) + 1] = rightSide;
	}

	outString[inMpuInt->length] = '\0';
}
void String_To_MPUInt(mpuint *outMpuInt, const char *inString)
{
	for (int i = 0; i < (sizeof(inString) - 1); i+=2)
	{
		const char leftSideValue = inString[i];
		const char rightSideValue = inString[i + 1];


		unsigned short mpuInt = (leftSideValue << 8) | (rightSideValue & 0x00FF); // move the left side over

		outMpuInt->value[i / 2] = mpuInt;
	}
}

LUA_FUNCTION(CPP_EncryptDecrypt)
{
	size_t keyLength;
	const char* key = LUA->GetString(1, &keyLength); // this value is 65 bytes long, 1 byte for the null char.

	size_t sourceLength;
	const char* source = LUA->GetString(2, &sourceLength); // this value is 33 bytes long, 1 byte for the null char.

	// the key string is 64 bytes long.
	// the first 32 bytes are the exponent.
	// the remaining 32 bytes are the modulus.

	// get the individual strings of the exponent and module parts.
	char* keyExponent = new char[32];
	char* keyModulus = new char[32];

	strncpy(keyExponent, key, 32);
	strncpy(keyModulus, key, 32);

	// convert the exponent to an integer.
	// e = 32 bytes = 256 bits
	// 256 = 16 * 16 bits.
	mpuint keyExponentInt(16);
	String_To_MPUInt(&keyExponentInt, keyExponent);

	// conver the modulus to an integer.
	mpuint keyModulusInt(16);
	String_To_MPUInt(&keyModulusInt, keyModulus);


	// get the source as an mpuint.
	mpuint sourceValue(16);
	String_To_MPUInt(&sourceValue, source);


	mpuint result(16);
	EncryptDecrypt(result, sourceValue, keyExponentInt, keyModulusInt);

	
	char* resultString = new char[33]; // 1 byte for \0.
	MPUInt_To_String(&result, resultString);

	LUA->PushString(resultString);

	delete[] resultString;
	delete[] keyExponent;
	delete[] keyModulus;

	return 1;
}

LUA_FUNCTION(CPP_GenerateKeys)
{
	// private key is (d, pq)
	// public key is (e, pq)

	// e and d are called exponent
	// the number pq is called the modulus
	// here the modulus is the variable "n"

	// 512bit keys integers.
	// 64 byte keys.
	// 32 byte d, e, n.
	// 32 bytes = 256 bits
	// 256 = 16 * 16 bit numbers.

	// initialize 3 numbers variables.
	mpuint d(16), e(16), n(16);

	// generate the 3 numbers.
	GenerateKeys(d, e, n);

	char* nStr = new char[32];
	n.edit(nStr);

	// find the ASCII value of the private key.
	char* dStr = new char[32];
	d.edit(dStr);

	// find the ASCII value of the public key.
	char* eStr = new char[32];
	e.edit(eStr);

	char* privateKey = new char[64];
	strcpy(privateKey, dStr);
	strcat(privateKey, nStr);

	char* publicKey = new char[64];
	strcpy(publicKey, eStr);
	strcpy(publicKey, nStr);

	// push the ASCII keys to lua!
	LUA->PushString(privateKey, 64);
	LUA->PushString(publicKey, 64);

	delete[] nStr;
	delete[] dStr;
	delete[] eStr;

	delete[] privateKey;
	delete[] publicKey;

	return 1;
}

/*

require( "example" );

MsgN( TestFunction() );

MsgN( TestFunction( 24.75 ) );

*/

LUA_FUNCTION( MyExampleFunction )
{
    if ( LUA->IsType( 1, Type::NUMBER ) )
    {
        char strOut[512];
        double fNumber = LUA->GetNumber( 1 );
        sprintf_s( strOut, "Thanks for the number - I love %f!!", fNumber );
        LUA->PushString( strOut );
        return 1;
    }

    LUA->PushString( "This string is returned" );
    return 1;
}

//
// Called when you module is opened
//
GMOD_MODULE_OPEN()
{
    //
    // Set Global[ "TextFunction" ] = MyExampleFunction
    //
    LUA->PushSpecial( SPECIAL_GLOB );        // Push global table
    LUA->PushString( "TestFunction" );       // Push Name
    LUA->PushCFunction( MyExampleFunction ); // Push function
    LUA->SetTable( -3 );                     // Set the table 

	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->PushString("GenerateKeyPair");
	LUA->PushCFunction(CPP_GenerateKeys);
	LUA->SetTable(-3);

	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->PushString("Decrypt");
	LUA->PushCFunction(CPP_EncryptDecrypt);
	LUA->SetTable(-3);

	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->PushString("Encrypt");
	LUA->PushCFunction(CPP_EncryptDecrypt);
	LUA->SetTable(-3);


    return 0;
}

//
// Called when your module is closed
//
GMOD_MODULE_CLOSE()
{
    return 0;
}
