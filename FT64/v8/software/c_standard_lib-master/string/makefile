# Makefile for STRING
#
PATH = $PATH;D:\Cores5\FT64\v7\software\C64\C64\debug\;D:\Cores5\FT64\v7\software\A64\A64\debug\;D:\Cores5\FT64\v7\software\FPP\FPP\debug\;D:\Cores5\FT64\v7\software\APP\debug\;"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.15.26726\bin\Hostx64\x64"
FPPINC = d:\Cores5\FT64\v7\software\source\;d:\Cores5\FT64\v7\software\FMTK\source\kernel\;d:\Cores5\FT64\v7\software\inc
APPINC = d:\Cores5\FT64\v7\software\source\;d:\Cores5\FT64\v7\software\FMTK\source\kernel\;d:\Cores5\FT64\v7\software\inc
INC = d:\Cores5\FT64\v7\software\source\;d:\Cores5\FT64\v7\software\FMTK\source\kernel\;d:\Cores5\FT64\v7\software\inc
INCLUDE = d:\Cores5\FT64\v7\software\source\;d:\Cores5\FT64\v7\software\FMTK\source\kernel\;d:\Cores5\FT64\v7\software\inc
#CCX = cc64
CFLAGS = -w -S
ASMS = \
	memchr.s \
	memcmp.s \
	memcpy.s \
	memmove.s \
	memset.s \
	memsetH.s \
	memsetW.s \
	strcat.s \
	strchr.s \
	strcmp.s \
	strcoll.s \
	strcpy.s \
	strcspn.s \
	strerror.s \
	strlen.s \
	strncat.s \
	strncpy.s \
	strpbrk.s \
	strrchr.s \
	strspn.s \
	strstr.s \
	strtok.s \
	strxfrm.s \
	xstrxfrm.s

all:	$(ASMS)
	echo "made STRING"
           
STRING:	$(ASMS)
	echo "made STRING"

.c.s:
	cc64 $(CFLAGS) $<

clean:
	del *.s
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir

