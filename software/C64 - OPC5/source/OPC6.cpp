// ============================================================================
// (C) 2017 Robert Finch
// All Rights Reserved.
// robfinch<remove>@finitron.ca
//
// C64 - 'C' derived language compiler
//  - 64 bit CPU
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#include "stdafx.h"

extern int lastsph;
extern char *semaphores[20];
extern int throwlab;
extern int breaklab;
extern int contlab;
extern int retlab;

extern TYP *stdfunc;

extern void scan(Statement *);
extern int GetReturnBlockSize();
void GenerateReturn(Statement *stmt);
int TempFPInvalidate();
int TempInvalidate();
void TempRevalidate(int);
void TempFPRevalidate(int);
void ReleaseTempRegister(AMODE *ap);
AMODE *GetTempRegister();
void GenLdi(AMODE *, AMODE *);
extern AMODE *copy_addr(AMODE *ap);
extern void GenLoad(AMODE *ap1, AMODE *ap3, int ssize, int size);

/*
 *      returns the desirability of optimization for a subexpression.
 */
static int OptimizationDesireability(CSE *csp)
{
	if( csp->voidf || (csp->exp->nodetype == en_icon &&
                       csp->exp->i < 32767 && csp->exp->i >= -32767))
        return 0;
    if (csp->exp->nodetype==en_cnacon)
        return 0;
	if (csp->exp->isVolatile)
		return 0;
    if( IsLValue(csp->exp) )
	    return 2 * csp->uses;
    return csp->uses;
}

static int CSECmp(const void *a, const void *b)
{
	CSE *csp1, *csp2;
	int aa,bb;

	csp1 = (CSE *)a;
	csp2 = (CSE *)b;
	aa = OptimizationDesireability(csp1);
	bb = OptimizationDesireability(csp2);
	if (aa < bb)
		return (-1);
	else if (aa == bb)
		return (0);
	else
		return (1);
}

static int CSECount(CSE *p)
{
	int count;

	for(count = 0; p; count++) {
		p = p->next;
	}
	return (count);
}

// ----------------------------------------------------------------------------
// AllocateRegisterVars will allocate registers for the expressions that have
// a high enough desirability.
// ----------------------------------------------------------------------------

int AllocateRegisterVars()
{
	CSE *csp;
    ENODE *exptr;
    int reg;
	uint64_t mask, rmask;
    uint64_t fpmask, fprmask;
    AMODE *ap, *ap2;
	int64_t nn;
	int cnt;
	int size;
	int csecnt;

	reg = 3;
    mask = 0;
	rmask = 0;
	fpmask = 0;
	fprmask = 0;
//	printf("Count:%d\r\n", CSECount(olist));

	// Sort the CSE table according to desirability of allocating
	// a register.
	qsort(CSETable,csendx,sizeof(CSE),CSECmp);

	// Initialize to no allocated registers
	for (csecnt = 0; csecnt < csendx; csecnt++)
		CSETable[csecnt].reg = -1;

	// Make multiple passes over the CSE table in order to use
	// up all temporary registers. Allocates on the progressively
	// less desirable.
	for (nn = 0; nn < 6; nn++) {
		for (csecnt = 0; csecnt < csendx; csecnt++)	{
			csp = &CSETable[csecnt];
			if (csp->reg==-1) {
				if( OptimizationDesireability(csp) >= 4-nn ) {
   					//if(( csp->duses > csp->uses / 2) && reg < 5 )
					if (csp->uses > 3 && reg < 5)
   						csp->reg = reg++;
				}
			}
		}
	}

	// Generate bit masks of allocated registers
	for (csecnt = 0; csecnt < csendx; csecnt++) {
		csp = &CSETable[csecnt];
		if( csp->reg != -1 )
    	{
    		rmask = rmask | (1LL << (63 - csp->reg));
    		mask = mask | (1LL << csp->reg);
    	}
	}

	// Push temporaries on the stack.
	if( mask != 0 ) {
		cnt = 0;
		//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(popcnt(mask)*sizeOfWord));
		for (nn = 0; nn < 64; nn++) {
			if (rmask & (0x8000000000000000ULL >> nn)) {
				//GenerateDiadic(op_sto,0,makereg(nn&15),make_indexed(cnt,regSP));
				GenerateMonadic(op_push,0,makereg(nn&15));
				cnt+=sizeOfWord;
			}
		}
	}

    save_mask = mask;
    fpsave_mask = fpmask;
    csp = olist;

	// Initialize temporaries
	for (csecnt = 0; csecnt < csendx; csecnt++) {
		csp = &CSETable[csecnt];
        if( csp->reg != -1 )
        {               // see if preload needed
            exptr = csp->exp;
            if( !IsLValue(exptr) || (exptr->p[0] && exptr->p[0]->i > 0) || (exptr->nodetype==en_struct_ref))
            {
                initstack();
				{
                    ap = GenerateExpression(exptr,F_REG|F_IMMED|F_MEM,sizeOfWord);
    				ap2 = makereg(csp->reg);
    				if (ap->mode==am_immed)
                        GenLdi(ap2,ap);
    				else if (ap->mode==am_reg)
    					GenerateDiadic(op_mov,0,ap2,ap);
    				else {
    					size = GetNaturalSize(exptr);
    					ap->isUnsigned = exptr->isUnsigned;
    					GenLoad(ap2,ap,size,size);
    				}
                }
                ReleaseTempReg(ap);
            }
        }
    }
	return (popcnt(mask));
}


