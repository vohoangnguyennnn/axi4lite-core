// Random native requester.
//
// Issues random write and read requests until NUM_TXN of each have completed
// with a response handshake. Requests lost to a mid-run reset are reissued.
//
// Plusargs: +NUM_TXN (default 500), +REQ_RATE (% chance per idle cycle to
// raise a request, default 50), +RSP_READY_RATE (% chance per cycle that a
// response ready is high, default 50).
module native_requester_driver
  import axi4lite_tb_pkg::*;
(
  native_req_rsp_if.requester native,
  output logic               done
);

  int unsigned num_txn;
  int unsigned req_rate;
  int unsigned rsp_ready_rate;

  // Completed transactions survive reset; in-flight ones do not.
  int unsigned wr_done_cnt;
  int unsigned rd_done_cnt;
  logic        wr_accepted;
  logic        rd_accepted;

  initial begin
    num_txn        = plusarg_int("NUM_TXN", 500);
    req_rate       = plusarg_int("REQ_RATE", 50);
    rsp_ready_rate = plusarg_int("RSP_READY_RATE", 50);
    wr_done_cnt    = 0;
    rd_done_cnt    = 0;
  end

  assign done = (wr_done_cnt >= num_txn) && (rd_done_cnt >= num_txn);

  always @(posedge native.ACLK or negedge native.ARESETn) begin
    if (!native.ARESETn) begin
      native.wr_req_addr  <= '0;
      native.wr_req_data  <= '0;
      native.wr_req_strb  <= '0;
      native.wr_req_prot  <= '0;
      native.wr_req_valid <= 1'b0;
      native.wr_rsp_ready <= 1'b0;
      native.rd_req_addr  <= '0;
      native.rd_req_prot  <= '0;
      native.rd_req_valid <= 1'b0;
      native.rd_rsp_ready <= 1'b0;
      wr_accepted         <= 1'b0;
      rd_accepted         <= 1'b0;
    end else begin
      // Write request: hold VALID and payload until accepted.
      if (native.wr_req_valid && native.wr_req_ready) begin
        native.wr_req_valid <= 1'b0;
        wr_accepted         <= 1'b1;
      end else if (!native.wr_req_valid && !wr_accepted &&
                   (wr_done_cnt < num_txn) && chance(req_rate)) begin
        native.wr_req_valid <= 1'b1;
        native.wr_req_addr  <= $urandom;
        native.wr_req_data  <= {$urandom, $urandom};
        native.wr_req_strb  <= $urandom;
        native.wr_req_prot  <= $urandom;
      end

      native.wr_rsp_ready <= chance(rsp_ready_rate);
      if (native.wr_rsp_valid && native.wr_rsp_ready) begin
        wr_accepted <= 1'b0;
        wr_done_cnt <= wr_done_cnt + 1;
      end

      // Read request.
      if (native.rd_req_valid && native.rd_req_ready) begin
        native.rd_req_valid <= 1'b0;
        rd_accepted         <= 1'b1;
      end else if (!native.rd_req_valid && !rd_accepted &&
                   (rd_done_cnt < num_txn) && chance(req_rate)) begin
        native.rd_req_valid <= 1'b1;
        native.rd_req_addr  <= $urandom;
        native.rd_req_prot  <= $urandom;
      end

      native.rd_rsp_ready <= chance(rsp_ready_rate);
      if (native.rd_rsp_valid && native.rd_rsp_ready) begin
        rd_accepted <= 1'b0;
        rd_done_cnt <= rd_done_cnt + 1;
      end
    end
  end

endmodule
