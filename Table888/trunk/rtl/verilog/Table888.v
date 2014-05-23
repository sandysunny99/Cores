// ============================================================================
// Table888.v
//        __
//   \\__/ o\    (C) 2014  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
`define TRUE	1'b1
`define FALSE	1'b0

`define RST_VECT	32'hFFFFFFF0
`define NMI_VECT	32'hFFFFFFE0
`define IRQ_VECT	32'hFFFFFFD0
`define DBG_VECT	32'hFFFFFFC0
`define ALN_VECT	32'hFFFFFFB0

`define BRK		8'h00
`define R		8'h01
`define NEG			8'h05
`define COM			8'h06
`define NOT			8'h07
`define SXB			8'h08
`define SXC			8'h09
`define SXH			8'h0A
`define SEI			8'h30
`define CLI			8'h31
`define PHP			8'h32
`define PLP			8'h33
`define ICON		8'h34
`define ICOFF		8'h35
`define RTI			8'h40
`define RR		8'h02
`define ADD			8'h04
`define SUB			8'h05
`define CMP			8'h06
`define MUL			8'h07
`define DIV			8'h08
`define MOD			8'h09
`define ADDU		8'h14
`define SUBU		8'h15
`define MULU		8'h17
`define DIVU		8'h18
`define MODU		8'h19
`define AND			8'h20
`define OR			8'h21
`define EOR			8'h22
`define ANDN		8'h23
`define NAND		8'h24
`define NOR			8'h25
`define ENOR		8'h26
`define ORN			8'h27
`define SHLI		8'h50
`define ROLI		8'h51
`define SHRI		8'h52
`define RORI		8'h53
`define ASRI		8'h54
`define SHL			8'h40
`define ROL			8'h41
`define SHR			8'h42
`define ROR			8'h43
`define ASR			8'h44
`define ADDI	8'h04
`define SUBI	8'h05
`define CMPI	8'h06
`define MULI	8'h07
`define DIVI	8'h08
`define MODI	8'h09
`define ANDI	8'h0C
`define ORI		8'h0D
`define EORI	8'h0F
`define ADDUI	8'h14
`define SUBUI	8'h15
`define LDI		8'h16
`define MULUI	8'h17
`define DIVUI	8'h18
`define MODUI	8'h19
`define BEQ		8'h40
`define BNE		8'h41
`define BVS		8'h42
`define BVC		8'h43
`define BMI		8'h44
`define BPL		8'h45
`define BRA		8'h46
`define BRN		8'h47
`define BGT		8'h48
`define BLE		8'h49
`define BGE		8'h4A
`define BLT		8'h4B
`define BHI		8'h4C
`define BLS		8'h4D
`define BHS		8'h4E
`define BLO		8'h4F
`define JMP		8'h50
`define JSR		8'h51
`define JMP_IX	8'h52
`define JSR_IX	8'h53
`define JMP_DRN	8'h54
`define JSR_DRN	8'h55
`define BRZ		8'h58
`define BRNZ	8'h59
`define DBNZ	8'h5A
`define RTS		8'h60
`define LB		8'h80
`define LBU		8'h81
`define LC		8'h82
`define LCU		8'h83
`define LH		8'h84
`define LHU		8'h85
`define LW		8'h86
`define LBX		8'h88
`define LBUX	8'h89
`define LCX		8'h8A
`define LCUX	8'h8B
`define LHX		8'h8C
`define LHUX	8'h8D
`define LWX		8'h8E
`define SB		8'hA0
`define SC		8'hA1
`define SH		8'hA2
`define SW		8'hA3
`define PUSH	8'hA6
`define POP		8'hA7
`define SBX		8'hA8
`define SCX		8'hA9
`define SHX		8'hAA
`define SWX		8'hAB

`define NOP		8'hEA

`define IMM1	8'hFD
`define IMM2	8'hFE

`define STW_NONE	4'd0
`define STW_SR	4'd1
`define STW_PC	4'd2
`define STW_A	4'd3
`define STW_B	4'd4
`define STW_C	4'd5

module Table888(rst_i, clk_i, nmi_i, irq_i, bte_o, cti_o, bl_o, cyc_o, stb_o, ack_i, sel_o, we_o, adr_o, dat_i, dat_o);
input rst_i;
input clk_i;
input nmi_i;
input irq_i;
output reg [1:0] bte_o;
output reg [2:0] cti_o;
output reg [5:0] bl_o;
output reg cyc_o;
output reg stb_o;
input ack_i;
output reg [3:0] sel_o;
output reg we_o;
output reg [31:0] adr_o;
input [31:0] dat_i;
output reg [31:0] dat_o;
// - - - - - - - - - - - - - - - - - -
// Machine states
// - - - - - - - - - - - - - - - - - -
parameter RESET = 6'd0;
parameter IFETCH = 6'd1;
parameter DECODE = 6'd2;
parameter EXECUTE = 6'd3;
parameter LOAD1 = 6'd4;
parameter LOAD2 = 6'd5;
parameter LOAD3 = 6'd6;
parameter LOAD4 = 6'd7;
parameter RTS1 = 6'd8;
parameter STORE1 = 6'd9;
parameter STORE2 = 6'd10;
parameter STORE3 = 6'd11;
parameter STORE4 = 6'd12;
parameter MULDIV = 6'd13;
parameter MULT1 = 6'd14;
parameter MULT2 = 6'd15;
parameter MULT3 = 6'd16;
parameter DIV = 6'd17;
parameter FIX_SIGN = 6'd18;
parameter MD_RES = 6'd19;
parameter ICACHE1 = 6'd20;
parameter ICACHE2 = 6'd21;
parameter IBUF1 = 6'd24;
parameter IBUF2 = 6'd25;
parameter IBUF3 = 6'd26;
// - - - - - - - - - - - - - - - - - -
// codes for load/store sizes
// - - - - - - - - - - - - - - - - - -
parameter word = 3'b110;
parameter half = 3'b101;
parameter uhalf = 3'b100;
parameter char = 3'b011;
parameter uchar = 3'b010;
parameter byt = 3'b001;
parameter ubyte = 3'b000;

