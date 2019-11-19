#include "CryptoPackage/mpuint.h"
#include "CryptoPackage/random.h"
#include "CSPRNG/csprng.hpp"

static int RandomKey(void)
{
	/*
	int n = 0;
	while (kbhit() == 0)
		n++;
	int c = getch();
	if (c == 0)
		c = getch();
	putch(' ' <= c && c <= '~' ? c : ' ');
	return c + n & 0xFF;
	*/
}

void Random(mpuint& x)
{
	duthomhas::csprng rng;

	unsigned short randomTempVar;
	for (unsigned i = 0; i < x.length; i++)
	{
		// generate 16 bit random integer.
		rng(randomTempVar);
		x.value[i] = randomTempVar;
	}
	/*
	cprintf("Please type %d random characters\r\n", x.length * 2);
	while (kbhit() != 0)
		RandomKey();
	for (unsigned i = 0; i < x.length; i++)
		x.value[i] = RandomKey() << 8 | RandomKey();
	cprintf("\r\nThank you\r\n");
	*/
}
