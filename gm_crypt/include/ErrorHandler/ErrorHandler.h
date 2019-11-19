#ifndef ERROR_HANDLER_H
#define ERROR_HANDLER_H

extern bool ERROR_HANDLER_NUMERIC_OVERFLOW_FLAG = false;

extern void ERROR_HANDLER_NumericOverflow()
{
	ERROR_HANDLER_NUMERIC_OVERFLOW_FLAG = true;
}

#endif