AMODE *GenExpr(ENODE *node)
{
	AMODE *ap1,*ap2,*ap3;
	int lab0, lab1;
	int size;
	int pop;
	int pl,pushed;

    lab0 = nextlabel++;
    lab1 = nextlabel++;

	switch(node->nodetype) {
	case en_eq:		break;
	case en_ne:		break;
	case en_lt:		break;
	case en_ult:	break;
	case en_le:		break;
	case en_ule:	break;
	case en_gt:		break;
	case en_ugt:	break;
	case en_ge:		break;
	case en_uge:	break;
	default:	// en_land, en_lor
		pl = GeneratePreload();
		GenerateFalseJump(node,lab0,0);
		ap1 = GetTempRegister2(&pushed);
		if (pushed) {
			GenerateTriadic(op_mov,0,ap1,makereg(regZero),make_immed(1));
			GenLdi(ap1,make_immed(1));
			GenerateTriadic(op_mov,0,makereg(regPC),makereg(0),make_label(lab1));
			GenerateLabel(lab0);
			GenerateDiadic(op_mov,0,ap1,makereg(regZero));
			GenerateLabel(lab1);
		}
		else {
			pop = peep_tail->back->predop;
			OverwritePreload(pl,op_mov,0,ap1,makereg(regZero),make_immed(1),nullptr);
			GeneratePredicatedTriadic(pop,op_mov,0,ap1,makereg(regZero),nullptr);
		}
		return ap1;
	}

	switch(node->nodetype) {
	case en_eq:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateTriadic(op_mov,0,ap3,makereg(regZero),make_immed(1));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_nz,op_mov,0,ap3,makereg(regZero),nullptr);
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_ne:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateTriadic(op_mov,0,ap3,makereg(regZero),make_immed(1));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_z,op_mov,0,ap3,makereg(regZero),nullptr);
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_lt:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateTriadic(op_mov,0,ap3,makereg(regZero),make_immed(1));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_pl,op_mov,0,ap3,makereg(regZero),nullptr);
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_le:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateTriadic(op_mov,0,ap3,makereg(regZero),make_immed(1));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_pl,op_mov,0,ap3,makereg(regZero),nullptr);
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_gt:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateDiadic(op_mov,0,ap3,makereg(regZero));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_pl,op_mov,0,ap3,makereg(regZero),make_immed(1));
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_ge:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateDiadic(op_mov,0,ap3,makereg(regZero));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_pl,op_mov,0,ap3,makereg(regZero),make_immed(1));
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_ult:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateTriadic(op_mov,0,ap3,makereg(regZero),make_immed(1));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_nc,op_mov,0,ap3,makereg(regZero),nullptr);
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_ule:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateTriadic(op_mov,0,ap3,makereg(regZero),make_immed(1));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_nc,op_mov,0,ap3,makereg(regZero),nullptr);
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_ugt:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateDiadic(op_mov,0,ap3,makereg(regZero));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_nc,op_mov,0,ap3,makereg(regZero),make_immed(1));
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	case en_uge:
		size = GetNaturalSize(node);
		ap3 = GetTempRegister();
		GenerateDiadic(op_mov,0,ap3,makereg(regZero));
		ap1 = GenerateExpression(node->p[0],F_REG,size);
		ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
		if (ap2->mode==am_immed)
			GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_nc,op_mov,0,ap3,makereg(regZero),make_immed(1));
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return (ap3);
	}
	//size = GetNaturalSize(node);
    ap3 = GetTempRegister();         
	//ap1 = GenerateExpression(node->p[0],F_REG,size);
	//ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
	//GenerateTriadic(op,0,ap3,ap1,ap2);
 //   ReleaseTempRegister(ap2);
 //   ReleaseTempRegister(ap1);
    return (ap3);
}

