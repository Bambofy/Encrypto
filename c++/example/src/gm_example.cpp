#include "GarrysMod/Lua/Interface.h"
#include <stdio.h>
#include "CryptoPackage/rsa.h"

/*
http://www.efgh.com/software/rsa.htm RSA implementation
http://www.efgh.com/software/mpuint.htm MPU integers
https://github.com/Duthomhas/CSPRNG PRNG 
*/

using namespace GarrysMod::Lua;

LUA_FUNCTION(CPP_GenerateKeys) {
	// private key is (d, pq)
	// public key is (e, pq)

	// e and d are called exponent
	// the number pq is called the modulus
	// here the modulus is the variable "n"

	// 512bit keys integers.
	// 512 / 16 = 32 indices

	// initialize 3 numbers variables.
	mpuint d(30), e(30), n(2);

	// generate the 3 numbers.
	GenerateKeys(d, e, n);

	// calculate the private key.
	mpuint privateKey = d; 
	privateKey += n; // (d,n) = private key.

	// calculate the public key.
	mpuint publicKey = e;
	publicKey += n; // (e,n) = public key.


	// find the ASCII value of the private key.
	char* privateKeyString = new char[128]; // 512 bits is 128 bytes.
	privateKey.edit(privateKeyString);

	// find the ASCII value of the public key.
	char* publicKeyString = new char[128]; // 512 bits is 128 bytes.
	publicKey.edit(publicKeyString);


	// push the ASCII keys to lua!
	LUA->PushString(privateKeyString, 128);
	LUA->PushString(publicKeyString, 128);


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

    return 0;
}

//
// Called when your module is closed
//
GMOD_MODULE_CLOSE()
{
    return 0;
}
