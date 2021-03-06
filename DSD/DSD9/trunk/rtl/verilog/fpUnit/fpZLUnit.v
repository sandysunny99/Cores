`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2007-2016  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpZLUnit.v
//		- zero latency floating point unit
//		- instructions can execute in a single cycle without
//		  a clock
//		- parameterized width
//		- IEEE 754 representation
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
//	fabs	- get absolute value of number
//	fnabs	- get negative absolute value of number
//	fneg	- negate number
//	fmov	- copy input to output
//	fsign	- get sign of number (set number to +1,0, or -1)
//	fman	- get mantissa (set exponent to zero)
//  fcmp
//
// ============================================================================

`define FLOAT   8'hF1
`define FCMP    6'h06
`define FMOV    6'h10
`define FNEG    6'h14
`define FABS    6'h15
`define FSIGN   6'h16
`define FMAN    6'h17
`define FNABS   6'h18
`define FCVTSQ  6'h1B

module fpZLUnit
#(parameter WID=32)
(
    input [39:0] ir,
	input [WID-1:0] a,
	input [WID-1:0] b,	// for fcmp
	output reg [WID-1:0] o,
	output nanx
);
localparam MSB = WID-1;
localparam EMSB = WID==128 ? 14 :
                  WID==96 ? 14 :
                  WID==80 ? 14 :
                  WID==64 ? 10 :
				  WID==52 ? 10 :
				  WID==48 ? 11 :
				  WID==44 ? 10 :
				  WID==42 ? 10 :
				  WID==40 ?  9 :
				  WID==32 ?  7 :
				  WID==24 ?  6 : 4;
localparam FMSB = WID==128 ? 111 :
                  WID==96 ? 79 :
                  WID==80 ? 63 :
                  WID==64 ? 51 :
				  WID==52 ? 39 :
				  WID==48 ? 34 :
				  WID==44 ? 31 :
				  WID==42 ? 29 :
				  WID==40 ? 28 :
				  WID==32 ? 22 :
				  WID==24 ? 15 : 9;

wire [7:0] op = ir[7:0];
wire [1:0] prec = ir[37:35];
wire [5:0] fn = ir[25:20];

wire [4:0] cmp_o;

fp_cmp_unit #(WID) u1 (.a(a), .b(b), .o(cmp_o), .nanx(nanx) );
wire [127:0] sq_o;
fcvtsq u2 (a[31:0], sq_o);

always @*
    case(op)
    `FLOAT:
        case(fn)
        `FABS:   o <= {1'b0,a[WID-2:0]};        // fabs
        `FNABS:  o <= {1'b1,a[WID-2:0]};        // fnabs
        `FNEG:   o <= {~a[WID-1],a[WID-2:0]};   // fneg
        `FMOV:   o <= a;                        // fmov
        `FSIGN:  o <= (a[WID-2:0]==0) ? 0 : {a[WID-1],1'b0,{EMSB{1'b1}},{FMSB+1{1'b0}}};    // fsign
        `FMAN:   o <= {a[WID-1],1'b0,{EMSB{1'b1}},a[FMSB:0]};    // fman
        `FCVTSQ:    o <= sq_o;
        `FCMP:   o <= cmp_o;
        default: o <= 0;
        endcase
	default:	o <= 0;
	endcase

endmodule