reg [5:0] state;
reg [3:0] store_what;
reg [39:0] ir;
wire [39:0] insn;
wire [7:0] opcode = ir[7:0];
wire [7:0] func = ir[39:32];
reg [31:0] pc;
reg [31:0] ibufadr;
wire ibufmiss = ibufadr != pc;
reg [39:0] ibuf;	// instruction buffer
reg isInsnCacheLoad,isCacheReset;
reg nmi_edge,nmi1;
reg hwi;			// hardware interrupt indicator
reg im;				// irq interrupt mask bit
wire [31:0] sr = {23'd0,im,8'h00};
reg [63:0] regfile [255:0];
reg [63:0] sp;	// stack pointer
wire [63:0] sp_inc = sp + 64'd8;
wire [63:0] sp_dec = sp - 64'd8;
reg gie;						// global interrupt enable
wire [7:0] Ra = ir[15:8];
wire [7:0] Rb = ir[23:16];
wire [7:0] Rc = ir[31:24];
reg [7:0] Rt;
reg wrrf;
reg [31:0] wadr, radr;
reg icacheOn;
wire uncachedArea = 1'b0;
wire ihit;
reg [2:0] ld_size, st_size;
reg isRTS,isPUSH,isPOP,isIMM1,isIMM2,isCMPI;
reg isJSR,isJSRix,isJSRdrn,isJMPix,isBRK,isPLP,isRTI;
reg isShifti;
wire hasIMM = isIMM1|isIMM2;
reg [63:0] rfoa,rfob,rfoc;
reg [64:0] res;			// result bus
reg [63:0] a,b,c;		// operand holding registers
reg [63:0] imm;
reg [63:0] immbuf;

// - - - - - - - - - - - - - - - - - -
// Convenience Functions
// - - - - - - - - - - - - - - - - - -