void GenerateCmp(ENODE *node, int label, int predreg, unsigned int prediction)
{
	int size;
	AMODE *ap1, *ap2;
	int lab1;

	size = GetNaturalSize(node);
    ap1 = GenerateExpression(node->p[0],F_REG, size);
	ap2 = GenerateExpression(node->p[1],F_REG|F_IMMED,size);
	switch(node->nodetype) {
	case en_eq:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_z,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		break;
	case en_ne:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_nz,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		break;
	case en_lt:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_mi,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		break;
	case en_le:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_mi,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_z,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		break;
	case en_gt:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		lab1 = nextlabel++;
		GeneratePredicatedTriadic(pop_z,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(lab1));
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_pl,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		GenerateLabel(lab1);
		break;
	case en_ge:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		lab1 = nextlabel++;
		GeneratePredicatedTriadic(pop_pl,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		GenerateLabel(lab1);
		break;
	case en_ult:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_c,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		break;
	case en_ule:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_c,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_z,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		break;
	case en_ugt:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		lab1 = nextlabel++;
		GeneratePredicatedTriadic(pop_z,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(lab1));
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		GeneratePredicatedTriadic(pop_nc,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		GenerateLabel(lab1);
		break;
	case en_uge:
		size = GetNaturalSize(node);
		if (ap2->mode==am_immed) {
			if (ap2->offset->i==0)
				GenerateDiadic(op_cmp,0,ap1,makereg(regZero));
			else
				GenerateTriadic(op_cmp,0,ap1,makereg(regZero),ap2);
		}
		else
			GenerateDiadic(op_cmp,0,ap1,ap2);
		lab1 = nextlabel++;
		GeneratePredicatedTriadic(pop_nc,op_mov,0,makereg(regPC),makereg(regZero),make_clabel(label));
		GenerateLabel(lab1);
		break;
	}
	//GenerateTriadic(op,sz,ap1,ap2,make_clabel(label));
   	ReleaseTempReg(ap2);
   	ReleaseTempReg(ap1);
}


static void GenerateDefaultCatch(SYM *sym)
{
	//GenerateLabel(throwlab);
	//if (sym->IsLeaf){
	//	if (sym->DoesThrow) {
	//		GenerateDiadic(op_lw,0,makereg(regLR),make_indexed(sizeOfWord,regBP));		// load throw return address from stack into LR
	//		GenerateDiadic(op_sw,0,makereg(regLR),make_indexed(sizeOfWord*2,regBP));		// and store it back (so it can be loaded with the lm)
	//		GenerateDiadic(op_bra,0,make_label(retlab),NULL);				// goto regular return cleanup code
	//	}
	//}
	//else {
	//	GenerateDiadic(op_lw,0,makereg(regLR),make_indexed(sizeOfWord,regBP));		// load throw return address from stack into LR
	//	GenerateDiadic(op_sw,0,makereg(regLR),make_indexed(sizeOfWord*2,regBP));		// and store it back (so it can be loaded with the lm)
	//	GenerateDiadic(op_bra,0,make_label(retlab),NULL);				// goto regular return cleanup code
	//}
}

// Generate a function body.
//
void GenerateFunction(SYM *sym)
{
	AMODE *ap;
    int defcatch;
	int nn;
	Statement *stmt = sym->stmt;
	int lab0;
	int o_throwlab, o_retlab, o_contlab, o_breaklab;

	o_throwlab = throwlab;
	o_retlab = retlab;
	o_contlab = contlab;
	o_breaklab = breaklab;

	throwlab = retlab = contlab = breaklab = -1;
	lastsph = 0;
	memset(semaphores,0,sizeof(semaphores));
	throwlab = nextlabel++;
	defcatch = nextlabel++;
	lab0 = nextlabel++;
	gd->GenMixedSource();
	//GenerateZeradic(op_calltgt);
	while( lc_auto & 1 )	/* round frame size to word */
		++lc_auto;
	if (sym->IsInterrupt) {
		//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(13*sizeOfWord));
		for (nn = 1; nn < 14; nn++) {
			//GenerateTriadic(op_sto,0,makereg(nn),makereg(regSP),make_immed((nn-1)*sizeOfWord));
			GenerateMonadic(op_push,0,makereg(nn));
		}
    //   if (sym->stkname)
    //       GenerateDiadic(op_lea,0,makereg(SP),make_string(sym->stkname));
	   //for (nn = 30; nn > 0; nn--)
		  // GenerateMonadic(op_push,0,makereg(nn));
	}
	// The prolog code can't be optimized because it'll run *before* any variables
	// assigned to registers are available. About all we can do here is constant
	// optimizations.
	if (sym->prolog) {
		scan(sym->prolog);
	    sym->prolog->Generate();
	}
	if (!sym->IsNocall) {
		/*
		// For a leaf routine don't bother to store the link register.
		if (sym->IsLeaf) {
    		//GenerateTriadic(op_addi,0,makereg(regSP),makereg(regSP),make_immed(-4));
			if (exceptions)
				GenerateMonadic(op_push, 0, makereg(regXLR));
			GenerateMonadic(op_push,0,makereg(regBP));
        }
		else
		*/
		{
			//GenerateMonadic(op_push, 0, makereg(regBP));
			ap = make_label(throwlab);
			ap->mode = am_immed;
		}
		// The stack doesn't need to be linked if there is no stack space in use and there
		// are no parameters passed to the function. Since function parameters are
		// referenced to the BP register the stack needs to be linked if there are any.
		// Stack link/unlink is optimized away by the peephole optimizer if they aren't
		// needed. So they are just always spit out here.
		//snprintf(buf, sizeof(buf), "#-%sSTKSIZE_-8",sym->mangledName->c_str());
		GenerateMonadic(op_hint,0,make_immed(4));
		//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(sym->IsLeaf ? sizeOfWord: sizeOfWord*2));
		if (!sym->IsLeaf) {
			//GenerateDiadic(op_sto,0,makereg(regLR),make_indexed(0,regSP));
			GenerateMonadic(op_push,0,makereg(regLR));
		}
		//GenerateDiadic(op_sto,0,makereg(regBP),make_indexed(sym->IsLeaf ?0 : sizeOfWord,regSP));
		GenerateMonadic(op_push,0,makereg(regBP));
		GenerateDiadic(op_mov,0,makereg(regBP), makereg(regSP));
		if (sym->stkspace!=0) {
			if (sym->stkspace < 16)
				GenerateDiadic(op_dec,0,makereg(regSP),make_immed(sym->stkspace));
			else 
				GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(sym->stkspace));
		}
		GenerateMonadic(op_hint,0,make_immed(5));
	}
	if (optimize)
		opt1(stmt);
    stmt->Generate();
    GenerateReturn(nullptr);
	if (exceptions && sym->IsInline)
		GenerateTriadic(op_mov,0,makereg(regPC),makereg(regZero),make_label(lab0));

	throwlab = o_throwlab;
	retlab = o_retlab;
	contlab = o_contlab;
	breaklab = o_breaklab;
}


// Unlink the stack
// For a leaf routine the link register and exception link register doesn't need to be saved/restored.

static void UnlinkStack(SYM * sym)
{
	GenerateMonadic(op_hint,0,make_immed(6));
	GenerateDiadic(op_mov,0,makereg(regSP),makereg(regBP));
	if (!sym->IsLeaf) {
		GenerateMonadic(op_pop,0,makereg(regLR));
	}
	GenerateMonadic(op_pop,0,makereg(regBP));
	GenerateMonadic(op_hint,0,make_immed(7));
}


// Restore registers used as register variables.

static void RestoreRegisterVars()
{
	int cnt2, cnt;
	int nn;

	if( save_mask != 0 ) {
		cnt2 = cnt = bitsset(save_mask)*sizeOfWord;
		for (nn = 31; nn >=1 ; nn--) {
			if (save_mask & (1LL << nn)) {
				//GenerateDiadic(op_ld,0,makereg(nn),make_indexed(cnt,regSP));
				GenerateMonadic(op_pop,0,makereg(nn));
				cnt -= sizeOfWord;
			}
		}
		//GenerateTriadic(op_add,0,makereg(regSP),makereg(regZero),make_immed(bitsset(save_mask)*sizeOfWord));
	}
}

// Generate a return statement.
//
void GenerateReturn(Statement *stmt)
{
	AMODE *ap, *ap1;
	int nn;
	int toAdd;
	SYM *sym = currentFn;
	SYM *p;

  // Generate the return expression and force the result into r1.
  if( stmt != NULL && stmt->exp != NULL )
  {
		initstack();
		ap = GenerateExpression(stmt->exp,F_REG|F_IMMED,sizeOfWord);
		GenerateMonadic(op_hint,0,make_immed(2));
		if (ap->mode == am_immed)
		    GenLdi(makereg(1),ap);
		else if (ap->mode == am_reg) {
            if (sym->tp->GetBtp() && (sym->tp->GetBtp()->type==bt_struct || sym->tp->GetBtp()->type==bt_union)) {
				p = sym->params.Find("_pHiddenStructPtr",false);
				if (p) {
					if (sym->tp->GetBtp()->size > 4) {
						GenerateMonadic(op_push,0,makereg(8));
						GenerateMonadic(op_push,0,makereg(9));
						GenerateMonadic(op_push,0,makereg(10));
						if (p->IsRegister)
							GenerateDiadic(op_mov,0,makereg(8),makereg(p->reg));
						else {
							ap1 = make_indexed(p->value.i,regBP);
							ap1->offset->sym = p;
							GenerateDiadic(op_ld,0,makereg(8),ap1);
						}
						GenerateDiadic(op_mov,0,makereg(9),ap);
						GenLdi(makereg(10),make_immed(sym->tp->GetBtp()->size));
						GenerateTriadic(op_jsr,0,makereg(regLR),makereg(regZero),make_string("_memcpy"));
						GenerateMonadic(op_pop,0,makereg(10));
						GenerateMonadic(op_pop,0,makereg(9));
						GenerateMonadic(op_pop,0,makereg(8));
					}
					else {
						AMODE *ap2, *ap3;

						ap2 = GetTempRegister();
						ap3 = GetTempRegister();
						ap1 = make_indexed(p->value.i,regBP);
						ap1->offset->sym = p;
						GenerateDiadic(op_ld,0,ap3,ap1);
						GenerateDiadic(op_ld,0,ap2,ap);
						GenerateDiadic(op_sto,0,ap2,ap3);
						if (sym->tp->GetBtp()->size > 1) {
							GenerateTriadic(op_ld,0,ap2,ap,make_immed(1));
							GenerateTriadic(op_sto,0,ap2,ap3,make_immed(1));
						}
						if (sym->tp->GetBtp()->size > 2) {
							GenerateTriadic(op_ld,0,ap2,ap,make_immed(2));
							GenerateTriadic(op_sto,0,ap2,ap3,make_immed(2));
						}
						if (sym->tp->GetBtp()->size > 3) {
							GenerateTriadic(op_ld,0,ap2,ap,make_immed(3));
							GenerateTriadic(op_sto,0,ap2,ap3,make_immed(3));
						}
						ReleaseTempReg(ap3);
						ReleaseTempReg(ap2);
					}
				}
				else {
					// ToDo compiler error
				}
            }
            else
			    GenerateDiadic(op_mov, 0, makereg(1),ap);
        }
		else
		    GenLoad(makereg(1),ap,sizeOfWord,sizeOfWord);
		ReleaseTempRegister(ap);
	}

	// Generate the return code only once. Branch to the return code for all returns.
	if (retlab != -1) {
		GenerateTriadic(op_mov,0,makereg(regPC),makereg(regZero),make_label(retlab));
		return;
	}
	retlab = nextlabel++;
	GenerateLabel(retlab);
		
	RestoreRegisterVars();
    if (sym->IsNocall) {
		if (sym->epilog) {
			sym->epilog->Generate();
			return;
		}
		return;
    }
	UnlinkStack(sym);
	toAdd = sizeOfWord;

	if (sym->epilog) {
		sym->epilog->Generate();
		return;
	}
        
	// Generate the return instruction. For the Pascal calling convention pop the parameters
	// from the stack.
	if (sym->IsInterrupt) {
		for (nn = 1; nn < 14; nn++) {
			if (sym->tp->GetBtp()->type!=bt_long || nn != 1)
				GenerateTriadic(op_ld,0,makereg(nn),makereg(regSP),make_immed((nn-1)*sizeOfWord));
		}
		GenerateTriadic(op_add,0,makereg(regSP),makereg(regZero),make_immed(13*sizeOfWord));
		GenerateZeradic(op_rti);
		return;
	}

	// If Pascal calling convention remove parameters from stack by adding to stack pointer
	// based on the number of parameters. However if a non-auto register parameter is
	// present, then don't add to the stack pointer for it. (Remove the previous add effect).
	if (sym->IsPascal) {
		TypeArray *ta;
		int nn;
		ta = sym->GetProtoTypes();
		for (nn = 0; nn < ta->length; nn++) {
			switch(ta->types[nn]) {
			case bt_float:
			case bt_quad:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000)==0)
					;
				else
					toAdd += sizeOfFPQ;
				break;
			case bt_double:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000)==0)
					;
				else
					toAdd += sizeOfFPD;
				break;
			case bt_triple:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000)==0)
					;
				else
					toAdd += sizeOfFPT;
				break;
			default:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000)==0)
					;
				else
					toAdd += sizeOfWord;
			}
		}
	}
	if (!sym->IsInline)
		GenerateDiadic(op_mov,0,makereg(regPC),makereg(regLR));
}

