// ============================================================================
//        __
//   \\__/ o\    (C) 2017  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	N4V68kSys.v
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
module N4V68kSys(cpu_resetn, xclk, led, btnu, btnd, btnl, btnr, btnc, sw,
    kd, kclk,
    TMDS_OUT_clk_p, TMDS_OUT_clk_n, TMDS_OUT_data_p, TMDS_OUT_data_n,
    ddr3_ck_p,ddr3_ck_n,ddr3_cke,ddr3_reset_n,ddr3_ras_n,ddr3_cas_n,ddr3_we_n,
    ddr3_ba,ddr3_addr,ddr3_dq,ddr3_dqs_p,ddr3_dqs_n,ddr3_dm,ddr3_odt
);
input cpu_resetn;
input xclk;
output [7:0] led;
input btnu;
input btnd;
input btnl;
input btnr;
input btnc;
input [7:0] sw;
inout tri kd;
inout tri kclk;
output TMDS_OUT_clk_p;
output TMDS_OUT_clk_n;
output [2:0] TMDS_OUT_data_p;
output [2:0] TMDS_OUT_data_n;

output [0:0] ddr3_ck_p;
output [0:0] ddr3_ck_n;
output [0:0] ddr3_cke;
output ddr3_reset_n;
output ddr3_ras_n;
output ddr3_cas_n;
output ddr3_we_n;
output [2:0] ddr3_ba;
output [14:0] ddr3_addr;
inout [15:0] ddr3_dq;
inout [1:0] ddr3_dqs_p;
inout [1:0] ddr3_dqs_n;
output [1:0] ddr3_dm;
output [0:0] ddr3_odt;

parameter SIM = 1'b0;

wire clk200,clk40;
wire locked;
wire cpu_clk = clk40;
wire _cpu_reset;
wire rst = ~locked;
wire [2:0] _cpu_ipl;
wire dram_dvalid;
wire [15:0] dram_data_o;
wire _cpu_as;
wire _cpu_lds;
wire _cpu_uds;
wire cpu_r_w;
wire _cpu_dtack;
wire cpu_dd;
wire [31:0] cpu_addr;
wire [15:0] cpu_data_o;
wire [15:0] cpu_data =  cpu_r_w ? 16'bz : cpu_data_o; //cpu_dd ? cpu_data_o : 16'bz;
wire [15:0] cpu_data_i;

//assign _cpu_reset = locked ? 1'b1 : 1'b0;

wire eol, eof;
wire hSync, vSync;
wire hSync_n = ~hSync;
wire vSync_n = ~vSync;
wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire blank, border;

wire vdg_ack;
wire [15:0] vdg_data_o;
wire [8:0] vdg_rgb;

