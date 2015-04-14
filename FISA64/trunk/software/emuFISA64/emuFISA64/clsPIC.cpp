#include "StdAfx.h"
#include "clsPIC.h"


clsPIC::clsPIC(void)
{
	Reset();
}

void clsPIC::Reset(void)
{
	int nn;

	for (nn = 0; nn < 16; nn++) {
		enables[nn] = false;
	}
}
