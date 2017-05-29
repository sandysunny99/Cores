/* ===============================================================
	(C) 2014 Robert Finch
	(C) 2003 Bird Computer
	All rights reserved.

	a_all.c

		Please read the Licensing Agreement included in
	license.html. Use of this file is subject to the
	license agreement.

	You are free to use and modify this code for non-commercial
	or evaluation purposes.
	
	If you do modify the code, please state the origin and
	note that you have modified the code.
	
=============================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include "fwstr.h"
#include "Assembler.h"
#include "fstreamS19.h"
#include "operands6502.h"
#include "operands65002.h"
char *trim(char *str)
{
	rtrim(str);
	ltrim(str);
	return (str);
}
char *rtrim(char *str)
{
   int ii;

   ii = strlen(str);
   if (ii)
   {
      --ii;
      while(ii >= 0 && isspace(str[ii])) --ii;
      ii++;
      str[ii] = '\0';
   }
   return str;
}
char *ltrim(char *str)
{
   int ii = 0;
   int nn;

   while(isspace(str[ii])) ii++;
   for (nn = 0; str[ii]; nn++, ii++)
      str[nn] = str[ii];
   str[nn] = '\0';
   return str;
}



namespace RTFClasses
{
	void Assembler::AddToSearchList()
	{
		String fname;

		g_nops = getCpu()->getOp()->get();
		fname = ((Operands6502 *)getCpu()->getOp())->op[0];
		fname.trim('"');
		SearchList[nSearchList] = fname;
		nSearchList++;
	}

	//		Performs processing for .align psuedo op. Updates the
	//	appropriate counter.

	void Assembler::align()
	{
		long data;

		g_nops = getCpu()->getOp()->get();
		data = ((Operands6502 *)getCpu()->getOp())->op[0].val.value;
		DoingDc = true;
		gSzChar = 'B';
		switch(CurrentArea)
		{
			case CODE_AREA:
				//while(ProgramCounter.byte)
				//	emit8(0xff);
				if (ProgramCounter.val % data)
				{
					while(ProgramCounter.val % data)
					emit8(0xff);
				}
				break;

			case DATA_AREA:
				while(DataCounter.byte)
					emit8(0xff);
				if (DataCounter.val % data)
				{
					while(DataCounter.val % data)
					emit32(0xffffffff);
				}
				break;

			case BSS_AREA:
//				while(BSSCounter.byte)
//					emit8(0xff);
				if (BSSCounter.val % data)
				{
					while(BSSCounter.val % data) {
						emit32(0xffffffff);
					}
				}
				break;
		}
		DoingDc = false;
	}


	/* ---------------------------------------------------------------
			Sets output area to the bss area. If the bss counter has
		previously been set the new setting causes 0xff bytes to be
		written to the output file until the new setting is reached.
	--------------------------------------------------------------- */

	void Assembler::bss()
	{
		CurrentArea = BSS_AREA;
	}


	/* ---------------------------------------------------------------
		Description :
			Sets output area to the code area. If the program
		counter has previously been set the new setting causes 0xff
		bytes to be written to the output file until the new
		setting is reached.
	--------------------------------------------------------------- */

	void Assembler::code()
	{
		gSOut.flush();
		CurrentArea = CODE_AREA;
	}


	void Assembler::comment()
	{
		char ch;

		ch = ibuf->nextNonSpace();
		CommentChar = ch;
		printf("comment char=%c\r\n", CommentChar);
		InComment++;
	}


	void Assembler::a_cpu()
	{
		String name;
		int ii;

		ibuf->skipSpacesLF();
		for (ii = 0; IsIdentChar(ibuf->peekCh()); ii++)
			name += (char)ibuf->nextCh();
		name += '\0';
		setProcessor(name);
	}


	void Assembler::data()
	{
		gSOut.flush();
		CurrentArea = DATA_AREA;
	}


	/* ---------------------------------------------------------------
			Define constant. Byte or word constants may be
		generated by a valid arithmetic expression.
		Example:

		dc.b 'h','i',0   ;the string 'hi'
	--------------------------------------------------------------- */

	void Assembler::db(char szch)
	{
		int ii;
		char *s, ch, *p, *eptr, sch;
		const char *backcodes = { "abfnrtv0'\"\\" };
		const char *textequ = { "\a\b\f\n\r\t\v\0'\"\\" };

		gSzChar = szch;
		DoingDc = true;
		g_nops = getCpu()->getOp()->get();
		for (ii = 0; (s = ((Operands6502 *)getCpu()->getOp())->op[ii].buf()) && (ii < ((Operands6502 *)getCpu()->getOp())->nops); ii++)
		{
			sch = *s;
//			if (sch == '\'' || sch == '\"')
			if (sch == '\"')
			{
				s++;
				while (*s && *s != sch)
				{
					ch = *s;
					if (ch == '\\')
					{
					s++;
					ch = *s;
					p = (char *)strchr(backcodes, ch);
					if (p)
						emit(szch, (__int64)textequ[p - backcodes]);
					else
					{
						emit(szch, (__int64)strtol(s, &s, 0));
						--s;
					}
					}
					else
					emit(szch, (__int64)ch);
					s++;
				}
				if (*s == '\'')
					s++;
			}
			else {
				emit(szch, expeval(s, &eptr).value);
			}
		}
		DoingDc = false;
	}