wire _ram_bhe,_ram_ble;
wire _ram_we,_ram_oe;
wire _ram_ce;
wire [15:0] ram_data;
wire [15:0] ram_data_i = ram_data;
wire [15:0] ram_data_o;
assign ram_data = _ram_we ? (&_ram_ce ? 16'd0000 : ram_data_o) : 16'bz;
wire [31:1] ram_addr,ram_addr1;
wire [15:0] chip_ram_dat_o;

wire br_ack;
wire [15:0] br_data_o;

wire kbd_ack;
wire [15:0] kbd_data_o;
wire rand_ack;
wire [15:0] rand_data_o;

wire sel_boot;
reg [7:0] ledo;

wire cs_boot = cpu_addr[31:20]==12'hFFF || cpu_addr[31:3]==29'h0;
wire cs_dram = cpu_addr[31:29]==3'b000 && !_cpu_as && !cs_boot;
wire cs_vdg_reg = cpu_addr[31:12]==20'hFFE00;
wire cs_vdg_ram = cpu_addr[31:21]==11'b1111_1111_100;
wire cs_led  = cpu_addr[31:4]==28'hFFDC060;
wire cs_rand = cpu_addr[31:4]==28'hFFDC0C0;

assign cpu_data_i = cs_dram ? dram_data_o :
                    cs_boot ? br_data_o :
                    (cs_vdg_reg | cs_vdg_ram) ? vdg_data_o :
                    cs_rand ? rand_data_o :
                    kbd_data_o;

wire _dram_dtack = cpu_r_w ? ~dram_dvalid | ~cs_dram : ~cs_dram;
wire led_ack = cs_led & ~cpu_as;
assign _cpu_dtack = _dram_dtack & ~vdg_ack & ~br_ack & ~kbd_ack & ~led_ack & ~rand_ack; 
assign _cpu_ipl = 3'b111;

wire btnuo, btndd, btnld, btnrd, btncd;
BtnDebounce ubdb1 (clk40, btnu, btnud);
BtnDebounce ubdb2 (clk40, btnd, btndd);
BtnDebounce ubdb3 (clk40, btnl, btnld);
BtnDebounce ubdb4 (clk40, btnr, btnrd);
BtnDebounce ubdb5 (clk40, btnc, btncd);

always @(posedge cpu_clk)
    if (cs_led)
        ledo <= cpu_data_o[7:0];

clk_wiz_0 ucg1
(
    // Clock out ports
    .clk_out1(),
    .clk_out2(clk200),
    .clk_out3(clk40),
    .clk_out4(),
    // Status and control signals
    .reset(~cpu_resetn),
    .locked(locked),
   // Clock in ports
    .clk_in1(xclk)
);

VGASyncGen800x600_60Hz uvgasg1
(
	.rst(rst),
	.clk(clk40),
	.eol(eol),
	.eof(eof),
	.hSync(hSync),
	.vSync(vSync),
	.hCtr(),
	.vCtr(),
    .blank(blank),
    .vblank(),
    .vbl_int(),
    .border(border)
);

// The following core supplied by Digilent as part of the NexysVideo examples.
rgb2dvi #(
    .kGenerateSerialClk(1'b0),
    .kClkPrimitive("MMCM"),
    .kClkRange(3),
    .kRstActiveHigh(1'b1)
)
ur2d1 
(
    .TMDS_Clk_p(TMDS_OUT_clk_p),
    .TMDS_Clk_n(TMDS_OUT_clk_n),
    .TMDS_Data_p(TMDS_OUT_data_p),
    .TMDS_Data_n(TMDS_OUT_data_n),
    .aRst(rst),
    .aRst_n(~rst),
    .vid_pData({red,blue,green}),
    .vid_pVDE(~blank),
    .vid_pHSync(~hSync),
    .vid_pVSync(vSync),
    .PixelClk(clk40),
    .SerialClk(clk200)
);

TG68 utg68k
(        
	.clk(cpu_clk),
	.reset(~rst),
    .clkena_in(1'b1),
    .data_in(cpu_data_i),
    .IPL(_cpu_ipl),
    .dtack(_cpu_dtack),
    .addr(cpu_addr),
    .data_out(cpu_data_o),
    .as(_cpu_as),
    .uds(_cpu_uds),
    .lds(_cpu_lds),
    .rw(cpu_r_w),
    .drive_data(cpu_dd)
);

bootrom(
    .clk_i(cpu_clk),
    .cs_i(cs_boot),
    .cyc_i(~cpu_as),
    .ack_o(br_ack),
    .adr_i(cpu_addr[15:0]),
    .dat_o(br_data_o)
);

DDRcontrol DDRCtrl1
(
	// Common
	.clk_200MHz_i(clk200),	// 200 MHz system clock
	.rst_i(rst),              // active high system reset

	// RAM interface
	.ram_a({cpu_addr[28:1],1'b0}),
	.ram_dq_i(cpu_data_o),
	.ram_dq_o(dram_data_o),
	.ram_cen(~cs_dram),
	.ram_oen(~cpu_r_w),
	.ram_wen(cpu_r_w),
	.ram_bhe(_cpu_uds),
	.ram_ble(_cpu_lds),
	.data_valid(dram_dvalid),
      
	// DDR3 interface
	.ddr3_dq(ddr3_dq),
	.ddr3_dqs_n(ddr3_dqs_n),
	.ddr3_dqs_p(ddr3_dqs_p),
	.ddr3_addr(ddr3_addr),
	.ddr3_ba(ddr3_ba),
	.ddr3_ras_n(ddr3_ras_n),
	.ddr3_cas_n(ddr3_cas_n),
	.ddr3_we_n(ddr3_we_n),
	.ddr3_ck_p(ddr3_ck_p),
	.ddr3_ck_n(ddr3_ck_n),
	.ddr3_cke(ddr3_cke),
	.ddr3_reset_n(ddr3_reset_n),
	.ddr3_dm(ddr3_dm),
	.ddr3_odt(ddr3_odt)
);

BitmapDisplay uvdg1
(
	.rst_i(rst),
	.clk_i(cpu_clk),
	.cyc_i(~_cpu_as),
	.stb_i(~_cpu_as),
	.ack_o(vdg_ack),
	.we_i(~cpu_r_w),
	.sel_i(1'b1),
	.adr_i(cpu_addr[23:0]),
	.dat_i(cpu_data_o),
	.dat_o(vdg_data_o),
	.cs_i(cs_vdg_reg),
	.cs_ram_i(cs_vdg_ram),
	.clk(clk40),
	.eol(eol),
	.eof(eof),
	.blank(blank),
    .border(border),
	.rgb(vdg_rgb)
);

random	uprg1
(
	.rst_i(rst),
	.clk_i(cpu_clk),
	.cs_i(cs_rand),
	.cyc_i(~_cpu_as),
	.stb_i(1'b1),
	.ack_o(rand_ack),
	.we_i(~cpu_r_w),
	.adr_i(cpu_addr[3:0]),
	.dat_i(cpu_data_o),
	.dat_o(rand_data_o)
);


assign led = btndd ? cpu_addr[23:16] :
			 btnrd ? cpu_addr[15:8] :
			 btnld ? cpu_addr[7:0] :
			 ledo;

//assign led[1] = sel_boot;
//assign led[0] = vSync;
//assign led[1] = locked;
/*
assign led[1:0] = 2'h0;
assign led[6] = locked;
assign led[5] = cpu_clk;
assign led[4] = ~cpu_resetn;
assign led[3] = vSync;
assign led[2] = hSync;
*/
assign red = {vdg_rgb[8:6],5'h0};
assign green = {vdg_rgb[5:3],5'h0};
assign blue = {vdg_rgb[2:0],5'h0};

endmodule
