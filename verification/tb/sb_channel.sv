// In-order scoreboard for one transaction stream.
//
// The "a" and "b" sides are the two ends of the path under test (for example
// native request in and AXI request out). Every transaction seen on one side
// must appear on the other side, unchanged and in the same order. Either side
// may be observed first. Both queues are flushed by reset, which discards
// transactions that the design under test also discards.
module sb_channel
  import axi4lite_tb_pkg::*;
#(
  parameter string NAME = "channel"
) (
  input  logic        clk,
  input  logic        rstn,
  input  logic        a_evt,
  input  txn_t        a_txn,
  input  logic        b_evt,
  input  txn_t        b_txn,
  output int unsigned matched,
  output logic        empty
);

  txn_t a_q[$];
  txn_t b_q[$];

  initial matched = 0;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      a_q.delete();
      b_q.delete();
    end else begin
      if (a_evt) a_q.push_back(a_txn);
      if (b_evt) b_q.push_back(b_txn);

      while ((a_q.size() != 0) && (b_q.size() != 0)) begin
        txn_t a;
        txn_t b;
        a = a_q.pop_front();
        b = b_q.pop_front();
        if (a !== b) begin
          $error("[%s] mismatch after %0d matches\n  a: %s\n  b: %s",
                 NAME, matched, txn_str(a), txn_str(b));
        end
        matched = matched + 1;
      end
    end
  end

  assign empty = (a_q.size() == 0) && (b_q.size() == 0);

endmodule