static int round4(int n)
{
    while(n & 3) n++;
    return (n);
};

static void SaveTemporaries(SYM *sym, int *sp, int *fsp)
{
	if (sym) {
		if (sym->UsesTemps) {
			*sp = TempInvalidate();
		}
	}
	else {
		*sp = TempInvalidate();
	}
}

static void RestoreTemporaries(SYM *sym, int sp, int fsp)
{
	if (sym) {
		if (sym->UsesTemps) {
			TempRevalidate(sp);
		}
	}
	else {
		TempRevalidate(sp);
	}
}

static int CountPreg(TypeArray *ta)
{
	int cnt;
	int nn;

	for (cnt = nn = 0; nn < ta->length; nn++)
		if (ta->preg[nn])
			cnt++;
	return cnt;
}

// Saves any registers used as parameters in the calling function.

static void SaveRegisterParameters(SYM *sym)
{
	TypeArray *ta;

	if (sym == nullptr)
		return;
	ta = sym->GetProtoTypes();
	if (ta) {
		int nn;
		nn = CountPreg(ta);
		if (nn > 0) {
			//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(nn * sizeOfWord));
			for (nn = 0; nn < ta->length; nn++) {
				if (ta->preg[nn]) {
					//switch(ta->types[nn]) {
					//case bt_quad:	GenerateMonadic(op_push,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//case bt_float:	GenerateMonadic(op_push,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//case bt_double:	GenerateMonadic(op_push,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//case bt_triple:	GenerateMonadic(op_push,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//default:	GenerateDiadic(op_sto,0,makereg(ta->preg[nn]& 0x7fff),make_indexed(nn * sizeOfWord,regSP)); break;
					//}
					//GenerateDiadic(op_sto,0,makereg(ta->preg[nn]& 0x7fff),make_indexed(nn * sizeOfWord,regSP));
					GenerateMonadic(op_push,0,makereg(ta->preg[nn]& 0x7fff));
				}
			}
		}
	}
}

