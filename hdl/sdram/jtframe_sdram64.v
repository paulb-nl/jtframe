// SDRAM is set to burst=2 (64 bits)

module jtframe_sdram64 #(
    parameter AW=22,
              HF=1,     // 1 for HF operation (idle cycles), 0 for LF operation
                        // HF operation starts at 66.6MHz (1/15ns)
              SHIFTED=0,
              BA0_LEN=1, // 1=16 bits, 2=32 bits, 4=64 bits
              BA1_LEN=1,
              BA2_LEN=1,
              BA3_LEN=1
)(
    input               rst,
    input               clk,

    // requests
    input      [AW-1:0] ba0_addr,
    input      [AW-1:0] ba1_addr,
    input      [AW-1:0] ba2_addr,
    input      [AW-1:0] ba3_addr,
    input         [3:0] rd,
    input         [3:0] wr,
    input        [15:0] din,
    input        [ 1:0] din_m,  // write mask

    output        [3:0] ack,
    output reg    [3:0] dst,
    output reg    [3:0] dbusy,
    output reg    [3:0] rdy,
    output reg   [15:0] dout,

    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    inout       [15:0]  sdram_dq,       // SDRAM Data bus 16 Bits
    output reg  [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    output              sdram_dqml,     // SDRAM Low-byte Data Mask
    output              sdram_dqmh,     // SDRAM High-byte Data Mask
    output reg  [ 1:0]  sdram_ba,       // SDRAM Bank Address
    output              sdram_nwe,      // SDRAM Write Enable
    output              sdram_ncas,     // SDRAM Column Address Strobe
    output              sdram_nras,     // SDRAM Row Address Strobe
    output              sdram_ncs       // SDRAM Chip Select
);

wire  [3:0] br, bx0_cmd, bx1_cmd, bx2_cmd, bx3_cmd,
            ba_dst, ba_dbusy, ba_rdy, init_cmd;
wire        init;
reg   [3:0] bg, cmd;
reg   [1:0] prio;    // this could be a lfsr...
wire [12:0] bx0_a, bx1_a, bx2_a, bx3_a, init_a;

assign {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe } = cmd;
assign {sdram_dqmh, sdram_dqml} = sdram_a[12:11];


always @(posedge clk) begin
    dst   <= ba_dst;
    rdy   <= ba_rdy;
    dbusy <= ba_dbusy;
    dout  <= sdram_dq;
    { cmd, sdram_a } <= init ? {init_cmd, init_a } : (
                       bg[0] ? {bx0_cmd, bx0_a } : (
                       bg[1] ? {bx1_cmd, bx1_a } : (
                       bg[2] ? {bx2_cmd, bx2_a } : {bx3_cmd,bx3_a})));
    sdram_ba <= (init || bg[0]) ? 2'd0 : ( bg[1] ? 2'd1 :( bg[2] ? 2'd2 : 2'd3 ));
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prio <= 0;
    end else begin
        prio <= prio + 2'd1;
    end
end

jtframe_sdram64_init #(.HF(HF)) u_init(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .init       ( init      ),
    .cmd        ( init_cmd  ),
    .sdram_a    ( init_a    )
);

jtframe_sdram64_bank #(
    .AW       ( AW      ),
    .HF       ( HF      ),
    .SHIFTED  ( SHIFTED ),
    .BANKLEN  ( BA0_LEN )
) u_bank0(
    .rst        ( rst        ),
    .clk        ( clk        ),

    // requests
    .addr       ( ba0_addr   ),
    .rd         ( rd[0]      ),
    .wr         ( wr[0]      ),

    .ack        ( ack[0]     ),
    .dst        ( ba_dst[0]  ),    // data starts
    .dbusy      ( ba_dbusy[0]),
    .rdy        ( ba_rdy[0]  ),

    // SDRAM interface
    .br         ( br[0]      ), // bus request
    .bg         ( bg[0]      ), // bus grant

    .sdram_a    ( bx0_a      ),
    .cmd        ( bx0_cmd    )
);

always @(*) begin
    case( {br, prio[1:0]} )
        6'b0000_00: bg=4'b0000;
        6'b0000_01: bg=4'b0000;
        6'b0000_10: bg=4'b0000;
        6'b0000_11: bg=4'b0000;
        6'b0001_00: bg=4'b0001;
        6'b0001_01: bg=4'b0001;
        6'b0001_10: bg=4'b0001;
        6'b0001_11: bg=4'b0001;
        6'b0010_00: bg=4'b0010;
        6'b0010_01: bg=4'b0010;
        6'b0010_10: bg=4'b0010;
        6'b0010_11: bg=4'b0010;
        6'b0011_00: bg=4'b0001;
        6'b0011_01: bg=4'b0010;
        6'b0011_10: bg=4'b0001;
        6'b0011_11: bg=4'b0010;
        6'b0100_00: bg=4'b0100;
        6'b0100_01: bg=4'b0100;
        6'b0100_10: bg=4'b0100;
        6'b0100_11: bg=4'b0100;
        6'b0101_00: bg=4'b0001;
        6'b0101_01: bg=4'b0001;
        6'b0101_10: bg=4'b0100;
        6'b0101_11: bg=4'b0100;

        6'b0110_00: bg=4'b0010;
        6'b0110_01: bg=4'b0010;
        6'b0110_10: bg=4'b0100;
        6'b0110_11: bg=4'b0100;

        6'b0111_00: bg=4'b0001;
        6'b0111_01: bg=4'b0010;
        6'b0111_10: bg=4'b0100;
        6'b0111_11: bg=4'b0001;  //*0001

        6'b1000_00: bg=4'b1000;
        6'b1000_01: bg=4'b1000;
        6'b1000_10: bg=4'b1000;
        6'b1000_11: bg=4'b1000;

        6'b1001_00: bg=4'b0001;
        6'b1001_01: bg=4'b0001;
        6'b1001_10: bg=4'b1000;
        6'b1001_11: bg=4'b1000;

        6'b1010_00: bg=4'b0010;
        6'b1010_01: bg=4'b0010;
        6'b1010_10: bg=4'b1000;
        6'b1010_11: bg=4'b1000;

        6'b1011_00: bg=4'b0001;
        6'b1011_01: bg=4'b0010; //*0010
        6'b1011_10: bg=4'b0010;
        6'b1011_11: bg=4'b1000;

        6'b1100_00: bg=4'b1000;
        6'b1100_01: bg=4'b0100;
        6'b1100_10: bg=4'b0100;
        6'b1100_11: bg=4'b1000;

        6'b1101_00: bg=4'b0001;
        6'b1101_01: bg=4'b0100; //*0100
        6'b1101_10: bg=4'b0100;
        6'b1101_11: bg=4'b1000;

        6'b1110_00: bg=4'b1000; //*1000
        6'b1110_01: bg=4'b0010;
        6'b1110_10: bg=4'b0100;
        6'b1110_11: bg=4'b1000;

        6'b1111_00: bg=4'b0001;
        6'b1111_01: bg=4'b0010;
        6'b1111_10: bg=4'b0100;
        6'b1111_11: bg=4'b1000;
    endcase
end

endmodule