function [31:0] pc_inc;
input [31:0] pc;
begin
	case(pc[3:0])
	4'd0:	pc_inc = {pc[31:4],4'd5};
	4'd5:	pc_inc = {pc[31:4],4'd10};
	4'd10:	pc_inc = {pc[31:4],4'd0} + 32'd16;
	default:	pc_inc = `ALN_VECT;
	endcase
end
endfunction

// Overflow:
// Add: the signs of the inputs are the same, and the sign of the
// sum is different
// Sub: the signs of the inputs are different, and the sign of
// the sum is the same as B
function overflow;
input op;
input a;
input b;
input s;
begin
overflow = (op ^ s ^ b) & (~op ^ a ^ b);
end
endfunction

// - - - - - - - - - - - - - - - - - -
// Instanced Modules
// - - - - - - - - - - - - - - - - - -

icache_tagram u1 (
	.wclk(clk_i),
	.wr((ack_i & isInsnCacheLoad)|isCacheReset),
	.wa(adr_o),
	.v(!isCacheReset),
	.rclk(~clk_i),
	.pc(pc),
	.hit(ihit)
);

wire [1:0] debug_bits;
icache_ram u2 (
	.wclk(clk_i),
	.wr(ack_i & isInsnCacheLoad),
	.wa(adr_o[12:0]),
	.i(dat_i),
	.rclk(~clk_i),
	.pc(pc[12:0]),
	.insn(insn),
	.debug_bits(debug_bits)
);

// - - - - - - - - - - - - - - - - - -
// Combinational logic follows.
// - - - - - - - - - - - - - - - - - -

// register read ports
always @*
case(Ra)
8'h00:	rfoa <= 64'd0;
8'hFE:	rfoa <= pc;
8'hFF:	rfoa <= sp;
default:	rfoa <= regfile[Ra];
endcase
always @*
case(Rb)
8'h00:	rfob <= 64'd0;
8'hFE:	rfob <= pc;
8'hFF:	rfob <= sp;
default:	rfob <= regfile[Rb];
endcase
always @*
case(Rc)
8'h00:	rfoc <= 64'd0;
8'hFE:	rfoc <= pc;
8'hFF:	rfoc <= sp;
default:	rfoc <= regfile[Rc];
endcase

// Data input multiplexers
reg [7:0] dat8;
always @(dat_i or radr)
case(radr[1:0])
2'b00:	dat8 <= dat_i[7:0];
2'b01:	dat8 <= dat_i[15:8];
2'b10:	dat8 <= dat_i[23:16];
2'b11:	dat8 <= dat_i[31:24];
endcase
reg [15:0] dat16;
always @(dat_i or radr)
case(radr[1])
1'b0:	dat16 <= dat_i[15:0];
1'b1:	dat16 <= dat_i[31:16];
endcase
wire [31:0] dat32 = dat_i;


// Generate result flags for compare instructions
wire [64:0] cmp_res = a - (isCMPI ? imm : b);
reg nf,vf,cf,zf;
always @(cmp_res or a or b or imm or isCMPI)
begin
	cf <= cmp_res[64];
	nf <= cmp_res[63];
	vf <= overflow(1,a[63],isCMPI ? imm[63] : b[63], cmp_res[63]);
	zf <= cmp_res[63:0]==64'd0;
end

// Evaluate branches
// 
reg take_branch;
always @(a or opcode)
case(opcode)
`BRZ:	take_branch <= a==64'd0;
`BRNZ:	take_branch <= a!=64'd0;
`DBNZ:	take_branch <= a!=64'd0;
`BEQ:	take_branch <= a[1];
`BNE:	take_branch <= !a[1];
`BVS:	take_branch <= a[62];
`BVC:	take_branch <= !a[62];
`BMI:	take_branch <= a[63];
`BPL:	take_branch <= !a[63];
`BRA:	take_branch <= `TRUE;
`BRN:	take_branch <= `FALSE;
`BHI:	take_branch <= a[0] & !a[1];
`BHS:	take_branch <= a[0];
`BLO:	take_branch <= !a[0];
`BLS:	take_branch <= !a[0] | a[1];
`BGT:	take_branch <= (a[63] & a[62] & !a[1]) | (!a[63] & !a[62] & !a[1]);
`BGE:	take_branch <= (a[63] & a[62])|(!a[63] & !a[62]);
`BLT:	take_branch <= (a[63] & !a[62])|(!a[63] & a[62]);
`BLE:	take_branch <= a[1] | (a[63] & !a[62])|(!a[63] & a[62]);
default:	take_branch <= `FALSE;
endcase

// Shifts
wire [5:0] shamt = isShifti ? Rb[5:0] : b[5:0];
wire [127:0] shlo = {64'd0,a} << shamt;
wire [127:0] shro = {a,64'd0} >> shamt;
wire signed [63:0] as = a;
wire signed [63:0] asro = as >> shamt;

// Multiply / Divide / Modulus
reg [6:0] cnt;
reg res_sgn;
reg [63:0] aa, bb;
reg [63:0] q, r;
wire [63:0] pa = a[63] ? -a : a;
wire [127:0] p1 = aa * bb;
reg [127:0] p;
wire [63:0] diff = r - bb;

// For scaled indexed address mode
wire [63:0] b_scaled = b << ir[33:32];

// - - - - - - - - - - - - - - - - - -
// Clocked logic follows.
// - - - - - - - - - - - - - - - - - -

always @(posedge clk_i)
if (rst_i) begin
	pc <= 32'hFFFFFFF0;
	ibufadr <= 32'h00000000;
	icacheOn <= `FALSE;
	gie <= `FALSE;
	nmi1 <= `FALSE;
	nmi_edge <= `FALSE;
	isInsnCacheLoad <= `FALSE;
	isCacheReset <= `TRUE;
	wb_nack();
	state <= RESET;
	store_what <= `STW_NONE;
end
else begin
if (nmi_i & !nmi1)
	nmi_edge <= `TRUE;
wrrf <= `FALSE;
case(state)
RESET:
	begin
		adr_o[3:2] <= 2'b11;		// The tagram checks for this
		adr_o <= adr_o + 32'd16;
		if (adr_o[12:6]==7'h7F) begin
			isCacheReset <= `FALSE;
			next_state(IFETCH);
		end
	end

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// IFETCH Stage
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
IFETCH:
	begin
		hwi <= `FALSE;
		next_state(DECODE);
		if (nmi_edge & gie & ~hasIMM) begin
			ir[7:0] <= `BRK;
			ir[39:8] <= `NMI_VECT;
			nmi_edge <= 1'b0;
			hwi <= `TRUE;
		end
		else if (irq_i & gie & !im & ~hasIMM) begin
			ir[7:0] <= `BRK;
			ir[39:8] <= `IRQ_VECT;
			hwi <= `TRUE;
		end
		else if (!ihit & !uncachedArea & icacheOn)
			next_state(ICACHE1);
		else if (ibufmiss & (uncachedArea | !icacheOn))
			next_state(IBUF1);
		else if (icacheOn & !uncachedArea) begin
			if (debug_bits[0]) begin
				ir[7:0] <= `BRK;
				ir[39:8] <= `DBG_VECT;
				hwi <= `TRUE;
			end
			else
				ir <= insn;
		end
		else
			ir <= ibuf;
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction cache load machine states.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ICACHE1:
	begin
		isInsnCacheLoad <= `TRUE;
		wb_burst(6'd3,{pc[31:4],4'h0});
		next_state(ICACHE2);
	end
