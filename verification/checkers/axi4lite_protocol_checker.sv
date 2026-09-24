// AXI4-Lite protocol checker.
//
// Rules are split into two groups:
//   - AMBA AXI4-Lite rules (always active). These are valid for any AXI4-Lite
//     master or slave, including third-party IP with multiple outstanding
//     transactions.
//   - Project profile rules (STRICT_PROFILE = 1). These additionally enforce
//     the depth-one transaction limit and the READY-low-in-reset policy of the
//     axi4lite-core adapters. Set STRICT_PROFILE = 0 when monitoring a bus
//     where either side is not one of the project adapters.
module axi4lite_protocol_checker #(
  parameter bit          STRICT_PROFILE  = 1'b1,
  // Must match the DATA_WIDTH of the monitored axi4lite_if.
  parameter int unsigned DATA_WIDTH      = 32,
  // Outstanding-transaction capacity of the checker's tracking counters.
  parameter int unsigned MAX_OUTSTANDING = 16
) (
  axi4lite_if.monitor axi
);

  import axi4lite_pkg::*;

  localparam int unsigned CNT_WIDTH  = $clog2(MAX_OUTSTANDING + 1);
  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;

  typedef logic [CNT_WIDTH-1:0] cnt_t;

  logic aw_hs;
  logic w_hs;
  logic b_hs;
  logic ar_hs;
  logic r_hs;

  // Accepted-but-unanswered transaction halves. AW and W are counted
  // separately because either half can be accepted first, and a new half can
  // be accepted in the same cycle as a B handshake.
  cnt_t aw_cnt_q;
  cnt_t w_cnt_q;
  cnt_t ar_cnt_q;

  // ARESETn sampled on the previous edge, used for the reset-exit rule.
  logic aresetn_q;

  // WDATA with the byte lanes that WSTRB does not select forced to zero, so
  // X checks only apply to lanes that carry valid data.
  logic [DATA_WIDTH-1:0] wdata_strobed;

  assign aw_hs = axi.AWVALID && axi.AWREADY;
  assign w_hs  = axi.WVALID  && axi.WREADY;
  assign b_hs  = axi.BVALID  && axi.BREADY;
  assign ar_hs = axi.ARVALID && axi.ARREADY;
  assign r_hs  = axi.RVALID  && axi.RREADY;

  always_comb begin
    for (int unsigned i = 0; i < STRB_WIDTH; i++) begin
      wdata_strobed[i*8 +: 8] = axi.WSTRB[i] ? axi.WDATA[i*8 +: 8] : 8'h00;
    end
  end

  // Reset style matches the adapters (asynchronous assert). At every sampling
  // edge aresetn_q still holds ARESETn as seen on the previous edge.
  always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      aresetn_q <= 1'b0;
    end else begin
      aresetn_q <= 1'b1;
    end
  end

  always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      aw_cnt_q <= '0;
      w_cnt_q  <= '0;
      ar_cnt_q <= '0;
    end else begin
      aw_cnt_q <= aw_cnt_q + cnt_t'(aw_hs) - cnt_t'(b_hs);
      w_cnt_q  <= w_cnt_q  + cnt_t'(w_hs)  - cnt_t'(b_hs);
      ar_cnt_q <= ar_cnt_q + cnt_t'(ar_hs) - cnt_t'(r_hs);
    end
  end

  initial begin : p_check_interface_widths
    if (($bits(axi.WDATA) != int'(DATA_WIDTH)) ||
        ($bits(axi.RDATA) != int'(DATA_WIDTH)) ||
        ($bits(axi.WSTRB) != int'(STRB_WIDTH))) begin
      $fatal(1, "axi4lite_protocol_checker: DATA_WIDTH does not match the interface");
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
  // AXI cross-channel dependencies and AXI4-Lite response encoding
  // ------------------------------------------------------------------------

  // The counters are registered, so a handshake on the current edge does not
  // count: BVALID/RVALID must follow the address/data handshakes by at least
  // one cycle.
  a_axi_bvalid_has_aw_and_w: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.BVALID |-> (aw_cnt_q != '0) && (w_cnt_q != '0)
  ) else $error("AXI BVALID asserted without accepted AW and W context");

  a_axi_rvalid_has_ar: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.RVALID |-> ar_cnt_q != '0
  ) else $error("AXI RVALID asserted without accepted AR context");

  // AXI4-Lite does not support exclusive accesses.
  a_axi_no_exokay_b: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.BVALID |-> axi.BRESP != AXI_RESP_EXOKAY
  ) else $error("AXI BRESP used EXOKAY, which AXI4-Lite does not support");

  a_axi_no_exokay_r: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.RVALID |-> axi.RRESP != AXI_RESP_EXOKAY
  ) else $error("AXI RRESP used EXOKAY, which AXI4-Lite does not support");

  // ------------------------------------------------------------------------
  // X/Z checks
  // ------------------------------------------------------------------------

  a_axi_valid_ready_known: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      !$isunknown({axi.AWVALID, axi.AWREADY, axi.WVALID, axi.WREADY,
                   axi.BVALID, axi.BREADY, axi.ARVALID, axi.ARREADY,
                   axi.RVALID, axi.RREADY})
  ) else $error("AXI VALID/READY is X or Z outside reset");

  a_axi_aw_payload_known: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.AWVALID |-> !$isunknown({axi.AWADDR, axi.AWPROT})
  ) else $error("AXI AWADDR/AWPROT is X or Z while AWVALID is high");

  a_axi_w_payload_known: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.WVALID |-> !$isunknown({axi.WSTRB, wdata_strobed})
  ) else $error("AXI WSTRB or a strobed WDATA lane is X or Z while WVALID is high");

  a_axi_b_payload_known: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.BVALID |-> !$isunknown(axi.BRESP)
  ) else $error("AXI BRESP is X or Z while BVALID is high");

  a_axi_ar_payload_known: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.ARVALID |-> !$isunknown({axi.ARADDR, axi.ARPROT})
  ) else $error("AXI ARADDR/ARPROT is X or Z while ARVALID is high");

  a_axi_r_payload_known: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      axi.RVALID |-> !$isunknown({axi.RDATA, axi.RRESP})
  ) else $error("AXI RDATA/RRESP is X or Z while RVALID is high");

  // ------------------------------------------------------------------------
  // AXI reset rules
  // ------------------------------------------------------------------------

  // These properties intentionally remain active while reset is asserted.
  a_axi_reset_valid_low: assert property (
    @(posedge axi.ACLK)
      !axi.ARESETn
      |-> !axi.AWVALID &&
          !axi.WVALID &&
          !axi.BVALID &&
          !axi.ARVALID &&
          !axi.RVALID
  ) else $error("AXI VALID observed high during reset");

  // VALID may first be driven high at a rising edge after ARESETn is high, so
  // it must still be low on the first edge that samples ARESETn high.
  a_axi_reset_exit_valid_low: assert property (
    @(posedge axi.ACLK)
      !aresetn_q && axi.ARESETn
      |-> !axi.AWVALID &&
          !axi.WVALID &&
          !axi.BVALID &&
          !axi.ARVALID &&
          !axi.RVALID
  ) else $error("AXI VALID asserted on the first cycle after reset");

  // ------------------------------------------------------------------------
  // Checker capacity
  // ------------------------------------------------------------------------

  a_checker_capacity: assert property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      (aw_cnt_q <= cnt_t'(MAX_OUTSTANDING)) &&
      (w_cnt_q  <= cnt_t'(MAX_OUTSTANDING)) &&
      (ar_cnt_q <= cnt_t'(MAX_OUTSTANDING))
  ) else $error("AXI outstanding transactions exceed checker MAX_OUTSTANDING");

  // ------------------------------------------------------------------------
  // Project profile: depth-one transactions and READY low in reset
  // ------------------------------------------------------------------------

  if (STRICT_PROFILE) begin : g_strict_profile

    // A new half may be accepted in the same cycle as the B/R handshake that
    // retires the previous transaction.
    a_profile_no_second_aw: assert property (
      @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        aw_hs |-> aw_cnt_q <= cnt_t'(b_hs)
    ) else $error("AXI4-Lite profile accepted a second outstanding AW");

    a_profile_no_second_w: assert property (
      @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        w_hs |-> w_cnt_q <= cnt_t'(b_hs)
    ) else $error("AXI4-Lite profile accepted a second outstanding W");

    a_profile_no_second_ar: assert property (
      @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        ar_hs |-> ar_cnt_q <= cnt_t'(r_hs)
    ) else $error("AXI4-Lite profile accepted a second outstanding AR");

    a_profile_reset_ready_low: assert property (
      @(posedge axi.ACLK)
        !axi.ARESETn
        |-> !axi.AWREADY &&
            !axi.WREADY &&
            !axi.BREADY &&
            !axi.ARREADY &&
            !axi.RREADY
    ) else $error("AXI READY observed high during reset");

  end else begin : g_generic_coverage

    // Overlap that the depth-one profile never produces.
    c_aw_with_b: cover property (
      @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        aw_hs && b_hs
    );

    c_multiple_outstanding_writes: cover property (
      @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        aw_cnt_q > cnt_t'(1)
    );

    c_multiple_outstanding_reads: cover property (
      @(posedge axi.ACLK) disable iff (!axi.ARESETn)
        ar_cnt_q > cnt_t'(1)
    );

  end

  // ------------------------------------------------------------------------
  // Coverage for required ordering, stalls, and read/write concurrency
  // ------------------------------------------------------------------------

  c_aw_before_w: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      w_hs && !aw_hs && (aw_cnt_q > w_cnt_q)
  );

  c_w_before_aw: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      aw_hs && !w_hs && (w_cnt_q > aw_cnt_q)
  );

  c_aw_w_same_cycle: cover property (
    @(posedge axi.ACLK) disable iff (!axi.ARESETn)
      aw_hs && w_hs && (aw_cnt_q == w_cnt_q)
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
      (ar_hs || (ar_cnt_q != '0)) &&
      (aw_hs || w_hs || (aw_cnt_q != '0) || (w_cnt_q != '0))
  );

endmodule
