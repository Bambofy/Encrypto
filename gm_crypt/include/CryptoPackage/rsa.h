#ifndef H__RSA
#define H__RSA

#include "CryptoPackage/mpuint.h"

void GenerateKeys(mpuint& d, mpuint& e, mpuint& n);

inline void EncryptDecrypt(mpuint& result, const mpuint& source,
	const mpuint& e, const mpuint& n)
{
	mpuint::Power(source, e, n, result);
}

#endif