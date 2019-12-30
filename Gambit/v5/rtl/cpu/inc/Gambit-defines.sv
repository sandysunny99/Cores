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
`define TRUE			1'b1
`define FALSE			1'b0
`define VAL				1'b1
`define INV				1'b0
`define HIGH			1'b1
`define LOW				1'b0

`define CSR				7'h01
`define ADD_3R		7'h04
`define ADD_RI22	7'h14
`define ADD_RI35	7'h24
`define ADDIS			7'h23
`define ASL_3R		7'h0C
`define ASR_3R		7'h2D
`define SUB_3R		7'h05
`define SUB_RI22	7'h15
`define SUB_RI35	7'h25
`define CMP_3R		7'h06
`define CMP_RI22	7'h16
`define CMP_RI35	7'h26
`define CMPU_3R		7'h07
`define CMPU_RI22	7'h17
`define CMPU_RI35	7'h27
`define MUL_3R		7'h0E
`define MUL_RI22	7'h1E
`define MUL_RI35	7'h2E
`define PERM_3R		7'h20
`define LSR_3R		7'h0D
`define BRANCH0		7'h40
`define BEQ					2'd0
`define BNE					2'd1
`define BGT					2'd2
`define BLT					2'd3
`define BRANCH1		7'h41
`define BGE					2'd0
`define BLE					2'd1
`define BRA					2'd2
`define JAL				7'h42
`define RETGRP		7'h44
`define RET					2'd0
`define RTI					2'd1
`define WAIGRP		7'h02
`define PFI				9'h002
`define WAI				9'h102
`define STPGRP		7'h43
`define STP					2'd0
`define NOP					2'd1
`define MRK					2'd2
`define ROL_3R		7'h1C
`define AND_3R		7'h08
`define AND_RI22	7'h18
`define AND_RI35	7'h28
`define ANDIS			7'h22
`define BIT_3R		7'h55
`define BIT_RI22	7'h65
`define BIT_RI35	7'h75
`define BRKGRP		7'h00
`define RST					3'd3
`define NMI					3'd2
`define IRQ					3'd1
`define BRK					3'd0
`define ROR_3R		7'h1D
`define OR_3R			7'h09
`define OR_RI22		7'h19
`define OR_RI35		7'h29
`define ORIS			7'h2C
`define JAL_RN		7'h48
`define EOR_3R		7'h0A
`define EOR_RI22	7'h1A
`define EOR_RI35	7'h2A
`define LD_D8			7'h50
`define LD_D22		7'h60
`define LD_D35		7'h70
`define LDB_D8		7'h51
`define LDB_D22		7'h61
`define LDB_D35		7'h71
`define ST_D8			7'h58
`define ST_D22		7'h68
`define ST_D35		7'h78
`define STB_D8		7'h59
`define STB_D22		7'h69
`define STB_D35		7'h79
`define REX				7'h6A
`define CACHE			7'h7A
`define SEQ_3R		7'h4C
`define BNE_3R		7'h5C
`define SLT_3R		7'h4D
`define SLE_3R		7'h5D
`define SLTU_3R		7'h6D
`define SLEU_3R		7'h7D
`define MTx				7'h4A
`define MFx				7'h5A

`define NOP_INSN	52'hC3

`define UO_ADD		6'd0
`define UO_ADDu		6'd1
`define UO_SUB		6'd2
`define UO_SUBu		6'd3
`define UO_ANDu		6'd4
`define UO_ORu		6'd5
`define UO_EORu		6'd6
`define UO_LD			6'd7
`define UO_LDu		6'd8
`define UO_LDB		6'd9
`define UO_LDBu		6'd10
`define UO_ST			6'd11
`define UO_STB		6'd12
`define UO_ASLu		6'd13
`define UO_ROLu		6'd14
`define UO_LSRu		6'd15
`define UO_RORu		6'd16
`define UO_BRA		6'd17
`define UO_BEQ		6'd18
`define UO_BNE		6'd19
`define UO_BMI		6'd20
`define UO_BPL		6'd21
`define UO_BCS		6'd22
`define UO_BCC		6'd23
`define UO_BVS		6'd24
`define UO_BVC		6'd25
`define UO_SEP		6'd26
`define UO_REP		6'd27
`define UO_JMP		6'd28
`define UO_STP		6'd29
`define UO_WAI		6'd30
`define UO_CAUSE	6'd31
`define UO_BUC		6'd32
`define UO_BUS		6'd33
`define UO_JSI		6'd34
`define UO_NOP		6'd35

