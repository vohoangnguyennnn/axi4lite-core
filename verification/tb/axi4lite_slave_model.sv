// Random AXI4-Lite slave.
//
// READY signals toggle randomly and independently, so AW and W are accepted
// in any order. Up to three halves of each kind are buffered. BVALID and
// RVALID are raised at least one edge after the handshakes they depend on,
// with random OKAY/SLVERR/DECERR responses (never EXOKAY).
//
// Plusargs: +READY_RATE (% chance per cycle that a READY is high, default
// 50), +RSP_RATE (% chance per cycle to start a pending response, default
// 50), +ERR_RATE (% of responses that are errors, default 20).
module axi4lite_slave_model
  import axi4lite_pkg::*;
  import axi4lite_tb_pkg::*;
(
  axi4lite_if.slave axi
);

  localparam int unsigned DEPTH = 3;

  int unsigned ready_rate;
  int unsigned rsp_rate;
  int unsigned err_rate;

  // Accepted halves not yet answered.
  int unsigned aw_cnt;
  int unsigned w_cnt;
  int unsigned ar_cnt;

  initial begin
    ready_rate = plusarg_int("READY_RATE", 50);
    rsp_rate   = plusarg_int("RSP_RATE", 50);
    err_rate   = plusarg_int("ERR_RATE", 20);
  end

  function automatic logic [1:0] random_resp();
    if (!chance(err_rate)) return AXI_RESP_OKAY;
    return chance(50) ? AXI_RESP_SLVERR : AXI_RESP_DECERR;
  endfunction

  always @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      aw_cnt      = 0;
      w_cnt       = 0;
      ar_cnt      = 0;
      axi.AWREADY <= 1'b0;
      axi.WREADY  <= 1'b0;
      axi.BRESP   <= AXI_RESP_OKAY;
      axi.BVALID  <= 1'b0;
      axi.ARREADY <= 1'b0;
      axi.RDATA   <= '0;
      axi.RRESP   <= AXI_RESP_OKAY;
      axi.RVALID  <= 1'b0;
    end else begin
      if (axi.AWVALID && axi.AWREADY) aw_cnt++;
      if (axi.WVALID  && axi.WREADY)  w_cnt++;
      if (axi.ARVALID && axi.ARREADY) ar_cnt++;

      // Write response
      if (axi.BVALID && axi.BREADY) begin
        aw_cnt--;
        w_cnt--;
        axi.BVALID <= 1'b0;
      end else if (!axi.BVALID && (aw_cnt != 0) && (w_cnt != 0) &&
                   chance(rsp_rate)) begin
        axi.BVALID <= 1'b1;
        axi.BRESP  <= random_resp();
      end

      // Read response
      if (axi.RVALID && axi.RREADY) begin
        ar_cnt--;
        axi.RVALID <= 1'b0;
      end else if (!axi.RVALID && (ar_cnt != 0) && chance(rsp_rate)) begin
        axi.RVALID <= 1'b1;
        axi.RDATA  <= {$urandom, $urandom};
        axi.RRESP  <= random_resp();
      end

      axi.AWREADY <= (aw_cnt < DEPTH) && chance(ready_rate);
      axi.WREADY  <= (w_cnt  < DEPTH) && chance(ready_rate);
      axi.ARREADY <= (ar_cnt < DEPTH) && chance(ready_rate);
    end
  end

endmodule