static void RestoreRegisterParameters(SYM *sym)
{
	TypeArray *ta;

	if (sym == nullptr)
		return;
	ta = sym->GetProtoTypes();
	if (ta) {
		int nn;
		int cn;
		cn = nn = CountPreg(ta);
		if (nn > 0) {
			for (nn = ta->length - 1; nn >= 0; nn--) {
				if (ta->preg[nn]) {
					//switch(ta->types[nn]) {
					//case bt_quad:	GenerateMonadic(op_pop,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//case bt_float:	GenerateMonadic(op_pop,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//case bt_double:	GenerateMonadic(op_pop,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//case bt_triple:	GenerateMonadic(op_pop,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//default:	GenerateMonadic(op_pop,0,makereg(ta->preg[nn]& 0x7fff)); break;
					//}
					//GenerateDiadic(op_ld,0,makereg(ta->preg[nn]& 0x7fff),make_indexed(nn * sizeOfWord,regSP));
					GenerateMonadic(op_pop,0,makereg(ta->preg[nn]& 0x7fff));
				}
			}
			//GenerateTriadic(op_add,0,makereg(regSP),makereg(regZero),make_immed(cn * sizeOfWord));
		}
	}
}

// push the operand expression onto the stack.
// Structure variables are represented as an address in a register and arrive
// here as autocon nodes if on the stack. If the variable size is greater than
// 8 we assume a structure variable and we assume we have the address in a reg.
// Returns: number of stack words pushed.
//
static int GeneratePushParameter(ENODE *ep, int regno)
{    
	AMODE *ap;
	int nn = 0;
	int sz = sizeOfWord;
	
	if (ep->tp) {
		if (ep->tp->IsFloatType())
			ap = GenerateExpression(ep,F_REG,sizeOfFP);
		else
			ap = GenerateExpression(ep,F_REG|F_IMM0,sizeOfWord);
	}
	else if (ep->etype==bt_quad)
		ap = GenerateExpression(ep,F_REG,sz);
	else if (ep->etype==bt_double)
		ap = GenerateExpression(ep,F_REG,sz);
	else if (ep->etype==bt_triple)
		ap = GenerateExpression(ep,F_REG,sz);
	else if (ep->etype==bt_float)
		ap = GenerateExpression(ep,F_REG,sz);
	else
		ap = GenerateExpression(ep,F_REG|F_IMM0,sz);
	switch(ap->mode) {
    case am_reg:
    case am_fpreg:
    case am_immed:
/*
        nn = round8(ep->esize); 
        if (nn > 8) {// && (ep->tp->type==bt_struct || ep->tp->type==bt_union)) {           // structure or array ?
            ap2 = GetTempRegister();
            GenerateTriadic(op_subui,0,makereg(regSP),makereg(regSP),make_immed(nn));
            GenerateDiadic(op_mov, 0, ap2, makereg(regSP));
            GenerateMonadic(op_push,0,make_immed(ep->esize));
            GenerateMonadic(op_push,0,ap);
            GenerateMonadic(op_push,0,ap2);
            GenerateMonadic(op_bsr,0,make_string("memcpy_"));
            GenerateTriadic(op_addui,0,makereg(regSP),makereg(regSP),make_immed(24));
          	GenerateMonadic(op_push,0,ap2);
            ReleaseTempReg(ap2);
            nn = nn >> 3;
        }
        else {
*/
			if (regno) {
				//GenerateMonadic(op_hint,0,make_immed(1));
				if (ap->mode==am_immed) {
					GenerateTriadic(op_mov,0,makereg(regno & 0x7fff), makereg(regZero), ap);
					if (regno & 0x8000) {
						GenerateMonadic(op_push,0,makereg(regno & 0x7fff));
						//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(sizeOfWord));
						nn = sz;
					}
				}
				else {
					GenerateDiadic(op_mov,0,makereg(regno & 0x7fff), ap);
					if (regno & 0x8000) {
						GenerateMonadic(op_push,0,makereg(regno & 0x7fff));
						//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(sizeOfWord));
						nn = 8;
					}
				}
			}
			else {
				if (ap->mode==am_immed) {	// must have been a zero
					//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(sizeOfWord));
					//GenerateDiadic(op_sto,0,makereg(regZero),make_indexed(0,regSP));
					GenerateMonadic(op_push,0,makereg(regZero));
					nn = 1;
				}
				else {
					if (ap->isFloat) {
						GenerateMonadic(op_push,ap->FloatSize,ap);
						nn = sz;
					}
					else {
						//GenerateTriadic(op_sub,0,makereg(regSP),makereg(regZero),make_immed(sizeOfWord));
						//GenerateDiadic(op_sto,0,ap,make_indexed(0,regSP));
          				GenerateMonadic(op_push,0,ap);
						nn = 1;
					}
				}
			}
//        }
    	break;
    }
//	ReleaseTempReg(ap);
	return nn;
}