ICACHE2:
	if (ack_i) begin
		if (adr_o[3:2]==2'b10)
			cti_o <= 3'b111;
		if (adr_o[3:2]==2'b11) begin
			isInsnCacheLoad <= `FALSE;
			wb_nack();
			state <= IFETCH;			// return to where we came from
		end
		adr_o[3:2] <= adr_o[3:2] + 2'd1;
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction buffer load machine states.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

IBUF1:
	begin
		wb_burst(6'd1,{pc[31:2],2'h0});
		next_state(IBUF2);
	end
IBUF2:
	begin
		if (ack_i) begin
			cti_o <= 3'b111;
			adr_o <= adr_o + 32'd4;
			case(pc[1:0])
			2'b00:	ibuf[31:0] <= dat_i;
			2'b01:	ibuf[23:0] <= dat_i[31:8];
			2'b10:	ibuf[15:0] <= dat_i[31:16];
			2'b11:	ibuf[7:0] <= dat_i[31:24];
			endcase
			next_state(IBUF3);
		end
	end
IBUF3:
	begin
		if (ack_i) begin
			wb_nack();
			ibufadr <= pc;
			case(pc[1:0])
			2'b00:	ibuf[39:32] <= dat_i[7:0];
			2'b01:	ibuf[39:24] <= dat_i[15:0];
			2'b10:	ibuf[39:16] <= dat_i[23:0];
			2'b11:	ibuf[39:8] <= dat_i;
			endcase
			next_state(IFETCH);
		end
	end

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// DECODE Stage
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
DECODE:
	begin
		next_state(EXECUTE);
		// Default a number of signals. These defaults may be overridden later.
		pc <= pc_inc(pc);
		isIMM1 <= `FALSE;
		isIMM2 <= `FALSE;
		isCMPI <= `FALSE;
		isBRK <= `FALSE;
		isJSR <= `FALSE;
		isJSRix <= `FALSE;
		isJMPix <= `FALSE;
		isRTS <= `FALSE;
		isPOP <= `FALSE;
		isPUSH <= `FALSE;
		isPLP <= `FALSE;
		isRTI <= `FALSE;
		isShifti = func==`SHLI || func==`SHRI || func==`ROLI || func==`RORI || func==`ASRI;
		a <= rfoa;
		b <= rfob;
		c <= rfoc;
		ld_size <= word;
		st_size <= word;
		
		// Set the target register
		case(opcode)
		`R:		Rt <= ir[23:16];
		`RR:	Rt <= ir[31:24];
		`LDI:	Rt <= ir[15:8];
		`DBNZ:	Rt <= ir[15:8];
		`ADDI,`ADDUI,`SUBI,`SUBUI,`CMPI,`MULI,`MULUI,`DIVI,`DIVUI,`MODI,`MODUI,
		`ANDI,`ORI,`EORI:
			Rt <= ir[23:16];
		`LB,`LBU,`LC,`LCU,`LH,`LHU,`LW:
			Rt <= ir[23:16];
		`LBX,`LBUX,`LCX,`LCUX,`LHX,`LHUX,`LWX:
			Rt <= ir[31:24];
		default:
			Rt <= 8'h00;
		endcase

		// Immediate value multiplexer
		case(opcode)
		`LDI:		imm <= hasIMM ? {immbuf[39:0],ir[39:16]} : {{40{ir[39]}},ir[39:16]};
		`JSR:		imm <= ir[39:8];	// PC has only 32 bits implemented
		`JMP:		imm <= ir[39:8];
		`JSR_IX:	imm <= hasIMM ? {immbuf[39:0],ir[39:16]} : ir[39:16];
		`JMP_IX:	imm <= hasIMM ? {immbuf[39:0],ir[39:16]} : ir[39:16];
		`JMP_DRN:	imm <= hasIMM ? {immbuf[39:0],ir[39:16]} : ir[39:16];
		`JSR_DRN:	imm <= hasIMM ? {immbuf[39:0],ir[39:16]} : ir[39:16];
		`LBX,`LBUX,`LCX,`LCUX,`LHX,`LHUX,`LWX,`SBX,`SCX,`SHX,`SWX:
				imm <= hasIMM ? {immbuf[57:0],ir[39:34]} : ir[39:34];
		default:
			if (hasIMM)
				imm <= {immbuf[47:0],ir[39:24]};
			else
				imm <= {{48{ir[39]}},ir[39:24]};
		endcase

		// This case statement decodes all instructions.
		case(opcode)
		`NOP:	next_state(IFETCH);
		`R:
			case(func)
			`SEI:	begin im <= `TRUE; next_state(IFETCH); end
			`CLI:	begin im <= `FALSE; next_state(IFETCH); end
			`ICON:	begin icacheOn <= `TRUE; next_state(IFETCH); end
			`ICOFF:	begin icacheOn <= `FALSE; next_state(IFETCH); end
			`PHP:
				begin
					wadr <= sp_dec;
					sp <= sp_dec;
					store_what <= `STW_SR;
					next_state(STORE1);
				end
			`PLP:
				begin
					isPLP <= `TRUE;
					radr <= sp;
					sp <= sp_inc;
					next_state(LOAD1);
				end
			`RTI:
				begin
					isRTI <= `TRUE;
					radr <= sp;
					sp <= sp_inc;
					next_state(LOAD1);
				end
			// Unimplemented instruction
			default:	;
			endcase
		`RR:
			case(func)
			`MUL,`MULU,`DIV,`DIVU,`MOD,`MODU:	next_state(MULDIV);
			endcase

		`MULI,`MULUI,`DIVI,`DIVUI,`MOD,`MODU:	next_state(MULDIV);
		`CMPI:	isCMPI <= `TRUE;


		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		// Flow Control Instructions Follow
		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		`BRK:
			begin
				isBRK <= `TRUE;
				if (hwi)
					pc <= pc;
				wadr <= sp_dec;
				sp <= sp_dec;
				store_what <= `STW_SR;
				next_state(STORE1);
			end
		`JMP:	begin pc <= ir[39:8]; next_state(IFETCH); end
		`JSR:
			begin
				isJSR <= `TRUE;
				wadr <= sp_dec[31:0];
				sp <= sp_dec;
				store_what <= `STW_PC;
				next_state(STORE1);
			end
		`JSR_DRN:
			begin
				isJSRdrn <= `TRUE;
				wadr <= sp_dec[31:0];
				sp <= sp_dec;
				store_what <= `STW_PC;
				next_state(STORE1);
			end
		`RTS:
			begin
				isRTS <= `TRUE;
				radr <= sp;
				next_state(LOAD1);
				sp <= sp_inc + ir[31:16];
			end
		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		// PUSH / POP
		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		`PUSH:
			begin
				isPUSH <= `TRUE;
				ir[39:8] <= {8'h00,ir[39:16]};
				wadr <= sp_dec[31:0];
				store_what <= `STW_A;
				if (ir[39:8]==32'h0)
					next_state(IFETCH);
				else if (ir[15:8]==8'h00)
					next_state(DECODE);
				else begin
					sp <= sp_dec;
					next_state(STORE1);
				end
			end
		`POP:
			begin
				isPOP <= `TRUE;
				Rt <= ir[15:8];
				ir[39:8] <= {8'h00,ir[39:16]};
				radr <= sp[31:0];
				if (ir[39:8]==32'h0)
					next_state(IFETCH);
				else if (ir[15:8]==8'h00)
					next_state(DECODE);
				else begin
					sp <= sp_inc;
					next_state(LOAD1);
				end
			end

		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		// Prefixes follow
		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		`IMM1:
			begin
				isIMM1 <= `TRUE;
				immbuf <= {{32{ir[39]}},ir[39:8]};
				next_state(IFETCH);
			end
		`IMM2:
			begin
				isIMM2 <= `TRUE;
				immbuf[63:32] <= ir[39:8];
				next_state(IFETCH);
			end
		endcase
	end

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// EXECUTE Stage
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
EXECUTE:
	begin
		next_state(IFETCH);
		// This case statement execute instructions.
		case(opcode)
		`R:
			case(func)
			`NEG:	res <= -a;
			`COM:	res <= ~a;
			`NOT:	res <= ~|a;
			`SXB:	res <= {{56{a[7]}},a[7:0]};
			`SXC:	res <= {{48{a[15]}},a[15:0]};
			`SXH:	res <= {{32{a[31]}},a[31:0]};
			endcase
		`RR:
			case(func)
			`ADD,`ADDU:	res <= a + b;
			`SUB,`SUBU:	res <= a - b;
			`CMP:		res <= {nf,vf,60'd0,zf,cf};
			`AND:		res <= a & b;
			`OR:		res <= a | b;
			`EOR:		res <= a ^ b;
			`ANDN:		res <= a & ~b;
			`NAND:		res <= ~(a & b);
			`NOR:		res <= ~(a | b);
			`ENOR:		res <= ~(a ^ b);
			`ORN:		res <= a | ~b;
			`SHLI,`SHL:	res <= shlo[63:0];
			`ROLI,`ROL: res <= shlo[127:64]|shlo[63:0];
			`RORI,`ROR:	res <= shro[127:64]|shro[63:0];
			`SHRI,`SHR:	res <= shro[127:64];
			`ASRI,`ASR:	res <= asro;
			// Unimplemented instruction
			default:	res <= 65'd0;
			endcase
		`LDI:	res <= imm;
		`ADDI,`ADDUI:	res <= a + imm;
		`SUBI,`SUBUI:	res <= a - imm;
		`CMPI:	res <= {nf,vf,60'd0,zf,cf};
		`ANDI:	res <= a & imm;
		`ORI:	res <= a | imm;
		`EORI:	res <= a ^ imm;

		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		// Flow Control Instructions Follow
		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		`BEQ,`BNE,`BVS,`BVC,`BMI,`BPL,`BRA,`BRN,`BGT,`BGE,`BLT,`BLE,`BHI,`BHS,`BLO,`BLS,
		`BRZ,`BRNZ:
			begin
				next_state(IFETCH);
				if (take_branch) begin
					pc[15: 0] <= ir[31:16];
					pc[31:16] <= pc[31:16] + {{11{ir[36]}},ir[36:32]};
				end
			end
		`DBNZ:
			begin
				next_state(IFETCH);
				if (take_branch) begin
					pc[15: 0] <= ir[31:16];
					pc[31:16] <= pc[31:16] + {{11{ir[36]}},ir[36:32]};
				end
				res <= a - 64'd1;
			end
		`JMP_IX:
			begin
				isJMPix <= `TRUE;
				radr <= a + imm;
				next_state(LOAD1);
			end
		`JMP_DRN:	pc <= a + imm;
		`JSR_IX:
			begin
				radr <= a + imm;
				wadr <= sp_dec[31:0];
				sp <= sp_dec;
				isJSRix <= `TRUE;
				store_what <= `STW_PC;
				next_state(STORE1);
			end

		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		// Loads and Stores follow
		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
		`LB:
			begin
				radr <= a + imm;
				ld_size <= byt;
				next_state(LOAD1);
			end
		`LBU:
			begin
				radr <= a + imm;
				ld_size <= ubyte;
				next_state(LOAD1);
			end
		`LC:
			begin
				radr <= a + imm;
				ld_size <= char;
				next_state(LOAD1);
			end
		`LCU:
			begin
				radr <= a + imm;
				ld_size <= uchar;
				next_state(LOAD1);
			end
		`LH:
			begin
				radr <= a + imm;
				ld_size <= half;
				next_state(LOAD1);
			end
		`LHU:
			begin
				radr <= a + imm;
				ld_size <= uhalf;
				next_state(LOAD1);
			end
		`LW:
			begin
				radr <= a + imm;
				ld_size <= word;
				next_state(LOAD1);
			end
		`LBX:
			begin
				radr <= a + b_scaled + imm;
				ld_size <= byt;
				next_state(LOAD1);
			end
		`LBUX:
			begin
				radr <= a + b_scaled + imm;
				ld_size <= ubyte;
				next_state(LOAD1);
			end
		`LCX:
			begin
				radr <= a + b_scaled + imm;
				ld_size <= char;
				next_state(LOAD1);
			end
		`LCUX:
			begin
				radr <= a + b_scaled + imm;
				ld_size <= uchar;
				next_state(LOAD1);
			end
		`LHX:
			begin
				radr <= a + b_scaled + imm;
				ld_size <= half;
				next_state(LOAD1);
			end
		`LHUX:
			begin
				radr <= a + b_scaled + imm;
				ld_size <= uhalf;
				next_state(LOAD1);
			end
		`LWX:
			begin
				radr <= a + b_scaled + imm;
				ld_size <= word;
				next_state(LOAD1);
			end
		`SB:
			begin
				wadr <= a + imm;
				st_size <= byt;
				store_what <= `STW_B;
				next_state(STORE1);
			end
		`SC:
			begin
				wadr <= a + imm;
				st_size <= char;
				store_what <= `STW_B;
				next_state(STORE1);
			end
		`SH:
			begin
				wadr <= a + imm;
				st_size <= half;
				store_what <= `STW_B;
				next_state(STORE1);
			end
		`SW:
			begin
				wadr <= a + imm;
				st_size <= word;
				store_what <= `STW_B;
				next_state(STORE1);
			end
		`SBX:
			begin
				wadr <= a + b_scaled + imm;
				st_size <= byt;
				store_what <= `STW_C;
				next_state(STORE1);
			end
		`SCX:
			begin
				wadr <= a + b_scaled + imm;
				st_size <= char;
				store_what <= `STW_C;
				next_state(STORE1);
			end
		`SHX:
			begin
				wadr <= a + b_scaled + imm;
				st_size <= half;
				store_what <= `STW_C;
				next_state(STORE1);
			end
		`SWX:
			begin
				wadr <= a + b_scaled + imm;
				st_size <= word;
				store_what <= `STW_C;
				next_state(STORE1);
			end

		// Unimplemented opcodes handled here
		default:
			;
		endcase
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Multiply / Divide / Modulus machine states.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

MULDIV:
	begin
		cnt <= 7'd64;
		case(opcode)
		`MULUI:
			begin
				aa <= a;
				bb <= b;
				res_sgn <= 1'b0;
				next_state(MULT1);
			end
		`MULI:
			begin
				aa <= a[63] ? -a : a;
				bb <= b[63] ? -b : b;
				res_sgn <= a[63] ^ b[63];
				next_state(MULT1);
			end
		`DIVUI,`MODUI:
			begin
				aa <= a;
				bb <= b;
				q <= a[62:0];
				r <= a[63];
				res_sgn <= 1'b0;
				next_state(DIV);
			end
		`DIVI,`MODI:
			begin
				aa <= a[63] ? -a : a;
				bb <= b[63] ? -b : b;
				q <= pa[62:0];
				r <= pa[63];
				res_sgn <= a[63] ^ b[63];
				next_state(DIV);
			end
		`RR:
			case(func)
			`MULU:
				begin
					aa <= a;
					bb <= b;
					res_sgn <= 1'b0;
					next_state(MULT1);
				end
			`MUL:
				begin
					aa <= a[31] ? -a : a;
					bb <= b[31] ? -b : b;
					res_sgn <= a[63] ^ b[63];
					next_state(MULT1);
				end
			`DIVU,`MODU:
				begin
					aa <= a;
					bb <= b;
					q <= a[62:0];
					r <= a[63];
					res_sgn <= 1'b0;
					next_state(DIV);
				end
			`DIV,`MOD:
				begin
					aa <= a[63] ? -a : a;
					bb <= b[63] ? -b : b;
					q <= pa[62:0];
					r <= pa[63];
					res_sgn <= a[63] ^ b[63];
					next_state(DIV);
				end
			default:
				state <= IFETCH;
			endcase
		endcase
	end
// Three wait states for the multiply to take effect. These are needed at
// higher clock frequencies. The multipler is a multi-cycle path that
// requires a timing constraint.
MULT1:	state <= MULT2;
MULT2:	state <= MULT3;
MULT3:	begin
			p <= p1;
			next_state(res_sgn ? FIX_SIGN : MD_RES);
		end

DIV:
	begin
		q <= {q[62:0],~diff[63]};
		if (cnt==7'd0) begin
			next_state(res_sgn ? FIX_SIGN : MD_RES);
			if (diff[63])
				r <= r[62:0];
			else
				r <= diff[62:0];
		end
		else begin
			if (diff[63])
				r <= {r[62:0],q[63]};
			else
				r <= {diff[62:0],q[63]};
		end
		cnt <= cnt - 7'd1;
	end

FIX_SIGN:
	begin
		next_state(MD_RES);
		if (res_sgn) begin
			p <= -p;
			q <= -q;
			r <= -r;
		end
	end

MD_RES:
	begin
		if (opcode==`MULI || opcode==`MULUI || (opcode==`RR && (func==`MUL || func==`MULU)))
			res <= p[63:0];
		else if (opcode==`DIVI || opcode==`DIVUI || (opcode==`RR && (func==`DIV || func==`DIVU)))
			res <= q[63:0];
		else
			res <= r[63:0];
		next_state(IFETCH);
	end

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// Memory Stage
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// LOAD machine states.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

LOAD1:
	begin
		wb_read(radr);
		next_state(LOAD2);
	end
LOAD2:
	begin
		if (ack_i) begin
			radr <= radr + 32'd4;
			wb_nack();
			if (ld_size==word) begin
				res[31:0] <= dat32;
				next_state(LOAD3);
			end
			else begin
				case(ld_size)
				uhalf:	res <= dat32;
				half:	res <= {{32{dat32[31]}},dat32};
				uchar:	res <= dat16;
				char:	res <= {{48{dat16[15]}},dat16};
				ubyte:	res <= dat8;
				byt:	res <= {{56{dat8[7]}},dat8};
				default:	res[31:0] <= dat32;
				endcase
				next_state(IFETCH);
			end
		end
	end
LOAD3:
	begin
		wb_read(radr);
		next_state(LOAD4);
	end
LOAD4:
	begin
		if (ack_i) begin
			radr <= radr + 32'd4;
			wb_nack();
			res[63:32] <= dat32;
			case(1'b1)
			isJSRix,isJMPix:
				begin
					pc <= res[31:0];
					next_state(IFETCH);
				end
			isRTS:
				begin
					pc <= res[31:0] + ir[15:8];
					next_state(IFETCH);
				end
			isRTI:
				begin
					isPLP <= `TRUE;
					isRTI <= `FALSE;
					pc <= res[31:0];
					next_state(LOAD1);
				end
			isPOP:
				begin
					wrrf <= `TRUE;
					next_state(DECODE);
				end
			isPLP:
				begin
					im <= res[8];
					next_state(IFETCH);
				end
			default:
				next_state(IFETCH);
			endcase
		end
	end


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// STORE machine states.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

STORE1:
	begin
		case (store_what)
		`STW_A:		wb_write(st_size,wadr,a[31:0]);
		`STW_B:		wb_write(st_size,wadr,b[31:0]);
		`STW_C:		wb_write(st_size,wadr,c[31:0]);
		`STW_PC:	wb_write(word,wadr,pc[31:0]);
		`STW_SR:	wb_write(word,wadr,sr[31:0]);
		endcase
		next_state(STORE2);
	end
STORE2:
	begin
		wb_nack();
		wadr <= wadr + 32'd4;
		if (st_size==word)
			next_state(STORE3);
		else
			next_state(IFETCH);
	end
STORE3:
	begin
		case (store_what)
		`STW_A:		wb_write(word,wadr,a[63:32]);
		`STW_B:		wb_write(word,wadr,b[63:32]);
		`STW_C:		wb_write(word,wadr,c[63:32]);
		`STW_PC:	wb_write(word,wadr,32'h0);
		`STW_SR:	wb_write(word,wadr,32'd0);
		endcase
		next_state(STORE4);
	end
STORE4:
	begin
		wb_nack();
		wadr <= wadr + 32'd4;
		case(1'b1)
		isBRK:
			begin
				if (store_what==`STW_PC) begin
					pc <= imm;
					next_state(IFETCH);
				end
				else begin
					store_what <= `STW_PC;
					wadr <= wadr - 32'd12;
					next_state(STORE1);
				end
			end
		isJSR:
			begin
				pc <= imm;
				next_state(IFETCH);
			end
		isJSRdrn:
			begin
				pc <= rfoa + imm;
				next_state(IFETCH);
			end
		isJSRix:
			next_state(LOAD1);
		isPOP,isPUSH:
			next_state(DECODE);
		default:
			next_state(IFETCH);
		endcase
	end
endcase


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// WRITEBACK Stage
// - This stage updates the register file and is overlapped with the 
//   instruction fetch stage.
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Update the register file
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if (state==IFETCH || wrrf) begin
	regfile[Rt] <= res;
	if (Rt==8'hFF) begin
		sp <= {res[63:3],3'b000};
		gie <= `TRUE;
	end
end

end

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// Support tasks
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

task next_state;
input [5:0] nxt;
begin
	state <= nxt;
end
endtask

// the read task always reads a whole half-word
task wb_read;
input [31:0] adr;
begin
	cyc_o <= 1'b1;
	stb_o <= 1'b1;
	sel_o <= 4'hF;
	adr_o <= {adr[31:2],2'b00};
end
endtask

task wb_write;
input [2:0] size;
input [31:0] adr;
input [31:0] dat;
begin
	cyc_o <= 1'b1;
	stb_o <= 1'b1;
	we_o <= 1'b1;
	adr_o <= {adr[31:2],2'b00};
	case(size)
	word,half,uhalf:
		begin
			sel_o <= 4'hF;
			dat_o <= dat;
		end
	char,uchar:
		begin
			sel_o <= adr[1] ? 4'b1100 : 4'b0011;
			dat_o <= {2{dat[15:0]}};
		end
	byt,ubyte:
		begin
			case(adr[1:0])
			2'b00:	begin sel_o <= 4'b0001; dat_o <= {4{dat[7:0]}}; end
			2'b01:	begin sel_o <= 4'b0010; dat_o <= {4{dat[7:0]}}; end
			2'b10:	begin sel_o <= 4'b0100; dat_o <= {4{dat[7:0]}}; end
			2'b11:	begin sel_o <= 4'b1000; dat_o <= {4{dat[7:0]}}; end
			endcase
		end
	endcase
end
endtask

task wb_burst;
input [5:0] bl;
input [31:0] adr;
begin
	bte_o <= 2'b00;
	cti_o <= 3'b001;
	bl_o <= bl;
	cyc_o <= 1'b1;
	stb_o <= 1'b1;
	sel_o <= 4'hF;
	adr_o <= adr;
end
endtask

// NACK cycle for bus acknowledge
task wb_nack;
begin
	bte_o <= 2'b00;
	cti_o <= 3'b000;
	bl_o <= 6'd0;
	cyc_o <= 1'b0;
	stb_o <= 1'b0;
	we_o <= 1'b0;
	sel_o <= 4'h0;
	adr_o <= 32'h0;
	dat_o <= 32'h0;
end
endtask

function [127:0] fnStateName;
input [5:0] state;
case(state)
RESET:	fnStateName = "RESET      ";
IFETCH:	fnStateName = "IFETCH     ";
DECODE:	fnStateName = "DECODE     ";
EXECUTE:	fnStateName = "EXECUTE   ";
RTS1:	fnStateName = "RTS1       ";
MULDIV:	fnStateName = "MULDIV    ";
MULT1:	fnStateName = "MULT1   ";
MULT2:	fnStateName = "MULT2   ";
MULT3:	fnStateName = "MULT3   ";
DIV:	fnStateName = "DIV     ";
FIX_SIGN:	fnStateName = "FIX_SIGN   ";
MD_RES:	fnStateName = "MD_RES    ";
LOAD1:	fnStateName = "LOAD1   ";
LOAD2:	fnStateName = "LOAD2  ";
LOAD3:	fnStateName = "LOAD3  ";
LOAD4:	fnStateName = "LOAD4  ";
STORE1:	fnStateName = "STORE1     ";
STORE2:	fnStateName = "STORE2     ";
STORE3:	fnStateName = "STORE3     ";
STORE4:	fnStateName = "STORE4     ";
IBUF1:		fnStateName = "IBUF1 ";
IBUF2:		fnStateName = "IBUF2 ";
IBUF3:		fnStateName = "IBUF3 ";
ICACHE1:		fnStateName = "ICACHE1    ";
ICACHE2:		fnStateName = "ICACHE2    ";
default:		fnStateName = "UNKNOWN    ";
endcase
endfunction

endmodule

module syncram_512x32_1rw1r(wclk, wr, wa, i, rclk, ra, o);
input wclk;
input wr;
input [8:0] wa;
input [31:0] i;
input rclk;
input [8:0] ra;
output [31:0] o;

reg [31:0] mem [511:0];
reg [8:0] rra;

always @(posedge wclk)
	if (wr)
		mem[wa] <= i;
always @(posedge rclk)
	rra <= ra;
assign o = mem[rra];

endmodule

module icache_ram(wclk, wr, wa, i, rclk, pc, insn, debug_bits);
input wclk;
input wr;
input [12:0] wa;
input [31:0] i;
input rclk;
input [12:0] pc;
output reg [39:0] insn;
output reg [1:0] debug_bits;

wire [31:0] o1,o2,o3,o4;

syncram_512x32_1rw1r u1 (wclk, wr && wa[3:2]==2'b00, wa[12:4], i, rclk, pc[12:4], o1);
syncram_512x32_1rw1r u2 (wclk, wr && wa[3:2]==2'b01, wa[12:4], i, rclk, pc[12:4], o2);
syncram_512x32_1rw1r u3 (wclk, wr && wa[3:2]==2'b10, wa[12:4], i, rclk, pc[12:4], o3);
syncram_512x32_1rw1r u4 (wclk, wr && wa[3:2]==2'b11, wa[12:4], i, rclk, pc[12:4], o4);

wire [127:0] bundle = {o4,o3,o2,o1};

always @(bundle or pc)
case(pc[3:0])
4'h0:	insn <= bundle[ 39: 0];
4'h5:	insn <= bundle[ 79:40];
4'hA:	insn <= bundle[119:80];
default:	insn <= {`ALN_VECT,8'h50};	// JMP Alignment fault
endcase

always @(bundle or pc)
case(pc[3:0])
4'h0:	debug_bits <= bundle[121:120];
4'h5:	debug_bits <= bundle[123:122];
4'hA:	debug_bits <= bundle[125:124];
default:	debug_bits <= 2'b00;
endcase

endmodule

module icache_tagram(wclk, wr, wa, v, rclk, pc, hit);
input wclk;
input wr;
input [31:0] wa;
input v;
input rclk;
input [31:0] pc;
output hit;

wire [31:0] tag;

syncram_512x32_1rw1r u1 (wclk, wr && wa[3:2]==2'b11, wa[12:4], {wa[31:1],v}, rclk, pc[12:4], tag);

assign hit = tag[31:13]==pc[31:13] && tag[0];

endmodule
