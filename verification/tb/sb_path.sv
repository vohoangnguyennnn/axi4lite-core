// Scoreboard for one request/response path: four in-order channels comparing
// the transactions observed at the two ends of the design under test.
module sb_path
  import axi4lite_tb_pkg::*;
(
  input  logic        clk,
  input  logic        rstn,

  input  logic        a_wr_req_evt,
  input  txn_t        a_wr_req_txn,
  input  logic        a_wr_rsp_evt,
  input  txn_t        a_wr_rsp_txn,
  input  logic        a_rd_req_evt,
  input  txn_t        a_rd_req_txn,
  input  logic        a_rd_rsp_evt,
  input  txn_t        a_rd_rsp_txn,

  input  logic        b_wr_req_evt,
  input  txn_t        b_wr_req_txn,
  input  logic        b_wr_rsp_evt,
  input  txn_t        b_wr_rsp_txn,
  input  logic        b_rd_req_evt,
  input  txn_t        b_rd_req_txn,
  input  logic        b_rd_rsp_evt,
  input  txn_t        b_rd_rsp_txn,

  output logic        empty,
  output int unsigned wr_matched,
  output int unsigned rd_matched
);

  logic        wr_req_empty;
  logic        wr_rsp_empty;
  logic        rd_req_empty;
  logic        rd_rsp_empty;
  // Request match counts are not reported; responses are the completion
  // measure used by tb_end_check.
  /* verilator lint_off UNUSEDSIGNAL */
  int unsigned wr_req_matched;
  int unsigned rd_req_matched;
  /* verilator lint_on UNUSEDSIGNAL */

  sb_channel #(.NAME("write request")) u_wr_req (
    .clk, .rstn,
    .a_evt(a_wr_req_evt), .a_txn(a_wr_req_txn),
    .b_evt(b_wr_req_evt), .b_txn(b_wr_req_txn),
    .matched(wr_req_matched), .empty(wr_req_empty)
  );

  sb_channel #(.NAME("write response")) u_wr_rsp (
    .clk, .rstn,
    .a_evt(a_wr_rsp_evt), .a_txn(a_wr_rsp_txn),
    .b_evt(b_wr_rsp_evt), .b_txn(b_wr_rsp_txn),
    .matched(wr_matched), .empty(wr_rsp_empty)
  );

  sb_channel #(.NAME("read request")) u_rd_req (
    .clk, .rstn,
    .a_evt(a_rd_req_evt), .a_txn(a_rd_req_txn),
    .b_evt(b_rd_req_evt), .b_txn(b_rd_req_txn),
    .matched(rd_req_matched), .empty(rd_req_empty)
  );

  sb_channel #(.NAME("read response")) u_rd_rsp (
    .clk, .rstn,
    .a_evt(a_rd_rsp_evt), .a_txn(a_rd_rsp_txn),
    .b_evt(b_rd_rsp_evt), .b_txn(b_rd_rsp_txn),
    .matched(rd_matched), .empty(rd_rsp_empty)
  );

  assign empty = wr_req_empty && wr_rsp_empty && rd_req_empty && rd_rsp_empty;

endmodule