/* ---------------------------------------------------------------
	Description :
		Define constant. Byte or word constants may be
	generated by a valid arithmetic expression.
	Example:

	 dc.b 'h','i',0   ;the string 'hi'

--------------------------------------------------------------- */
/*
int Assembler::dc(Opa *o)
{
   int ii;
   char *s, ch, *p, *eptr, sch;
   char *backcodes = { "abfnrtv0'\"\\" };
   const char *textequ = { "\a\b\f\n\r\t\v\0'\"\\" };

   DoingDc = TRUE;
   for (ii = 0; (s = ((Operands6502 *)getCpu()->op)->op[ii].text()) && (ii < MAX_OPERANDS); ii++)
   {
      sch = *s;
      if (sch == '\'' || sch == '\"')
      {
         s++;
         while (*s && *s != sch)
         {
            ch = *s;
            if (ch == '\\')
            {
               s++;
               ch = *s;
               p = (char *)strchr(backcodes, ch);
               if (p)
                  emit(gSzChar, (__int64)textequ[p - backcodes]);
               else
               {
                  emit(gSzChar, (__int64)strtol(s, &s, 0));
                  --s;
               }
            }
            else
               emit(gSzChar, (__int64)ch);
            s++;
         }
         if (*s == '\'')
            s++;
      }
      else
         emit(gSzChar, expeval(s, &eptr).value);
   }
   DoingDc = FALSE;
   return (TRUE);
}
*/

	// Ignores remainder of file.

	void Assembler::end()
	{
		ibuf->end();
	}


	/* ---------------------------------------------------------------
			Second part of macro definiton. Actually store the
		macro in the table. To this point lines for the macro have
		been collected in macrobuf.
	--------------------------------------------------------------- */
	void Assembler::endm()
	{
		String bdy2;
		char *bdy;
		Macro *mac;
		int ii;

		// First check if in the macro definition process
		if (!CollectingMacro) {
			Err(E_ENDM);
			return;
		}
		CollectingMacro = false;
		if (pass < 2)
		{
			try {
				mac = new Macro;
//				if (mac == NULL)
//					throw Err((int)E_MEMORY);
				macrobuf.rtrim();
				// Strip out spaces on the first line because these will be
				// supplied where the macro is to be substituted.
	//			ltrim(macrobuf.buf()+1);
				macrobuf += "\r\n";
				//printf("macrobuf:%s|\r\n",macrobuf.buf());
				mac->setBody(macrobuf);
				mac->setArgCount(gMacro.Nargs());
				mac->setName(gMacro.getName().buf());
				mac->setFileLine(gMacro.getFile(), gMacro.getLine());
				bdy = mac->initBody(parmlist);   // put parameter markers into body
				bdy2 = bdy;
				mac->setBody(bdy2);              // save body with markers
			}
			catch (char *msg) {
				printf(":%s\r\n", msg);
				getchar();
			}
		}
		// we don't need parms any more so free them up
		for (ii = 0; ii < MAX_MACRO_PARMS; ii++) {
			delete parmlist[ii];
			parmlist[ii] = NULL;
		}
		// Reset macro buffer
		macrobuf = "";
		if (pass < 2)
			macroTbl->insert(mac);
	}


	void Assembler::endr()
	{
		String bdy2;
		char *bdy;
		Rept *mac;
		int ii, slen, tomove;

		// First check if in the macro definition process
		if (!CollectingMacro) {
			Err(E_ENDM);
			return;
		}
		CollectingMacro = false;
		macrobuf.rtrim();
		// Strip out spaces on the first line because these will be
		// supplied where the macro is to be substituted.
//			ltrim(macrobuf.buf()+1);
		macrobuf += "\r\n";
		printf("got body:%s|\r\n", macrobuf.buf());
		gRept.setBody(macrobuf);
		bdy = gRept.initBody(parmlist);   // put parameter markers into body
		printf("1");
		bdy2 = bdy;
		gRept.setBody(bdy2);              // save body with markers
		printf("2");
		// we don't need parms any more so free them up
		for (ii = 0; ii < MAX_MACRO_PARMS; ii++) {
			delete parmlist[ii];
			parmlist[ii] = NULL;
		}
		printf("3");
		// Reset macro buffer
		macrobuf = "";
		slen = ibuf->ndx() - gRept.sptr;
		printf("replacing:%.*s|\r\n", slen, &ibuf->buf()[gRept.sptr]);
		// tomove = number of characters to move
		//        = buffer size - current pointer position
		tomove = ibuf->getSize() - (ibuf->getPtr() - ibuf->buf());
		// sptr = where to begin substitution
		//printf("sptr:%.*s|,slen=%d,tomove=%d\n", slen, sptr1,slen,tomove);
		printf("sptr:%.80s|\r\n", &ibuf->buf()[gRept.sptr]);
//		getchar();
		gRept.sub(NULL, ibuf, gRept.sptr, slen, tomove);
		ibuf->moveTo(gRept.sptr);
	}


