// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2019  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpRsqrte.v
//		- reciprocal square root estimate
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
//
// ============================================================================

`define POINT5			32'h3F000000
`define ONEPOINT5		32'h3FC00000
`define FRSQRTE_MAGIC		32'h5f3759df

module fpRsqrte(clk, ce, ld, a, o);
parameter WID = 32;
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
input clk;
input ce;
input ld;
input [WID-1:0] a;
output reg [WID-1:0] o;

// An implementation of the approximation used in the Quake game.

reg [31:0] x2, x2yy;
reg [31:0] y, yy;
wire [31:0] y1 = `FRSQRTE_MAGIC - a[31:1];
reg [31:0] aa0, bb0, aa1, bb1;
wire [31:0] mo0, mo1, x2yy1p5;

reg [3:0] cnt;
reg [5:0] state;
always @(posedge clk)
begin
	if (ld) begin
		state <= MULP5;
		cnt <= 4'd5;
		aa0 <= a;
		bb0 <= `POINT5;
		aa1 <= y1;
		bb1 <= y1;
	end
	case(state)
	IDLE:	;
	MULP5:	
		begin
			cnt <= cnt - 4'd1;
			if (cnt[3]) begin
				cnt <= 4'd5;
				x2 <= mo0;
				yy <= mo1;
				aa0 <= mo0;
				bb0 <= mo1;
				state <= MULX2YY;
			end
		end
	MULX2YY:
		begin
			cnt <= cnt - 4'd1;
			if (cnt[3]) begin
				x2yy <= mo0;
				aa0 <= `ONEPOINT5;
				bb0 <= mo0;
				state <= SUB;
			end
		end
	SUB:
		begin
			cnt <= cnt - 4'd1;
			if (cnt[3]) begin
				cnt <= 4'd5;
				aa0 <= y;
				bb0 <= x2yy1p5;
				state <= RES;
			end
		end
	RES:
		begin
			o <= mo0;
			state <= IDLE:
		end
	endcase
end

fpMulnr #(32) u1 (clk, ce, aa0, bb0, mo0);
fpMulnr #(32) u1 (clk, ce, aa1, bb1, mo1);
fpAddsubnr #(32) u4 (clk, ce, 3'd0, 1'b1, aa0, bb0, x2yy1p5);


fpMulnr #(32) u1 (clk, ce, a, `POINT5, x2);
assign y = `FRSQRTE_MAGIC - a[31:1];
fpMulnr #(32) u2 (clk, ce, y, y, yy);
fpMulnr #(32) u3 (clk, ce, x2, yy, x2yy);
fpAddsubnr #(32) u4 (clk, ce, 3'd0, 1'b1, `ONEPOINT5, x2yy, x2yy1p5);
fpMulnr #(32) u5 (clk, ce, y, x2yy1p5, o);

endmodule
