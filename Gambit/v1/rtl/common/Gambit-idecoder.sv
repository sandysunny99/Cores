// ============================================================================
//        __
//   \\__/ o\    (C) 2019  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
`include ".\Gambit-config.sv"
`include ".\Gambit-defines.sv"

module idecoder(instr,predict_taken,bus);
input [23:0] instr;
input predict_taken;
output reg [`IBTOP:0] bus;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
// Memory access sizes
parameter byt = 3'd0;
parameter word = 3'd1;

function IsAlu;
input [23:0] isn;
case(isn[21:16])
`UO_ADD,`UO_SUB,
`UO_ADDu,`UO_SUBu,
`UO_ANDu,`UO_ORu,`UO_EORu,
`UO_ASLu,`UO_LSRu,`UO_RORu,`UO_ROLu,
`UO_REP,`UO_SEP:
	IsAlu = TRUE;
default:	IsAlu = FALSE;
endcase
endfunction

function IsMem;
input [23:0] isn;
case(isn[21:16])
`UO_LD,`UO_LDB,`UO_LDu,`UO_LDBu,
`UO_ST,`UO_STB:
	IsMem = TRUE;
default:
	IsMem = FALSE;
endcase
endfunction

function IsFcu;
input [23:0] isn;
case(isn[21:16])
`UO_BEQ,`UO_BNE,`UO_BCS,`UO_BCC,`UO_BVS,`UO_BVC,`UO_BMI,`UO_BPL,`UO_BRA,
`UO_JMP:
	IsFcu = TRUE;
default:	IsFcu = FALSE;
endcase
endfunction

function IsCmp;
input [23:0] isn;
case(isn[21:16])
`UO_SUBu:	IsCmp = isn[3:0]==4'h0;
default:	IsCmp = FALSE;
endcase
endfunction

function IsLoad;
input [23:0] isn;
case(isn[21:16])
`UO_LDB,`UO_LD,`UO_LDBu,`UO_LDu:
	IsLoad = TRUE;
default:
	IsLoad = FALSE;
endcase
endfunction

function IsStore;
input [23:0] isn;
case(isn[21:16])
`UO_STB,`UO_ST:
	IsStore = TRUE;
default:
	IsStore = FALSE;
endcase
endfunction


function [2:0] MemSize;
input [23:0] isn;
casez(isn[21:16])
`UO_LDB,`UO_LDBu,`UO_STB:	MemSize = byt;
default:	MemSize = word;
endcase
endfunction

function IsJmp;
input [23:0] isn;
IsJmp = isn[21:0]==`UO_JMP;
endfunction

// Really IsPredictableBranch
// Does not include BccR's
function IsBranch;
input [23:0] isn;
case(isn[23:16])
`UO_BEQ,`UO_BNE,`UO_BCS,`UO_BCC,`UO_BVS,`UO_BVC,`UO_BMI,`UO_BPL,`UO_BRA:
	IsBranch = TRUE;
default:
	IsBranch = FALSE;
endcase
endfunction

function IsRFW;
input [23:0] isn;
case(isn[21:16])
`UO_LDB,`UO_LDBu,`UO_LD,`UO_LDu,
`UO_ADD,`UO_ADDu,`UO_SUB,`UO_SUBu,
`UO_ANDu,`UO_ORu,`UO_EORu,
`UO_ASLu,`UO_LSRu,`UO_ROLu,`UO_RORu:
	IsRFW = TRUE;
default:
	IsRFW = FALSE;
endcase
endfunction

function fnNeedSr;
input [23:0] isn;
fnNeedSr = TRUE;
/*
case(isn[23:16])
`UO_STB,`UO_STBW:
	fnNeedSr = isn[5:3]==`UO_SR;
`UO_ADCB,`UO_SBCB,`UO_ROLB,`UO_RORB:	// carry input
	fnNeedSr = TRUE;
`UO_BEQ,`UO_BNE,`UO_BCS,`UO_BCC,`UO_BVS,`UO_BVC,`UO_BMI,`UO_BPL:
	fnNeedSr = TRUE;
default:
	fnNeedSr = FALSE;
endcase
*/
endfunction

always @*
begin
	bus <= 167'h0;
	bus[`IB_CMP] <= IsCmp(instr);
//	bus[`IB_CONST] <= {{58{instr[39]}},instr[39:35],instr[32:16]};
//	bus[`IB_RT]		 <= fnRd(instr,ven,vl,thrd) | {thrd,7'b0};
//	bus[`IB_RC]		 <= fnRc(instr,ven,thrd) | {thrd,7'b0};
//	bus[`IB_RA]		 <= fnRa(instr,ven,vl,thrd) | {thrd,7'b0};
	bus[`IB_SRC1]		 <= instr[7:4];
	bus[`IB_SRC2]		 <= instr[3:0];
	bus[`IB_DST]		 <= instr[11:8];
//	bus[`IB_IMM]	 <= HasConst(instr);
	// IB_BT is now used to indicate when to update the branch target buffer.
	// This occurs when one of the instructions with an unknown or calculated
	// target is present.
	bus[`IB_BT]		 <= 1'b0;
	bus[`IB_ALU]   <= IsAlu(instr);
	bus[`IB_FC]		 <= IsFcu(instr);
//	bus[`IB_CANEX] <= fnCanException(instr);
	bus[`IB_LOAD]	 <= IsLoad(instr);
	bus[`IB_STORE]	<= IsStore(instr);
	bus[`IB_MEMSZ]  <= MemSize(instr);
	bus[`IB_MEM]		<= IsMem(instr);
	bus[`IB_JMP]		<= IsJmp(instr);
	bus[`IB_BR]			<= IsBranch(instr);
	bus[`IB_RFW]		<= IsRFW(instr);
	bus[`IB_NEED_SR]	<= fnNeedSr(instr);
end

endmodule