// push entire parameter list onto stack
//
static int GeneratePushParameterList(SYM *sym, ENODE *plist)
{
	TypeArray *ta = nullptr;
	int i,sum;

	sum = 0;
	if (sym)
		ta = sym->GetProtoTypes();

	for(i = 0; plist != NULL; i++ )
    {
		sum += GeneratePushParameter(plist->p[0],ta ? ta->preg[ta->length - i - 1] : 0);
		plist = plist->p[1];
    }
	if (ta)
		delete ta;
    return sum;
}

AMODE *GenerateFunctionCall(ENODE *node, int flags)
{ 
	AMODE *ap;
	SYM *sym;
	SYM *o_fn;
    int             i;
	int sp = 0;
	int fsp = 0;
	TypeArray *ta = nullptr;
	int64_t mask,fmask;

	sym = nullptr;

	// Call the function
	if( node->p[0]->nodetype == en_nacon || node->p[0]->nodetype == en_cnacon ) {
 		sym = gsearch(*node->p[0]->sp);
        i = 0;
		SaveTemporaries(sym, &sp, &fsp);
  /*
    	if ((sym->tp->GetBtp()->type==bt_struct || sym->tp->GetBtp()->type==bt_union) && sym->tp->GetBtp()->size > 8) {
            nn = tmpAlloc(sym->tp->GetBtp()->size) + lc_auto + round8(sym->tp->GetBtp()->size);
            GenerateMonadic(op_pea,0,make_indexed(-nn,regBP));
            i = 1;
        }
*/
		SaveRegisterParameters(sym);
        i = i + GeneratePushParameterList(sym,node->p[1]);
//		ReleaseTempRegister(ap);
		if (sym && sym->IsInline) {
			o_fn = currentFn;
			mask = save_mask;
			fmask = fpsave_mask;
			currentFn = sym;
			GenerateFunction(sym);
			currentFn = o_fn;
			fpsave_mask = fmask;
			save_mask = mask;
		}
		else {
			//GenerateTriadic(op_mov,0,makereg(regLR),makereg(regPC),make_immed(2));
			GenerateTriadic(op_jsr,0,makereg(regLR),makereg(regZero),make_offset(node->p[0]));
		}
	}
    else
    {
        i = 0;
    /*
    	if ((node->p[0]->tp->GetBtp()->type==bt_struct || node->p[0]->tp->GetBtp()->type==bt_union) && node->p[0]->tp->GetBtp()->size > 8) {
            nn = tmpAlloc(node->p[0]->tp->GetBtp()->size) + lc_auto + round8(node->p[0]->tp->GetBtp()->size);
            GenerateMonadic(op_pea,0,make_indexed(-nn,regBP));
            i = 1;
        }
     */
		ap = GenerateExpression(node->p[0],F_REG,sizeOfWord);
		if (ap->offset)
			sym = ap->offset->sym;
		SaveTemporaries(sym, &sp, &fsp);
		SaveRegisterParameters(sym);
        i = i + GeneratePushParameterList(sym,node->p[1]);
		ap->mode = am_ind;
		ap->offset = 0;
		if (sym && sym->IsInline) {
			o_fn = currentFn;
			mask = save_mask;
			fmask = fpsave_mask;
			currentFn = sym;
			GenerateFunction(sym);
			currentFn = o_fn;
			fpsave_mask = fmask;
			save_mask = mask;
		}
		else {
			//GenerateTriadic(op_mov,0,makereg(regLR),makereg(regPC),make_immed(2));
			GenerateDiadic(op_jsr,0,makereg(regLR),ap);
		}
		ReleaseTempRegister(ap);
    }
	// Pop parameters off the stack
	if (i!=0) {
		if (sym) {
			if (!sym->IsPascal) {
				if (i*sizeOfWord < 16)
					GenerateDiadic(op_inc,0,makereg(regSP),make_immed(i * sizeOfWord));
				else
					GenerateTriadic(op_add,0,makereg(regSP),makereg(regZero),make_immed(i * sizeOfWord));
			}
		}
		else {
			if (i*sizeOfWord < 16)
				GenerateDiadic(op_inc,0,makereg(regSP),make_immed(i * sizeOfWord));
			else
				GenerateTriadic(op_add,0,makereg(regSP),makereg(regZero),make_immed(i * sizeOfWord));
		}
	}
	RestoreRegisterParameters(sym);
	RestoreTemporaries(sym, sp, fsp);
	if (sym && sym->tp && sym->tp->GetBtp()->IsFloatType() && (flags & F_FPREG))
		return (makereg(1));
	return (makereg(1));
}

void GenLdi(AMODE *ap1, AMODE *ap2)
{
	GenerateTriadic(op_mov,0,ap1,makereg(0),ap2);
  return;
}

