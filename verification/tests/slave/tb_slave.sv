// Slave adapter bench: random AXI4-Lite master -> axi4lite_slave_adapter
// -> random native target. The scoreboard compares AXI transactions with the
// native transactions they produce.
module tb_slave
  import axi4lite_tb_pkg::*;
#(
  parameter int unsigned DATA_WIDTH = 32
);

  logic clk;
  logic rstn;

  tb_clock_reset u_clock_reset (.clk, .rstn);

  native_req_rsp_if #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) native (clk, rstn);
  axi4lite_if       #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) axi    (clk, rstn);

  axi4lite_slave_adapter #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) dut (
    .s_axi(axi), .native(native)
  );

  logic done;

  axi4lite_master_driver u_master (.axi(axi), .done(done));
  native_target_model    u_target (.native(native));

  axi4lite_protocol_checker #(.DATA_WIDTH(DATA_WIDTH)) u_axi_checker (.axi(axi));
  native_req_rsp_checker u_native_checker (.native(native));

  logic n_wr_req_evt, n_wr_rsp_evt, n_rd_req_evt, n_rd_rsp_evt;
  txn_t n_wr_req_txn, n_wr_rsp_txn, n_rd_req_txn, n_rd_rsp_txn;
  logic a_wr_req_evt, a_wr_rsp_evt, a_rd_req_evt, a_rd_rsp_evt;
  txn_t a_wr_req_txn, a_wr_rsp_txn, a_rd_req_txn, a_rd_rsp_txn;

  native_monitor u_native_monitor (
    .native(native),
    .wr_req_evt(n_wr_req_evt), .wr_req_txn(n_wr_req_txn),
    .wr_rsp_evt(n_wr_rsp_evt), .wr_rsp_txn(n_wr_rsp_txn),
    .rd_req_evt(n_rd_req_evt), .rd_req_txn(n_rd_req_txn),
    .rd_rsp_evt(n_rd_rsp_evt), .rd_rsp_txn(n_rd_rsp_txn)
  );

  axi4lite_monitor u_axi_monitor (
    .axi(axi),
    .wr_req_evt(a_wr_req_evt), .wr_req_txn(a_wr_req_txn),
    .wr_rsp_evt(a_wr_rsp_evt), .wr_rsp_txn(a_wr_rsp_txn),
    .rd_req_evt(a_rd_req_evt), .rd_req_txn(a_rd_req_txn),
    .rd_rsp_evt(a_rd_rsp_evt), .rd_rsp_txn(a_rd_rsp_txn)
  );

  logic        sb_empty;
  int unsigned wr_matched;
  int unsigned rd_matched;

  sb_path u_scoreboard (
    .clk, .rstn,
    .a_wr_req_evt(a_wr_req_evt), .a_wr_req_txn(a_wr_req_txn),
    .a_wr_rsp_evt(a_wr_rsp_evt), .a_wr_rsp_txn(a_wr_rsp_txn),
    .a_rd_req_evt(a_rd_req_evt), .a_rd_req_txn(a_rd_req_txn),
    .a_rd_rsp_evt(a_rd_rsp_evt), .a_rd_rsp_txn(a_rd_rsp_txn),
    .b_wr_req_evt(n_wr_req_evt), .b_wr_req_txn(n_wr_req_txn),
    .b_wr_rsp_evt(n_wr_rsp_evt), .b_wr_rsp_txn(n_wr_rsp_txn),
    .b_rd_req_evt(n_rd_req_evt), .b_rd_req_txn(n_rd_req_txn),
    .b_rd_rsp_evt(n_rd_rsp_evt), .b_rd_rsp_txn(n_rd_rsp_txn),
    .empty(sb_empty), .wr_matched(wr_matched), .rd_matched(rd_matched)
  );

  tb_end_check #(.NAME("slave")) u_end_check (
    .clk, .done, .empty(sb_empty), .wr_matched, .rd_matched
  );

endmodule
