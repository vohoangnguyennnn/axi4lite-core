// End-of-test check shared by the regression benches.
//
// Once the stimulus reports done, waits for in-flight events to settle, then
// requires every scoreboard queue to be empty and at least +NUM_TXN write and
// read responses to have been matched. Prints "TEST PASS" and finishes.
module tb_end_check
  import axi4lite_tb_pkg::*;
#(
  parameter string NAME = "test"
) (
  input logic        clk,
  input logic        done,
  input logic        empty,
  input int unsigned wr_matched,
  input int unsigned rd_matched
);

  int unsigned num_txn;

  initial begin
    num_txn = plusarg_int("NUM_TXN", 500);
    wait (done);
    repeat (20) @(posedge clk);

    if (!empty) begin
      $fatal(1, "%s: scoreboard not empty at end of test", NAME);
    end
    if ((wr_matched < num_txn) || (rd_matched < num_txn)) begin
      $fatal(1, "%s: matched %0d writes and %0d reads, expected at least %0d each",
             NAME, wr_matched, rd_matched, num_txn);
    end

    $display("TEST PASS: %s writes=%0d reads=%0d", NAME, wr_matched, rd_matched);
    $finish;
  end

endmodule
