module native_req_rsp_checker (
  native_req_rsp_if.monitor native
);

  import axi4lite_pkg::*;

  logic wr_req_hs;
  logic wr_rsp_hs;
  logic rd_req_hs;
  logic rd_rsp_hs;

  logic wr_outstanding_q;
  logic rd_outstanding_q;

  assign wr_req_hs = native.wr_req_valid && native.wr_req_ready;
  assign wr_rsp_hs = native.wr_rsp_valid && native.wr_rsp_ready;
  assign rd_req_hs = native.rd_req_valid && native.rd_req_ready;
  assign rd_rsp_hs = native.rd_rsp_valid && native.rd_rsp_ready;

  // Native transaction ownership starts at the request handshake and ends at
  // the matching response handshake. Read and write contexts are independent.
  always_ff @(posedge native.ACLK) begin
    if (!native.ARESETn) begin
      wr_outstanding_q <= 1'b0;
      rd_outstanding_q <= 1'b0;
    end else begin
      if (wr_rsp_hs) begin
        wr_outstanding_q <= 1'b0;
      end else if (wr_req_hs) begin
        wr_outstanding_q <= 1'b1;
      end

      if (rd_rsp_hs) begin
        rd_outstanding_q <= 1'b0;
      end else if (rd_req_hs) begin
        rd_outstanding_q <= 1'b1;
      end
    end
  end

  // ------------------------------------------------------------------------
  // Native channel source persistence
  // ------------------------------------------------------------------------

  // Use one-cycle $past comparisons for compatibility with the project's
  // open-source simulation flow. A stalled source retains VALID and payload.
  a_native_wr_req_stable: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      $past(native.wr_req_valid && !native.wr_req_ready)
      |-> native.wr_req_valid &&
          (native.wr_req_addr == $past(native.wr_req_addr)) &&
          (native.wr_req_data == $past(native.wr_req_data)) &&
          (native.wr_req_strb == $past(native.wr_req_strb)) &&
          (native.wr_req_prot == $past(native.wr_req_prot))
  ) else $error("Native write request source changed VALID/payload while stalled");

  a_native_wr_rsp_stable: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      $past(native.wr_rsp_valid && !native.wr_rsp_ready)
      |-> native.wr_rsp_valid &&
          (native.wr_rsp_resp == $past(native.wr_rsp_resp))
  ) else $error("Native write response source changed VALID/payload while stalled");

  a_native_rd_req_stable: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      $past(native.rd_req_valid && !native.rd_req_ready)
      |-> native.rd_req_valid &&
          (native.rd_req_addr == $past(native.rd_req_addr)) &&
          (native.rd_req_prot == $past(native.rd_req_prot))
  ) else $error("Native read request source changed VALID/payload while stalled");

  a_native_rd_rsp_stable: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      $past(native.rd_rsp_valid && !native.rd_rsp_ready)
      |-> native.rd_rsp_valid &&
          (native.rd_rsp_data == $past(native.rd_rsp_data)) &&
          (native.rd_rsp_resp == $past(native.rd_rsp_resp))
  ) else $error("Native read response source changed VALID/payload while stalled");

  // ------------------------------------------------------------------------
  // Native request/response ordering and response profile
  // ------------------------------------------------------------------------

  // The registered context deliberately excludes a request accepted on the
  // current edge. This rejects zero-cycle combinational responses as required
  // by the v1 native protocol contract.
  a_native_wr_rsp_has_request: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.wr_rsp_valid |-> wr_outstanding_q
  ) else $error("Native write response asserted without an accepted request");

  a_native_rd_rsp_has_request: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.rd_rsp_valid |-> rd_outstanding_q
  ) else $error("Native read response asserted without an accepted request");

  a_native_wr_rsp_not_reserved: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.wr_rsp_valid |-> native.wr_rsp_resp != native_resp_e'(2'b01)
  ) else $error("Native write response used reserved encoding 2'b01");

  a_native_rd_rsp_not_reserved: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.rd_rsp_valid |-> native.rd_rsp_resp != native_resp_e'(2'b01)
  ) else $error("Native read response used reserved encoding 2'b01");

  // ------------------------------------------------------------------------
  // Project depth-one transaction profile
  // ------------------------------------------------------------------------

  // Together with response-context and source-persistence assertions, these
  // properties enforce at most one request and one response per direction.
  // Eventual response delivery is intentionally not bounded: legal
  // backpressure can last for any number of cycles.
  a_native_no_second_wr_req: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      wr_req_hs |-> !wr_outstanding_q
  ) else $error("Native protocol accepted a second outstanding write request");

  a_native_no_second_rd_req: assert property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      rd_req_hs |-> !rd_outstanding_q
  ) else $error("Native protocol accepted a second outstanding read request");

  // ------------------------------------------------------------------------
  // Deterministic project reset contract
  // ------------------------------------------------------------------------

  // These properties remain active in reset so they check, rather than
  // disable, the deterministic reset policy defined by the project scope.
  a_project_reset_valid_low: assert property (
    @(posedge native.ACLK)
      !native.ARESETn
      |-> !native.wr_req_valid &&
          !native.wr_rsp_valid &&
          !native.rd_req_valid &&
          !native.rd_rsp_valid
  ) else $error("Native VALID observed high during reset");

  a_project_reset_ready_low: assert property (
    @(posedge native.ACLK)
      !native.ARESETn
      |-> !native.wr_req_ready &&
          !native.wr_rsp_ready &&
          !native.rd_req_ready &&
          !native.rd_rsp_ready
  ) else $error("Native READY observed high during reset");

  a_project_reset_clears_context: assert property (
    @(posedge native.ACLK)
      $past(!native.ARESETn) && native.ARESETn
      |-> !wr_outstanding_q && !rd_outstanding_q
  ) else $error("Native transaction context survived reset");

  // ------------------------------------------------------------------------
  // Coverage for legal backpressure and read/write concurrency
  // ------------------------------------------------------------------------

  c_native_wr_req_backpressure: cover property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.wr_req_valid && !native.wr_req_ready
  );

  c_native_wr_rsp_backpressure: cover property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.wr_rsp_valid && !native.wr_rsp_ready
  );

  c_native_rd_req_backpressure: cover property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.rd_req_valid && !native.rd_req_ready
  );

  c_native_rd_rsp_backpressure: cover property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      native.rd_rsp_valid && !native.rd_rsp_ready
  );

  c_native_concurrent_read_write: cover property (
    @(posedge native.ACLK) disable iff (!native.ARESETn)
      (wr_req_hs || wr_outstanding_q) &&(rd_req_hs || rd_outstanding_q)
  );

endmodule
