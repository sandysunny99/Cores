`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2018  Robert Finch, Waterloo
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
//
// Register file with two write ports and six read ports.
// ============================================================================
//
module regfileRam(wclk, wr, wa, i, rclk,
	ra0, ra1, ra2, ra3, ra4, ra5,
	o0, o1, o2, o3, o4, o5);
parameter WID = 64;
parameter RBIT = 11;
input wclk;
input wr;
input [RBIT:0] wa;
input [WID-1:0] i;
input rclk;
input [RBIT:0] ra0;
input [RBIT:0] ra1;
input [RBIT:0] ra2;
input [RBIT:0] ra3;
input [RBIT:0] ra4;
input [RBIT:0] ra5;
output [WID-1:0] o0;
output [WID-1:0] o1;
output [WID-1:0] o2;
output [WID-1:0] o3;
output [WID-1:0] o4;
output [WID-1:0] o5;

(* RAM_STYLE="BLOCK" *)
reg [WID-1:0] mem [0:RBIT==11 ? 4095:RBIT==10 ? 2047:RBIT==9 ? 1023:RBIT==7 ? 255 : 63];
reg [RBIT:0] rra0, rra1, rra2, rra3, rra4, rra5;

`ifdef SIMULATION
integer n;
initial begin
    for (n = 0; n < ((RBIT==11) ? 4095 : (RBIT==10) ? 2047 : (RBIT==9) ? 1024: 256); n = n + 1)
    begin
        mem[n] = 0;
    end
end
`endif

always @(posedge wclk)
	if (wr)
		mem[wa] <= i;
always @(posedge wclk)	rra0 <= ra0;
always @(posedge wclk)	rra1 <= ra1;
always @(posedge wclk)	rra2 <= ra2;
always @(posedge wclk)	rra3 <= ra3;
always @(posedge wclk)	rra4 <= ra4;
always @(posedge wclk)	rra5 <= ra5;

assign o0 = mem[rra0];
assign o1 = mem[rra1];
assign o2 = mem[rra2];
assign o3 = mem[rra3];
assign o4 = mem[rra4];
assign o5 = mem[rra5];

endmodule

module FT64_regfile2w6r(clk, wr0, wr1, wa0, wa1, i0, i1,
	rclk, ra0, ra1, ra2, ra3, ra4, ra5,
	o0, o1, o2, o3, o4, o5);
parameter WID=64;
parameter RBIT = 11;
input clk;
input wr0;
input wr1;
input [RBIT:0] wa0;
input [RBIT:0] wa1;
input [WID-1:0] i0;
input [WID-1:0] i1;
input rclk;
input [RBIT:0] ra0;
input [RBIT:0] ra1;
input [RBIT:0] ra2;
input [RBIT:0] ra3;
input [RBIT:0] ra4;
input [RBIT:0] ra5;
output [WID-1:0] o0;
output [WID-1:0] o1;
output [WID-1:0] o2;
output [WID-1:0] o3;
output [WID-1:0] o4;
output [WID-1:0] o5;

wire [WID-1:0] o00, o01, o02, o03, o04, o05;
wire [WID-1:0] o10, o11, o12, o13, o14, o15;
regfileRam #(WID,RBIT) urf1 (clk, wr0, wa0, i0, rclk, ra0, ra1, ra2, ra3, ra4, ra5, o00, o01, o02, o03, o04, o05);
regfileRam #(WID,RBIT) urf2 (clk, wr1, wa1, i1, rclk, ra0, ra1, ra2, ra3, ra4, ra5, o10, o11, o12, o13, o14, o15);

reg whichreg [0:RBIT==11 ? 4095:RBIT==10 ? 2047:RBIT==9 ? 1023 :255];	// tracks which register file is the valid one for a given register

// We only care about what's in the regs to begin with in simulation. In sim
// the 'x' values propagate screwing things up. In real hardware there's no such
// thing as an 'x'.
`define SIMULATION
`ifdef SIMULATION
integer n;
initial begin
    for (n = 0; n < ((RBIT==11) ? 4095 : (RBIT==10) ? 2047 : (RBIT==9) ? 1024: 256); n = n + 1)
    begin
        regs0[n] = 0;
        regs1[n] = 0;
        whichreg[n] = 0;
    end
end
`endif


assign o0 = ra0[4:0]==5'd0 ? {WID{1'b0}} :
	(wr1 && (ra0==wa1)) ? i1 :
	(wr0 && (ra0==wa0)) ? i0 :
	whichreg[ra0]==1'b0 ? o00 : o10;
assign o1 = ra1[4:0]==5'd0 ? {WID{1'b0}} :
	(wr1 && (ra1==wa1)) ? i1 :
	(wr0 && (ra1==wa0)) ? i0 :
	whichreg[ra1]==1'b0 ? o01 : o11;
assign o2 = ra2[4:0]==5'd0 ? {WID{1'b0}} :
	(wr1 && (ra2==wa1)) ? i1 :
	(wr0 && (ra2==wa0)) ? i0 :
	whichreg[ra2]==1'b0 ? o02 : o12;
assign o3 = ra3[4:0]==5'd0 ? {WID{1'b0}} :
	(wr1 && (ra3==wa1)) ? i1 :
	(wr0 && (ra3==wa0)) ? i0 :
	whichreg[ra3]==1'b0 ? o03 : o13;
assign o4 = ra4[4:0]==5'd0 ? {WID{1'b0}} :
    (wr1 && (ra4==wa1)) ? i1 :
    (wr0 && (ra4==wa0)) ? i0 :
    whichreg[ra4]==1'b0 ? o04 : o14;
assign o5 = ra5[4:0]==5'd0 ? {WID{1'b0}} :
    (wr1 && (ra5==wa1)) ? i1 :
    (wr0 && (ra5==wa0)) ? i0 :
    whichreg[ra5]==1'b0 ? o05 : o15;

always @(posedge clk)
	// writing three registers at once
	if (wr0 && wr1 && wa0==wa1)		// Two ports writing the same address
		whichreg[wa0] <= 1'b1;		// port one is the valid one
	// writing two registers
	else if (wr0 && wr1) begin
		whichreg[wa0] <= 1'b0;
		whichreg[wa1] <= 1'b1;
	end
	// writing a single register
	else if (wr0)
		whichreg[wa0] <= 1'b0;
	else if (wr1)
		whichreg[wa1] <= 1'b1;

endmodule

