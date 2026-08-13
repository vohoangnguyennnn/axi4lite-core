module axi4lite_protocol_checker (
  axi4lite_if.monitor axi
);

  import axi4lite_pkg::*;

  logic aw_hs;
  logic w_hs;
  logic b_hs;
  logic ar_hs;
  logic r_hs;

  logic aw_seen_q;
  logic w_seen_q;
  logic ar_seen_q;

  assign aw_hs = axi.AWVALID && axi.AWREADY;
  assign w_hs  = axi.WVALID  && axi.WREADY;
  assign b_hs  = axi.BVALID  && axi.BREADY;
  assign ar_hs = axi.ARVALID && axi.ARREADY;
  assign r_hs  = axi.RVALID  && axi.RREADY;

  // Passive transaction context for the project depth-one profile.
  // AW and W are tracked independently because either half can arrive first.
  always_ff @(posedge axi.ACLK) begin
    if (!axi.ARESETn) begin
      aw_seen_q <= 1'b0;
      w_seen_q  <= 1'b0;
      ar_seen_q <= 1'b0;
    end else begin
      if (b_hs) begin
        aw_seen_q <= 1'b0;
        w_seen_q  <= 1'b0;
      end else begin
        if (aw_hs) begin
          aw_seen_q <= 1'b1;
        end

        if (w_hs) begin
          w_seen_q <= 1'b1;
        end
      end

      if (r_hs) begin
        ar_seen_q <= 1'b0;
      end else if (ar_hs) begin
        ar_seen_q <= 1'b1;
      end
    end
  end

  // ------------------------------------------------------------------------
  // AXI channel source persistence
  // ------------------------------------------------------------------------

  // $past comparisons are equivalent to $stable for this one-cycle check and
  // remain compatible with the project's open-source Verilator flow.
  a_axi_aw_stable: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      $past(axi.AWVALID && !axi.AWREADY)
      |-> axi.AWVALID &&
          (axi.AWADDR == $past(axi.AWADDR)) &&
          (axi.AWPROT == $past(axi.AWPROT))
  ) else $error("AXI AW source changed VALID/payload while stalled");

  a_axi_w_stable: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      $past(axi.WVALID && !axi.WREADY)
      |-> axi.WVALID &&
          (axi.WDATA == $past(axi.WDATA)) &&
          (axi.WSTRB == $past(axi.WSTRB))
  ) else $error("AXI W source changed VALID/payload while stalled");

  a_axi_b_stable: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      $past(axi.BVALID && !axi.BREADY)
      |-> axi.BVALID &&
          (axi.BRESP == $past(axi.BRESP))
  ) else $error("AXI B source changed VALID/payload while stalled");

  a_axi_ar_stable: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      $past(axi.ARVALID && !axi.ARREADY)
      |-> axi.ARVALID &&
          (axi.ARADDR == $past(axi.ARADDR)) &&
          (axi.ARPROT == $past(axi.ARPROT))
  ) else $error("AXI AR source changed VALID/payload while stalled");

  a_axi_r_stable: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      $past(axi.RVALID && !axi.RREADY)
      |-> axi.RVALID &&
          (axi.RDATA == $past(axi.RDATA)) &&
          (axi.RRESP == $past(axi.RRESP))
  ) else $error("AXI R source changed VALID/payload while stalled");

  // ------------------------------------------------------------------------
  // AXI cross-channel dependencies and project response profile
  // ------------------------------------------------------------------------

  a_axi_bvalid_has_aw_and_w: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.BVALID |-> aw_seen_q && w_seen_q
  ) else $error("AXI BVALID asserted without accepted AW and W context");

  a_axi_rvalid_has_ar: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.RVALID |-> ar_seen_q
  ) else $error("AXI RVALID asserted without accepted AR context");

  a_profile_no_exokay_b: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.BVALID |-> axi.BRESP != AXI_RESP_EXOKAY
  ) else $error("AXI BRESP used unsupported EXOKAY response");

  a_profile_no_exokay_r: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.RVALID |-> axi.RRESP != AXI_RESP_EXOKAY
  ) else $error("AXI RRESP used unsupported EXOKAY response");

  // ------------------------------------------------------------------------
  // Project depth-one transaction profile
  // ------------------------------------------------------------------------

  a_profile_no_second_aw: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      aw_hs |-> !aw_seen_q
  ) else $error("AXI4-Lite profile accepted a second outstanding AW");

  a_profile_no_second_w: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      w_hs |-> !w_seen_q
  ) else $error("AXI4-Lite profile accepted a second outstanding W");

  a_profile_no_second_ar: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      ar_hs |-> !ar_seen_q
  ) else $error("AXI4-Lite profile accepted a second outstanding AR");

  // ------------------------------------------------------------------------
  // Deterministic project reset contract
  // ------------------------------------------------------------------------

  // These properties intentionally remain active while reset is asserted.
  a_project_reset_valid_low: assert property (
    @(posedge axi.ACLK)
      !axi.ARESETn
      |-> !axi.AWVALID &&
          !axi.WVALID &&
          !axi.BVALID &&
          !axi.ARVALID &&
          !axi.RVALID
  ) else $error("AXI VALID observed high during reset");

  a_project_reset_ready_low: assert property (
    @(posedge axi.ACLK)
      !axi.ARESETn
      |-> !axi.AWREADY &&
          !axi.WREADY &&
          !axi.BREADY &&
          !axi.ARREADY &&
          !axi.RREADY
  ) else $error("AXI READY observed high during reset");

  // ------------------------------------------------------------------------
  // Coverage for required ordering, stalls, and read/write concurrency
  // ------------------------------------------------------------------------

  c_aw_before_w: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      w_hs && aw_seen_q && !w_seen_q
  );

  c_w_before_aw: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      aw_hs && w_seen_q && !aw_seen_q
  );

  c_aw_w_same_cycle: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      aw_hs && w_hs && !aw_seen_q && !w_seen_q
  );

  c_aw_stall_w_progress: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.AWVALID && !axi.AWREADY && w_hs
  );

  c_w_stall_aw_progress: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.WVALID && !axi.WREADY && aw_hs
  );

  c_b_backpressure: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.BVALID && !axi.BREADY
  );

  c_r_backpressure: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.RVALID && !axi.RREADY
  );

  c_concurrent_read_write: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      (ar_hs || ar_seen_q) &&
      (aw_hs || w_hs || aw_seen_q || w_seen_q)
  );

endmodule
