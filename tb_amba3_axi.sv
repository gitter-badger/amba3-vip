/*==============================================================================

The MIT License (MIT)

Copyright (c) 2014 Luuvish Hwang

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

================================================================================

    File         : tb_amba3_axi.sv
    Author(s)    : luuvish (github.com/luuvish/amba3-vip)
    Modifier     : luuvish (luuvish@gmail.com)
    Descriptions : testbench for amba 3 axi

==============================================================================*/

`timescale 1ns/10ps

module tb_amba3_axi;

  import pkg_amba3::*;

  localparam integer ACLK_PERIOD = 2; // 500Mhz -> 2ns
  localparam integer TXID_SIZE = 4, ADDR_SIZE = 32, DATA_SIZE = 128;

  typedef amba3_axi_tx_fixed_t #(
    TXID_SIZE, ADDR_SIZE, DATA_SIZE, DATA_SIZE
  ) tx_t;
  typedef logic [ADDR_SIZE - 1:0] addr_t;
  typedef logic [DATA_SIZE - 1:0] data_t;

  logic aclk;
  logic areset_n;

  amba3_axi_if #(TXID_SIZE, ADDR_SIZE, DATA_SIZE) axi (aclk, areset_n);
  amba3_axi_master_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE) master = new (axi);
  amba3_axi_slave_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE) slave = new (axi);

  initial begin
    aclk = 1'b0;
    forever aclk = #(ACLK_PERIOD/2) ~aclk;
  end

  initial begin
    areset_n = 1'b1;
    repeat (10) @(posedge aclk);
    areset_n = 1'b0;
    repeat (50) @(posedge aclk);
    areset_n = 1'b1;
  end

  initial begin
    static int count = 0;
    void'($value$plusargs("unittest=%d", count));

    if ($test$plusargs("waveform")) begin
      $shm_open("waveform");
      $shm_probe("ars");
    end

    master.start();
    slave.start();
    repeat (100) @(posedge aclk);

    if (count > 0)
      unit_test(count);
    else
      example();

    repeat (100) @(posedge aclk);
    $finish;
  end

  task example ();
    if ($test$plusargs("verbose")) begin
      $display("axi example test start");
    end

    master.ticks(1);

    example_burst_types();
    example_burst_fixed();
    example_burst_incr();
    example_burst_wrap();

    if ($test$plusargs("verbose")) begin
      $display("axi example test done");
    end
  endtask

  task example_burst_types ();
    amba3_axi_tx_incr_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE,  8) incr_1b;
    amba3_axi_tx_incr_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE, 32) incr_4b;
    amba3_axi_tx_incr_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE, 64) incr_8b;
    amba3_axi_tx_wrap_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE, 32) wrap_4b;
    amba3_axi_tx_fixed_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE, 8) fixed_1b;

    incr_1b  = new (tx_t::WRITE, 'h0100, '{'h07, 'h15, 'h23, 'h31, 'h39});
    incr_4b  = new (tx_t::WRITE, 'h0104, '{'h4739, 'h7163, 'hA395, 'h1507});
    incr_8b  = new (tx_t::WRITE, 'h0201, '{'h332211, 'h77665544, 'h76543210});
    wrap_4b  = new (tx_t::WRITE, 'h0704, '{'h2211, 'h7766, 'h5432, 'h7123});
    fixed_1b = new (tx_t::WRITE, 'h0106, '{'h07, 'h15, 'h23, 'h31, 'h39});

    assert(incr_1b.data[0].data == 128'h0000_0000_0000_0007);
    assert(incr_1b.data[0].strb == 16'h0001);
    assert(incr_1b.data[0].last == 1'b0);
    assert(incr_1b.data[1].data == 128'h0000_0000_0000_1500);
    assert(incr_1b.data[1].strb == 16'h0002);
    assert(incr_1b.data[1].last == 1'b0);
    assert(incr_1b.data[2].data == 128'h0000_0000_0023_0000);
    assert(incr_1b.data[2].strb == 16'h0004);
    assert(incr_1b.data[2].last == 1'b0);
    assert(incr_1b.data[3].data == 128'h0000_0000_3100_0000);
    assert(incr_1b.data[3].strb == 16'h0008);
    assert(incr_1b.data[3].last == 1'b0);
    assert(incr_1b.data[4].data == 128'h0000_0039_0000_0000);
    assert(incr_1b.data[4].strb == 16'h0010);
    assert(incr_1b.data[4].last == 1'b1);

    assert(incr_4b.data[0].data == 128'h0000_0000_0000_0000_4739_0000_0000);
    assert(incr_4b.data[0].strb == 16'h00f0);
    assert(incr_4b.data[0].last == 1'b0);
    assert(incr_4b.data[1].data == 128'h0000_0000_7163_0000_0000_0000_0000);
    assert(incr_4b.data[1].strb == 16'h0f00);
    assert(incr_4b.data[1].last == 1'b0);
    assert(incr_4b.data[2].data == 128'ha395_0000_0000_0000_0000_0000_0000);
    assert(incr_4b.data[2].strb == 16'hf000);
    assert(incr_4b.data[2].last == 1'b0);
    assert(incr_4b.data[3].data == 128'h0000_0000_0000_0000_0000_0000_1507);
    assert(incr_4b.data[3].strb == 16'h000f);
    assert(incr_4b.data[3].last == 1'b1);

    assert(incr_8b.data[0].data == 128'h0000_0000_0000_0000_0000_3322_1100);
    assert(incr_8b.data[0].strb == 16'h00fe);
    assert(incr_8b.data[0].last == 1'b0);
    assert(incr_8b.data[1].data == 128'h0000_7766_5544_0000_0000_0000_0000);
    assert(incr_8b.data[1].strb == 16'hff00);
    assert(incr_8b.data[1].last == 1'b0);
    assert(incr_8b.data[2].data == 128'h0000_0000_0000_0000_0000_7654_3210);
    assert(incr_8b.data[2].strb == 16'h00ff);
    assert(incr_8b.data[2].last == 1'b1);

    assert(wrap_4b.data[0].data == 128'h0000_0000_0000_0000_2211_0000_0000);
    assert(wrap_4b.data[0].strb == 16'h00f0);
    assert(wrap_4b.data[0].last == 1'b0);
    assert(wrap_4b.data[1].data == 128'h0000_0000_7766_0000_0000_0000_0000);
    assert(wrap_4b.data[1].strb == 16'h0f00);
    assert(wrap_4b.data[1].last == 1'b0);
    assert(wrap_4b.data[2].data == 128'h5432_0000_0000_0000_0000_0000_0000);
    assert(wrap_4b.data[2].strb == 16'hf000);
    assert(wrap_4b.data[2].last == 1'b0);
    assert(wrap_4b.data[3].data == 128'h0000_0000_0000_0000_0000_0000_7123);
    assert(wrap_4b.data[3].strb == 16'h000f);
    assert(wrap_4b.data[3].last == 1'b1);

    assert(fixed_1b.data[0].data == 128'h0007_0000_0000_0000);
    assert(fixed_1b.data[0].strb == 16'h0040);
    assert(fixed_1b.data[0].last == 1'b0);
    assert(fixed_1b.data[1].data == 128'h0015_0000_0000_0000);
    assert(fixed_1b.data[1].strb == 16'h0040);
    assert(fixed_1b.data[1].last == 1'b0);
    assert(fixed_1b.data[2].data == 128'h0023_0000_0000_0000);
    assert(fixed_1b.data[2].strb == 16'h0040);
    assert(fixed_1b.data[2].last == 1'b0);
    assert(fixed_1b.data[3].data == 128'h0031_0000_0000_0000);
    assert(fixed_1b.data[3].strb == 16'h0040);
    assert(fixed_1b.data[3].last == 1'b0);
    assert(fixed_1b.data[4].data == 128'h0039_0000_0000_0000);
    assert(fixed_1b.data[4].strb == 16'h0040);
    assert(fixed_1b.data[4].last == 1'b1);

    master.write(incr_1b);
    master.write(incr_4b);
    master.write(incr_8b);
    master.write(wrap_4b);
    master.write(fixed_1b, 1'b1);

    incr_1b  = new (tx_t::READ, 'h0100, , 5);
    incr_4b  = new (tx_t::READ, 'h0104, , 4);
    incr_8b  = new (tx_t::READ, 'h0201, , 3);
    wrap_4b  = new (tx_t::READ, 'h0704, , 4);
    fixed_1b = new (tx_t::READ, 'h0106, , 5);

    master.read(incr_1b);
    master.read(incr_4b);
    master.read(incr_8b);
    master.read(wrap_4b);
    master.read(fixed_1b, 1'b1);
  endtask

  task example_burst_fixed ();
    typedef amba3_axi_tx_fixed_t #(
      TXID_SIZE, ADDR_SIZE, DATA_SIZE, DATA_SIZE
    ) tx_t;
    tx_t tx [4];

    tx[0] = new (tx_t::WRITE, 'h0010, '{'h11, 'h12, 'h13, 'h14});
    tx[1] = new (tx_t::WRITE, 'h0020, '{'h21, 'h22, 'h23, 'h24});
    tx[2] = new (tx_t::WRITE, 'h0030, '{'h31, 'h32, 'h33, 'h34});
    tx[3] = new (tx_t::WRITE, 'h0040, '{'h41, 'h42, 'h43, 'h44});
    master.write(tx[0]);
    master.ticks(random_delay());
    master.write(tx[1]);
    master.write(tx[2]);
    master.write(tx[3], 1'b1);
    master.ticks(random_delay());

    tx[0] = new (tx_t::READ, 'h0010, , 4);
    tx[1] = new (tx_t::READ, 'h0020, , 4);
    tx[2] = new (tx_t::READ, 'h0030, , 4);
    tx[3] = new (tx_t::READ, 'h0040, , 4);
    master.read(tx[0]);
    master.ticks(random_delay());
    master.read(tx[2]);
    master.read(tx[3]);
    master.read(tx[1], 1'b1);
    master.ticks(random_delay());

    assert(tx[0].data[0].data == 'h11);
    assert(tx[0].data[1].data == 'h12);
    assert(tx[0].data[2].data == 'h13);
    assert(tx[0].data[3].data == 'h14);
    assert(tx[1].data[0].data == 'h21);
    assert(tx[1].data[1].data == 'h22);
    assert(tx[1].data[2].data == 'h23);
    assert(tx[1].data[3].data == 'h24);
    assert(tx[2].data[0].data == 'h31);
    assert(tx[2].data[1].data == 'h32);
    assert(tx[2].data[2].data == 'h33);
    assert(tx[2].data[3].data == 'h34);
    assert(tx[3].data[0].data == 'h41);
    assert(tx[3].data[1].data == 'h42);
    assert(tx[3].data[2].data == 'h43);
    assert(tx[3].data[3].data == 'h44);
  endtask

  task example_burst_incr ();
    typedef amba3_axi_tx_incr_t #(
      TXID_SIZE, ADDR_SIZE, DATA_SIZE, DATA_SIZE
    ) tx_t;
    tx_t tx [4];

    tx[0] = new (tx_t::WRITE, 'h0010, '{'h11, 'h12, 'h13, 'h14});
    tx[1] = new (tx_t::WRITE, 'h0050, '{'h21, 'h22, 'h23, 'h24});
    tx[2] = new (tx_t::WRITE, 'h0090, '{'h31, 'h32, 'h33, 'h34});
    tx[3] = new (tx_t::WRITE, 'h00D0, '{'h41, 'h42, 'h43, 'h44});
    master.write(tx[0]);
    master.ticks(random_delay());
    master.write(tx[1]);
    master.write(tx[2]);
    master.write(tx[3], 1'b1);
    master.ticks(random_delay());

    tx[0] = new (tx_t::READ, 'h0010, , 4);
    tx[1] = new (tx_t::READ, 'h0050, , 4);
    tx[2] = new (tx_t::READ, 'h0090, , 4);
    tx[3] = new (tx_t::READ, 'h00D0, , 4);
    master.read(tx[0]);
    master.ticks(random_delay());
    master.read(tx[2]);
    master.read(tx[3]);
    master.read(tx[1], 1'b1);
    master.ticks(random_delay());

    assert(tx[0].data[0].data == 'h11);
    assert(tx[0].data[1].data == 'h12);
    assert(tx[0].data[2].data == 'h13);
    assert(tx[0].data[3].data == 'h14);
    assert(tx[1].data[0].data == 'h21);
    assert(tx[1].data[1].data == 'h22);
    assert(tx[1].data[2].data == 'h23);
    assert(tx[1].data[3].data == 'h24);
    assert(tx[2].data[0].data == 'h31);
    assert(tx[2].data[1].data == 'h32);
    assert(tx[2].data[2].data == 'h33);
    assert(tx[2].data[3].data == 'h34);
    assert(tx[3].data[0].data == 'h41);
    assert(tx[3].data[1].data == 'h42);
    assert(tx[3].data[2].data == 'h43);
    assert(tx[3].data[3].data == 'h44);
  endtask

  task example_burst_wrap ();
    typedef amba3_axi_tx_wrap_t #(
      TXID_SIZE, ADDR_SIZE, DATA_SIZE, 16
    ) tx_t;
    tx_t tx [4];

    tx[0] = new (tx_t::WRITE, 'h0210, '{'h11, 'h12, 'h13, 'h14});
    tx[1] = new (tx_t::WRITE, 'h021C, '{'h21, 'h22, 'h23, 'h24});
    tx[2] = new (tx_t::WRITE, 'h0280, '{'h31, 'h32, 'h33, 'h34});
    tx[3] = new (tx_t::WRITE, 'h0322, '{'h41, 'h42, 'h43, 'h44});
    master.write(tx[0]);
    master.ticks(random_delay());
    master.write(tx[1]);
    master.write(tx[2]);
    master.write(tx[3], 1'b1);
    master.ticks(random_delay());

    tx[0] = new (tx_t::READ, 'h0210, , 4);
    tx[1] = new (tx_t::READ, 'h021A, , 4);
    tx[2] = new (tx_t::READ, 'h0286, , 4);
    tx[3] = new (tx_t::READ, 'h0320, , 4);
    master.read(tx[0]);
    master.ticks(random_delay());
    master.read(tx[2]);
    master.read(tx[3]);
    master.read(tx[1], 1'b1);
    master.ticks(random_delay());

    assert(tx[0].data[0].data[ 15:  0] == 'h11);
    assert(tx[0].data[1].data[ 31: 16] == 'h12);
    assert(tx[0].data[2].data[ 47: 32] == 'h13);
    assert(tx[0].data[3].data[ 63: 48] == 'h14);
    assert(tx[1].data[0].data[ 95: 80] == 'h24);
    assert(tx[1].data[1].data[111: 96] == 'h21);
    assert(tx[1].data[2].data[127:112] == 'h22);
    assert(tx[1].data[3].data[ 79: 64] == 'h23);
    assert(tx[2].data[0].data[ 63: 48] == 'h34);
    assert(tx[2].data[1].data[ 15:  0] == 'h31);
    assert(tx[2].data[2].data[ 31: 16] == 'h32);
    assert(tx[2].data[3].data[ 47: 32] == 'h33);
    assert(tx[3].data[0].data[ 15:  0] == 'h44);
    assert(tx[3].data[1].data[ 31: 16] == 'h41);
    assert(tx[3].data[2].data[ 47: 32] == 'h42);
    assert(tx[3].data[3].data[ 63: 48] == 'h43);
  endtask

  task unit_test (int count);

    if ($test$plusargs("verbose")) begin
      $display("axi unittest start");
    end

    repeat (count) begin
    end

    if ($test$plusargs("verbose")) begin
      $display("axi unittest %0d done", count);
    end
  endtask

  function automatic int random_delay ();
    return $urandom_range(0, 1) ? 0 : $urandom_range(1, 10);
  endfunction

endmodule