`define UOF_I			7'b0010000

`define OPCODE		6:0
`define RT				11:7
`define RA				16:12
`define RB				21:17

`define DRAMSLOT_AVAIL	3'b000
`define DRAMSLOT_BUSY		3'b001
`define DRAMSLOT_RMW		3'b010
`define DRAMSLOT_RMW2		3'b011
`define DRAMSLOT_REQBUS	3'b101
`define DRAMSLOT_HASBUS	3'b110
`define DRAMREQ_READY		3'b111


`define IB_CMP		0
`define IB_MEMNDX	1
`define IB_ALU0		12
`define IB_BT			13
`define IB_ALU		14
`define IB_FC			15
`define IB_LOAD		16
`define IB_STORE	17
`define IB_MEMSZ	18
`define IB_MEM		19
`define IB_JAL		20
`define IB_BR			21
`define IB_RFW		22
`define IB_CONST	74:23
`define IBTOP		75

`define CSR_CR0     12'h000
`define CSR_HARTID  12'h001
`define CSR_TICK    12'h002
`define CSR_PCR     12'h003
`define CSR_PMR			12'h005
`define CSR_CAUSE   12'h006
`define CSR_BADADR  12'h007
`define CSR_PCR2    12'h008
`define CSR_SCRATCH 12'h009
`define CSR_WBRCD	12'h00A
`define CSR_BADINST	12'h00B
`define CSR_SEMA    12'h00C
`define CSR_KEYS		12'h00E
`define CSR_TCB			12'h010
`define CSR_FSTAT   12'h014
`define CSR_DBAD0   12'h018
`define CSR_DBAD1   12'h019
`define CSR_DBAD2   12'h01A
`define CSR_DBAD3   12'h01B
`define CSR_DBCTRL  12'h01C
`define CSR_DBSTAT  12'h01D
`define CSR_CAS     12'h02C
`define CSR_TVEC    12'b0000000110???
`define CSR_IM_STACK	12'h040
`define CSR_DOI_STACK	12'h041
`define CSR_PL_STACKL	12'h042
`define CSR_PL_STACKH	12'h043
`define CSR_STATUS 	12'h044
`define CSR_BRS_STACK	12'h046
`define CSR_IPC0    12'h048
`define CSR_IPC1    12'h049
`define CSR_IPC2    12'h04A
`define CSR_IPC3    12'h04B
`define CSR_IPC4    12'h04C
`define CSR_IPC5    12'h04D
`define CSR_IPC6    12'h04E
`define CSR_IPC7    12'h04F
`define CSR_GOLEX0	12'h050
`define CSR_GOLEX1	12'h051
`define CSR_GOLEX2	12'h052
`define CSR_GOLEX3	12'h053
`define CSR_GOLEXVP	12'h054
`define CSR_CODEBUF 12'b0000010??????
`define CSR_TB			12'h0C0
`define CSR_CBL			12'h0C1
`define CSR_CBU			12'h0C2
`define CSR_RO			12'h0C3
`define CSR_DBL			12'h0C4
`define CSR_DBU			12'h0C5
`define CSR_SBL			12'h0C6
`define CSR_SBU			12'h0C7
`define CSR_ENU			12'h0C8
`define CSR_PREGS		12'h0F0
`define CSR_Q_CTR		12'h3C0
`define CSR_BM_CTR	12'h3C1
`define CSR_ICL_CTR	12'h3C2
`define CSR_IRQ_CTR	12'h3C3
`define CSR_BR_CTR	12'h3C4
`define CSR_TIME_FRAC		12'hFE0
`define CSR_TIME_SECS		12'hFE1
`define CSR_INFO    12'hFF?
