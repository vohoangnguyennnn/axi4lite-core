// End-to-end bench: random native requester -> axi4lite_master_adapter ->
// AXI4-Lite -> axi4lite_slave_adapter -> random native target. The scoreboard
// compares the native transactions at both ends; the AXI bus in the middle is
// covered by the protocol checker.
module tb_loopback
  import axi4lite_tb_pkg::*;
#(
  parameter int unsigned DATA_WIDTH = 32
);

  logic clk;
  logic rstn;

  tb_clock_reset u_clock_reset (.clk, .rstn);

  native_req_rsp_if #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) native     (clk, rstn);
  axi4lite_if       #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) axi        (clk, rstn);
  native_req_rsp_if #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) native_out (clk, rstn);

  axi4lite_master_adapter #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) dut_master (
    .native(native), .m_axi(axi)
  );

  axi4lite_slave_adapter #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) dut_slave (
    .s_axi(axi), .native(native_out)
  );

  logic done;

  native_requester_driver u_requester (.native(native), .done(done));
  native_target_model     u_target    (.native(native_out));

  axi4lite_protocol_checker #(.DATA_WIDTH(DATA_WIDTH)) u_axi_checker (.axi(axi));
  native_req_rsp_checker u_native_checker     (.native(native));
  native_req_rsp_checker u_native_out_checker (.native(native_out));

  logic n_wr_req_evt, n_wr_rsp_evt, n_rd_req_evt, n_rd_rsp_evt;
  txn_t n_wr_req_txn, n_wr_rsp_txn, n_rd_req_txn, n_rd_rsp_txn;
  logic o_wr_req_evt, o_wr_rsp_evt, o_rd_req_evt, o_rd_rsp_evt;
  txn_t o_wr_req_txn, o_wr_rsp_txn, o_rd_req_txn, o_rd_rsp_txn;

  native_monitor u_native_monitor (
    .native(native),
    .wr_req_evt(n_wr_req_evt), .wr_req_txn(n_wr_req_txn),
    .wr_rsp_evt(n_wr_rsp_evt), .wr_rsp_txn(n_wr_rsp_txn),
    .rd_req_evt(n_rd_req_evt), .rd_req_txn(n_rd_req_txn),
    .rd_rsp_evt(n_rd_rsp_evt), .rd_rsp_txn(n_rd_rsp_txn)
  );

  native_monitor u_native_out_monitor (
    .native(native_out),
    .wr_req_evt(o_wr_req_evt), .wr_req_txn(o_wr_req_txn),
    .wr_rsp_evt(o_wr_rsp_evt), .wr_rsp_txn(o_wr_rsp_txn),
    .rd_req_evt(o_rd_req_evt), .rd_req_txn(o_rd_req_txn),
    .rd_rsp_evt(o_rd_rsp_evt), .rd_rsp_txn(o_rd_rsp_txn)
  );

  logic        sb_empty;
  int unsigned wr_matched;
  int unsigned rd_matched;

  sb_path u_scoreboard (
    .clk, .rstn,
    .a_wr_req_evt(n_wr_req_evt), .a_wr_req_txn(n_wr_req_txn),
    .a_wr_rsp_evt(n_wr_rsp_evt), .a_wr_rsp_txn(n_wr_rsp_txn),
    .a_rd_req_evt(n_rd_req_evt), .a_rd_req_txn(n_rd_req_txn),
    .a_rd_rsp_evt(n_rd_rsp_evt), .a_rd_rsp_txn(n_rd_rsp_txn),
    .b_wr_req_evt(o_wr_req_evt), .b_wr_req_txn(o_wr_req_txn),
    .b_wr_rsp_evt(o_wr_rsp_evt), .b_wr_rsp_txn(o_wr_rsp_txn),
    .b_rd_req_evt(o_rd_req_evt), .b_rd_req_txn(o_rd_req_txn),
    .b_rd_rsp_evt(o_rd_rsp_evt), .b_rd_rsp_txn(o_rd_rsp_txn),
    .empty(sb_empty), .wr_matched(wr_matched), .rd_matched(rd_matched)
  );

  tb_end_check #(.NAME("loopback")) u_end_check (
    .clk, .done, .empty(sb_empty), .wr_matched, .rd_matched
  );

endmodule
