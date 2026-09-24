// Random native target.
//
// Accepts one request per direction, then responds at least one cycle later
// with a random response. Obeys the native depth-one, no-zero-cycle-response
// contract checked by native_req_rsp_checker.
//
// Plusargs: +READY_RATE (% chance per cycle that request ready is high while
// idle, default 50), +RSP_RATE (% chance per cycle to start a pending
// response, default 50), +ERR_RATE (% of responses that are errors,
// default 20).
module native_target_model
  import axi4lite_pkg::*;
  import axi4lite_tb_pkg::*;
(
  native_req_rsp_if.target native
);

  int unsigned ready_rate;
  int unsigned rsp_rate;
  int unsigned err_rate;

  logic wr_pending;
  logic rd_pending;

  initial begin
    ready_rate = plusarg_int("READY_RATE", 50);
    rsp_rate   = plusarg_int("RSP_RATE", 50);
    err_rate   = plusarg_int("ERR_RATE", 20);
  end

  function automatic native_resp_e random_resp();
    if (!chance(err_rate)) return NATIVE_RESP_OKAY;
    return chance(50) ? NATIVE_RESP_TARGET_ERR : NATIVE_RESP_DECODE_ERR;
  endfunction

  always @(posedge native.ACLK or negedge native.ARESETn) begin
    if (!native.ARESETn) begin
      native.wr_req_ready <= 1'b0;
      native.wr_rsp_resp  <= NATIVE_RESP_OKAY;
      native.wr_rsp_valid <= 1'b0;
      native.rd_req_ready <= 1'b0;
      native.rd_rsp_data  <= '0;
      native.rd_rsp_resp  <= NATIVE_RESP_OKAY;
      native.rd_rsp_valid <= 1'b0;
      wr_pending          <= 1'b0;
      rd_pending          <= 1'b0;
    end else begin
      // Write
      if (native.wr_req_valid && native.wr_req_ready) begin
        wr_pending          <= 1'b1;
        native.wr_req_ready <= 1'b0;
      end else begin
        native.wr_req_ready <= !wr_pending && chance(ready_rate);
      end

      if (native.wr_rsp_valid && native.wr_rsp_ready) begin
        native.wr_rsp_valid <= 1'b0;
        wr_pending          <= 1'b0;
      end else if (wr_pending && !native.wr_rsp_valid && chance(rsp_rate)) begin
        native.wr_rsp_valid <= 1'b1;
        native.wr_rsp_resp  <= random_resp();
      end

      // Read
      if (native.rd_req_valid && native.rd_req_ready) begin
        rd_pending          <= 1'b1;
        native.rd_req_ready <= 1'b0;
      end else begin
        native.rd_req_ready <= !rd_pending && chance(ready_rate);
      end

      if (native.rd_rsp_valid && native.rd_rsp_ready) begin
        native.rd_rsp_valid <= 1'b0;
        rd_pending          <= 1'b0;
      end else if (rd_pending && !native.rd_rsp_valid && chance(rsp_rate)) begin
        native.rd_rsp_valid <= 1'b1;
        native.rd_rsp_data  <= {$urandom, $urandom};
        native.rd_rsp_resp  <= random_resp();
      end
    end
  end

endmodule