/* ---------------------------------------------------------------
	Description :
		Defines a macro that doesn't take parameters. The
	macro definition is assumed to be the remaining text on the
	line unless the last character is '\' which continues the
	definition with the next line.

		Associate symbols with numeric values. During pass one
	any symbols encountered should not be previously defined.
	If a symbol that already exists is encountered in an equ
	statement during pass one then it is multiplely defined.
	This is an error.

	Returns:
		FALSE if the line isn't an equ statement, otherwise
	TRUE.
--------------------------------------------------------------- */

int Assembler::equ(char *iid)
{
	Symbol *p, tdef;
	__int64 n;
	char size, label[50];
	char *eptr, *ptr;
	char tbuf[80];
	Value v;
	bool defAlready = false;
	String nm;
	String s1;


	//size = (char)getSzChar();
	//if (size != 0 && !strchr("BCHWLDS", size))
	//{
	//	printf("wl1:\r\n");
	//	Err(E_LENGTH);       //Wrong length.
	//	return (TRUE);
	//}

	size = 0;
	ptr = ibuf->getPtr();    // Save off starting point // inptr;
	if (*ptr=='=')
		ibuf->nextCh();
	else {
		if (!ibuf->isNext((char *)"equ", 3))
			return 0;
	}

	/* -------------------------------------------------------
		Attempt to find the symbol in the symbol tree. If
	found during pass one then it is a redefined symbol
	error.
	------------------------------------------------------- */
	if (iid[0]=='.') {
        s1 = iid;
		nm = lastLabel;
        nm.add(s1);
   }
	else
		nm = iid;
	tdef.setName(nm.buf());
	p = NULL;
	if (localSymTbl && !File[FileNum].bGlobalEquates)
		p = localSymTbl->find(&tdef);
	if (p == NULL)
		p = gSymbolTable->find(&tdef);
	if(pass == 1)
	{
		//printf("ibuf:%.20s|\r\n", ibuf->getPtr());
		v = ibuf->expeval(&eptr);
		if(p != NULL)
		{
			defAlready = true;
			if (v.value!=p->getValue()) {
				Err(E_DEFINED, nm.buf());    // Symbol already defined.
				return (TRUE);
			}
		}

		if (p==NULL)
			p = new Symbol;
		if (p == NULL) {
			Err(E_MEMORY);
			return TRUE;
		}

      // assume a size if not specified
      if (size==0)
      {
//          if (gProcessor==102||gProcessor==65102)
//              size = 'W';
//            else
                size = 'W';
      }
		p->setSize(size);
		p->setName(nm.buf());
		p->setLabel(0);
		p->Def(NO_OCLASS, File[CurFileNum].LastLine, CurFileNum);

		if (!defAlready) {
			if (localSymTbl && !File[FileNum].bGlobalEquates)
				localSymTbl->insert(p);
			else
				gSymbolTable->insert(p);
		}

//		v = ibuf->expeval(&eptr);
		n = v.value;
	  // If the value is unsized set the size to long if it might
	  // contain a forward reference, otherwise set the size based
	  // on what the symbol evaluates to.
	  if (size == 0) {
		  if (v.fForwardRef) {
	  /*
              if (gProcessor==102||gProcessor==65102) {
			        p->SetSize('W');
			        size = 'W';
              }
              else { */
    			  p->setSize('W');
			        size = 'W';
//              }
		  }
		  else {
			  p->setSize(v.size);
		  }
	  }
      p->setValue(n);
      p->setDefined(true);
	  return TRUE;
   }
   /* --------------------------------------------------------
         During pass two the symbol should be in the symbol
      tree as it would have been encountered during the
      first pass.
   -------------------------------------------------------- */
   else if(pass >= 2)
   {
      if(p == NULL)
      {
         Err(E_NOTDEFINED, iid); // Undefined symbol.
         return (TRUE);
      }

      /* -----------------------------------------------------
            Calculate what the symbol is equated to since
         forward references may now be filled in causing the
         value of the equate to be different than pass one 
         during pass two.
      ------------------------------------------------------ */
      v = ibuf->expeval(&eptr);
	  n = v.value;
      if(theAssembler.errtype == false)
      {
         return (TRUE);
      }
      p->setValue(n);

      /* ---------------------------------------------------------------------
            Print symbol value if in listing mode. The monkey business with
         tbuf is neccessary to chop off leading 'FF's when the value is
         negative.
      --------------------------------------------------------------------- */
      if(bGen && fListing)
      {
         switch(toupper(v.size/*  size*/))
         {
            case 'B':
               sprintf(tbuf, "%08.8X", (int)n);
               memmove(tbuf, &tbuf[6], 3);
               fprintf(fpList, "%7d = %s%*s", OutputLine, tbuf, SRC_COL-14,"");
               col = SRC_COL-1;
               break;

            case 'C':
            case 'H':
               sprintf(tbuf, "%08.8X", (int)n);
               memmove(tbuf, &tbuf[4], 5);
               fprintf(fpList, "%7d = %s%*s", OutputLine, tbuf, SRC_COL-16, "");
 			   col = SRC_COL-1;
               break;
			default:
            case 'W':
            case 'L':
               sprintf(tbuf, "%08.8I64X", n);
  //             memmove(tbuf, &tbuf[0], 9);
               fprintf(fpList, "%7d = %s%*s", OutputLine, tbuf, SRC_COL-20, "");
 
               col = SRC_COL-1;
               break;

			case 'S':
			case 'D':
               sprintf(tbuf, "%08.8X", (int)(n >> 32));
               sprintf(&tbuf[8], "%08.8X", (int)n);
               //memmove(&tbuf[8], &tbuf[8], 7);
               fprintf(fpList, "%7d = %s%*s", OutputLine, tbuf, SRC_COL-14, "");
				col = SRC_COL-1;
               break;
         }
//         OutListLine();
      }
   }
   return (TRUE);
}


	/* ---------------------------------------------------------------
			Declare external symbols. External symbols are added to
		the global symbol table with the extern oclass, if not
		already defined as public or extern.
	--------------------------------------------------------------- */
	void Assembler::a_extern()
	{
		char *sptr, *eptr;
		char ch;
		char label[NAME_MAX+1];
		int len, first = 1;
		Symbol tdef, *p;

		// Set default size of long if not specified.
		if (gSzChar == 0) gSzChar = 'W';
		// Size must be either word or long.
		if (gSzChar != 'W' && gSzChar != 'H') {
			Err(E_WORDLONG);
			gSzChar = 'W';
		}

		do
		{
			len = ibuf->getIdentifier(&sptr, &eptr);
			if (first) {
				if (len < 1) {
					Err(E_ADDRLABEL);
					return;
				}
				first = 0;
			}
			ch = ibuf->nextNonSpaceLF();
			len = min(len, sizeof(label)-1);
			strncpy(label, sptr, len);
			label[len] = '\0';
			tdef.setName(label);
			p = gSymbolTable->find(&tdef);
			//    If symbol already exists then validate the size, but
			// otherwise ignore.
			if (p)
			{
				if (p->getSize() != gSzChar)
					Err(E_SIZE);
			}
			// If symbol doesn't exist then add as extern
			else {
				Symbol *sym = new Symbol;
				if (sym == NULL) {
					Err(E_MEMORY);
					return;
				}
				sym->setDefined(false);
				sym->setName(label);
				sym->setSize(gSzChar);
				p = gSymbolTable->insert(sym);
				if (p == NULL) {
					Err(E_MEMORY);
					return;
				}
				p->Def(EXT, File[CurFileNum].LastLine, CurFileNum);
			}
		} while (ch == ',');
	}

	// Mostly done on 92/09/19

	void Assembler::fill()
	{
		long i,n, j;

		//   printf("Fill: %c, %s, %s\n", gSzChar, theAssembler.gOperand[0], theAssembler.gOperand[1]);
		gSzChar = getSzChar();
		if (gSzChar == 0)
			gSzChar = 'W';
		if (!strchr("WCB", gSzChar)) {
			Err(E_LENGTH); // Wrong length..
			return;
		}
		g_nops = getCpu()->getOp()->get();
		i = ((Operands6502 *)getCpu()->getOp())->op[0].val.value;
		n = ((Operands6502 *)getCpu()->getOp())->op[1].val.value;
		DoingDc = TRUE;
		for (j = 0; j < i; j++)
			emit(gSzChar, n);
		DoingDc = FALSE;
	}


	/* ---------------------------------------------------------------
			Processes include directive. This is somewhat tricky
		because of the fact that there may be text in the input
		buffer after the include directive due to a macro
		expansion. The input buffer has to be saved and restored.
	--------------------------------------------------------------- */

	void Assembler::include()
	{
		char buf[300];
		int ret, fnum;
		//String tmp;
		char *tmp;
		char *ptr;
		int ndx;
		int tmplineno;
		int sol3;
		time_t tim;
#ifdef DEMO
		Err(E_DEMOI);
		return;
#endif

		sol3 = getStartOfLine();
		g_nops = getCpu()->getOp()->get();
		memset(buf, '\0', sizeof(buf));
		strncpy(buf, ((Operands6502 *)getCpu()->getOp())->op[0].buf(), sizeof(buf)-1);
		buf[sizeof(buf)-1] = '\0';

		// Trim quotes from filename
		if (buf[0]=='"' || buf[0]=='\'')
			memmove(buf, &buf[1], strlen(buf));
		if (buf[strlen(buf)-1]=='"' || buf[strlen(buf)-1]=='\'')
			buf[strlen(buf)-1]='\0';
		trim(buf);
		tmplineno = lineno;
		fnum = CurFileNum;
		lineno = 0;
		tmp = strdup(ibuf->buf());  // Save copy of input buffer
		if (tmp == NULL) {
			Err(E_MEMORY);
			ret = FALSE;
		}
		else {
//			ptr = ibuf->getPtr();
			ndx = ibuf->ndx();
			//ptr++;
			//ibuf->clear();        // Start with fresh buffer for new file.
			FileLevel++;
			processFile(buf, (char *)"*");
			FileLevel--;
			if (FileLevel == 0)
				localSymTbl = NULL;
//			memcpy(ibuf->getBuf(), tmp, tmp.len());  // Restore input buffer.
			ibuf->enlarge(strlen(tmp)+10);
			ibuf->copy(tmp,strlen(tmp));
			//strcpy(ibuf->buf(), tmp);
			free(tmp);
			//ibuf=File[fnum].getBuf();
			ibuf->setptr(&ibuf->buf()[ndx]);
			//getCpu()->getOp()->setInput(ibuf);
			lineno = tmplineno;
			CurFileNum = fnum;
			// echo filename
			fprintf(fpErr, "File: %s\r\n", File[CurFileNum].name.buf());
			if(isGenerationPass() && fListing == TRUE) {
				time(&tim);
				fprintf(fpList, verstr, ctime(&tim), page);
				fputs(File[CurFileNum].name.buf(), fpList);
				fputs("\r\n", fpList);
				fputs("\r\n\r\n", fpList);
			}
		}
//		gOperand[0] = buf;	// So it can be freed on return to PrcMneumonic.
		setStartOfLine(sol3);
		return;
	}


	void Assembler::list()
	{
		char *line;

		printf("list pseudo op detected\n");
		g_nops = getCpu()->getOp()->get();
		line = ((Operands6502 *)getCpu()->getOp())->op[0].buf() + strspn(((Operands6502 *)getCpu()->getOp())->op[0].buf(), " \t");
		fListing = !strnicmp(line, "on", 2);
	}


	void Assembler::lword()
	{
	}


	/* ---------------------------------------------------------------
			Processes a macro definition. Gets optional macro
		parameter list then sets a flag indicating that the main
		assembling loop should collect lines for a macro
		definition. The 'endm' mnemonic is checked for in the main
		loop and the remainder of the definition is processed when
		'endm' is detected.

		Macros have the form

			macro MACRONAME parameter[,parameter]...
			.
			.
			.
			endm

		The body of the macro is copied to the macro buffer.
	--------------------------------------------------------------- */

	void Assembler::macro()
	{
		char *sptr, *eptr;
		char nbuf[NAME_MAX+1];
		int idlen, xx;
		Macro *fmac;

		gNargs = 0;
		macrobuf = "";
		idlen = ibuf->getIdentifier(&sptr, &eptr);
		if (idlen == 0)
		{
			//printf("aaa:%.20s|\r\n", sptr);
			Err(E_MACRONAME);
			return;
		}
		if (pass < 2)
		{
			memset(nbuf, '\0', sizeof(nbuf));
			memcpy(nbuf, sptr, min(idlen, NAME_MAX));
			gMacro.setName(nbuf);
			fmac = (Macro *)macroTbl->find(&gMacro);
			if (fmac)
			{
				Err(E_DEFINED, nbuf);
				return;
			}
		}
		// Free parameter list (if not already freed)
		for (xx = 0; xx < MAX_MACRO_PARMS; xx++)
			if (parmlist[xx]) {
				delete parmlist[xx];
				parmlist[xx] = NULL;
			}

		xx = gNargs = ibuf->getParmList(parmlist);
		gMacro.setArgCount(xx);
		gMacro.setFileLine(CurFileNum, File[CurFileNum].LastLine);
		CollectingMacro = true;
	}


	int Assembler::macro2(char *iid)
	{
		Symbol *p, tdef;
		char *eptr;
		char *sptr;
		char nbuf[NAME_MAX+1];
		int idlen, xx;
		Macro *fmac;

		if (!ibuf->isNext((char *)".macro", 6) && !ibuf->isNext((char *)"macro",5)) {
//			printf("next:%.5s|\r\n", ibuf->getPtr());
//			getchar();
			return 0;
		}
		gNargs = 0;
		macrobuf = "";
		idlen = strlen(iid);
		if (idlen == 0)
		{
			Err(E_MACRONAME);
			return 0;
		}
		if (pass < 2)
		{
			memset(nbuf, '\0', sizeof(nbuf));
			memcpy(nbuf, iid, min(idlen, NAME_MAX));
			gMacro.setName(nbuf);
			fmac = (Macro *)macroTbl->find(&gMacro);
			if (fmac)
			{
				Err(E_DEFINED, nbuf);
				return 0;
			}
		}
		// Free parameter list (if not already freed)
		for (xx = 0; xx < MAX_MACRO_PARMS; xx++)
			if (parmlist[xx]) {
				delete parmlist[xx];
				parmlist[xx] = NULL;
			}
		//printf("ibuf:%.20s|\r\n",ibuf->getPtr());
		xx = gNargs = ibuf->getParmList(parmlist);
		gMacro.setArgCount(xx);
		gMacro.setFileLine(CurFileNum, File[CurFileNum].LastLine);
		CollectingMacro = true;
		return 1;
	}


	void Assembler::rept()
	{
		char *sptr, *eptr;
		char nbuf[NAME_MAX+1];
		int idlen, xx, ii;
		Rept *fmac;

		gNargs = 0;
		macrobuf = "";
		// Free parameter list (if not already freed)
		for (xx = 0; xx < MAX_MACRO_PARMS; xx++)
			if (parmlist[xx]) {
				delete parmlist[xx];
				parmlist[xx] = NULL;
			}

		xx = gNargs = ibuf->getParmList(parmlist);
		if (xx < 1) {
			Err(E_REPCNT);
			gRept.count = 1;
		}
		else {
			gRept.count = expeval(parmlist[0]->buf(),&eptr).value;
			for (ii = 1; ii < xx; ii++) {
				parmlist[ii-1] = parmlist[ii];
			}
			delete parmlist[ii];
			parmlist[ii] = NULL;
		}
		gRept.sptr = sol;
		gRept.setArgCount(xx-1);
		gRept.setFileLine(CurFileNum, File[CurFileNum].LastLine);
		CollectingMacro = true;
	}

	void Assembler::message()
	{
		g_nops = getCpu()->getOp()->get();
//		fprintf(stdout, "%x: ", getCounter().val);
		fprintf(stdout, ((Operands6502 *)getCpu()->getOp())->op[0].buf());
		fprintf(stdout, "\n");
	}


	/* ---------------------------------------------------------------
			Sets the value of the program counter. If the program
		counter has previously been set the new setting causes 0xff
		bytes to be written to the output file until the new
		setting is reached.
	--------------------------------------------------------------- */

	void Assembler::org()
	{
		static int orgd = 0, orgc = 0;
		U32 loc;

		g_nops = getCpu()->getOp()->get();
		loc = ((Operands6502 *)getCpu()->getOp())->op[0].val.value;
		if (CurrentArea == BSS_AREA)
			BSSCounter.set(loc);
		else {
			if (fSOut)
				gSOut.flush();
			if (orgd == pass)
			{
				if (fBinOut | bMemOut | fListing) {
					DoingDc = true;
					//printf("%x %x\r\n", getCounter().val, loc);
					//getchar();
					while (getCounter().val < loc) {
					//printf("%x %x\r\n", getCounter().val, loc);
						emit('B', 0xff);
					}
					DoingDc = false;
				}
				getCounter().set(loc);
			}
			else
			{
				getCounter().set(loc);
				orgd = pass;
			}
		}
	}


	/* ---------------------------------------------------------------
			Process a public declaration. All that happens here is
		the symbol is flagged as public so that when object code is
		generated it is included in a public declarations record.
		An entry is put into the symbol table if the symbol is not
		yet in the table. If the symbol is followed by a ':' then
		a label definition is assumed and label definition
		processing code is called. A list of symbols may be made
		public using the ',' as a separater.
	--------------------------------------------------------------- */

	void Assembler::a_public()
	{
		char *eptr, *sptr;
		int len, ch;
		Symbol tdef, *p;
		char labeln[100];
		String lbl;
		SymbolTable *lst;

		len = ibuf->getIdentifier(&sptr, &eptr);
		if (len < 1)
		{
			Err(E_PUBLIC);
			return;
		}
		ch = ibuf->nextNonSpaceLF();
		len = min(len, sizeof(labeln)-1);
		strncpy(labeln, sptr, len);
		labeln[len] = '\0';
		if (labeln[0]!='.') {
			lastLabel = labeln;
			lbl = labeln;
		}
		else {
			lbl = lastLabel;
			lbl.add(labeln);
        }
		tdef.setName(lbl.buf());
		// A forward reference may have been placed in the local symbol table.
		// Promote it to global.
		p = NULL;
		lst = getLocalSymTbl();
		if (lst)
			p = lst->find(&tdef);
		if (p) {
			if (tdef.getName()==(char *)"loadBootFile7") {
				printf("rmv lbf7\r\n");
				getchar();
			}
			lst->remove(p);
			if (!getGlobalSymTbl()->find(&tdef))
				getGlobalSymTbl()->insert(p);
		}
		p = gSymbolTable->find(&tdef);

		if (p) {
			if (pass < 2 && p->isDefined()) {
				ForceErr = 1;
				Err(E_DEFINED, lbl.buf());
				ForceErr = 0;
			}
			else
				p->define(PUB);
		}
		else
			label(labeln, PUB);
		if (ch != ':')
			ibuf->unNextCh();
	}


	int Assembler::out8(Opa *o)
	{
		emit8(o->oc);
		return (TRUE);
	}

	int Assembler::out16(Opa *o)
	{
		emit16(o->oc);
		return (TRUE);
	}


	int Assembler::out24(Opa *o)
	{
		emit8(o->oc&0xff);
		emit16(o->oc>>8);
		return (TRUE);
	}


	int Assembler::out32(Opa *o)
	{
		emit32(o->oc);
		return (TRUE);
	}
}
