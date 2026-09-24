// Clock, reset, and watchdog for the regression benches.
//
// Reset is asserted for the first cycles of simulation and, when +RESET_AT=<n>
// is given, again for +RESET_LEN (default 5) cycles starting at cycle n. The
// mid-run reset is applied asynchronously (off the clock edge) and released on
// a falling edge, i.e. synchronously to the next rising edge. +TIMEOUT
// (default 500000 cycles) ends a hung run.
module tb_clock_reset
  import axi4lite_tb_pkg::*;
(
  output logic clk,
  output logic rstn
);

  int unsigned reset_at;
  int unsigned reset_len;
  int unsigned timeout;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    reset_at  = plusarg_int("RESET_AT", 0);
    reset_len = plusarg_int("RESET_LEN", 5);
    timeout   = plusarg_int("TIMEOUT", 500000);

    rstn = 1'b0;
    repeat (5) @(negedge clk);
    rstn = 1'b1;

    if (reset_at != 0) begin
      repeat (reset_at) @(posedge clk);
      #2 rstn = 1'b0;
      repeat (reset_len) @(negedge clk);
      rstn = 1'b1;
      $display("[%0t] mid-run reset applied at cycle %0d", $time, reset_at);
    end
  end

  initial begin
    repeat (timeout) @(posedge clk);
    $fatal(1, "watchdog: test did not finish within %0d cycles", timeout);
  end

endmodule
