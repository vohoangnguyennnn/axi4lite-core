// Self-test for axi4lite_protocol_checker.
//
// The testbench drives both sides of an AXI4-Lite bus directly and runs one
// scenario selected with +SCENARIO=<name>. Legal scenarios must finish with
// "SELFTEST PASS" and no assertion failure. Illegal scenarios must trip the
// assertion named by the runner script.
module axi4lite_checker_selftest_tb #(
  parameter bit STRICT_PROFILE = 1'b1
);

  import axi4lite_pkg::*;

  logic ACLK;
  logic ARESETn;

  axi4lite_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) bus (ACLK, ARESETn);

  axi4lite_protocol_checker #(.STRICT_PROFILE(STRICT_PROFILE)) u_checker (
    .axi(bus)
  );

  initial begin
    ACLK = 1'b0;
    forever #5 ACLK = ~ACLK;
  end

  string scenario;

  // All stimulus changes on the falling edge so the checker samples stable
  // values on the rising edge.
  task automatic tick(input int unsigned n = 1);
    repeat (n) @(negedge ACLK);
  endtask

  task automatic idle_bus();
    bus.AWADDR  = '0;
    bus.AWPROT  = '0;
    bus.AWVALID = 1'b0;
    bus.AWREADY = 1'b0;
    bus.WDATA   = '0;
    bus.WSTRB   = '0;
    bus.WVALID  = 1'b0;
    bus.WREADY  = 1'b0;
    bus.BRESP   = AXI_RESP_OKAY;
    bus.BVALID  = 1'b0;
    bus.BREADY  = 1'b0;
    bus.ARADDR  = '0;
    bus.ARPROT  = '0;
    bus.ARVALID = 1'b0;
    bus.ARREADY = 1'b0;
    bus.RDATA   = '0;
    bus.RRESP   = AXI_RESP_OKAY;
    bus.RVALID  = 1'b0;
    bus.RREADY  = 1'b0;
  endtask

  task automatic reset_bus();
    idle_bus();
    ARESETn = 1'b0;
    tick(3);
    ARESETn = 1'b1;
    tick(2);
  endtask

  // Complete a B handshake with the master ready immediately.
  task automatic send_b(input logic [1:0] resp);
    bus.BRESP  = resp;
    bus.BVALID = 1'b1;
    bus.BREADY = 1'b1;
    tick();
    bus.BVALID = 1'b0;
    bus.BREADY = 1'b0;
  endtask

  // ------------------------------------------------------------------------
  // Legal scenarios
  // ------------------------------------------------------------------------

  // Depth-one traffic that both the generic and strict rule sets accept.
  task automatic legal_basic();
    // AW before W, with a stalled AW first.
    bus.AWADDR = 32'h0000_0010; bus.AWVALID = 1'b1;
    tick(2);
    bus.AWREADY = 1'b1;
    tick();
    bus.AWVALID = 1'b0; bus.AWREADY = 1'b0;
    bus.WDATA = 32'hCAFE_0001; bus.WSTRB = 4'hF; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
    tick();
    bus.WVALID = 1'b0; bus.WREADY = 1'b0;
    // B stalled by the master for two cycles.
    bus.BRESP = AXI_RESP_OKAY; bus.BVALID = 1'b1;
    tick(2);
    bus.BREADY = 1'b1;
    tick();
    bus.BVALID = 1'b0; bus.BREADY = 1'b0;

    // W before AW.
    bus.WDATA = 32'hCAFE_0002; bus.WSTRB = 4'b0011; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
    tick();
    bus.WVALID = 1'b0; bus.WREADY = 1'b0;
    bus.AWADDR = 32'h0000_0014; bus.AWVALID = 1'b1; bus.AWREADY = 1'b1;
    tick();
    bus.AWVALID = 1'b0; bus.AWREADY = 1'b0;
    send_b(AXI_RESP_SLVERR);

    // AW and W in the same cycle, overlapping with a read.
    bus.AWADDR = 32'h0000_0018; bus.AWVALID = 1'b1; bus.AWREADY = 1'b1;
    bus.WDATA  = 32'hCAFE_0003; bus.WSTRB   = 4'hF; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
    bus.ARADDR = 32'h0000_0010; bus.ARVALID = 1'b1; bus.ARREADY = 1'b1;
    tick();
    bus.AWVALID = 1'b0; bus.AWREADY = 1'b0;
    bus.WVALID  = 1'b0; bus.WREADY  = 1'b0;
    bus.ARVALID = 1'b0; bus.ARREADY = 1'b0;
    send_b(AXI_RESP_DECERR);
    // R stalled by the master for one cycle.
    bus.RDATA = 32'hCAFE_0001; bus.RRESP = AXI_RESP_OKAY; bus.RVALID = 1'b1;
    tick();
    bus.RREADY = 1'b1;
    tick();
    bus.RVALID = 1'b0; bus.RREADY = 1'b0;

    // A new AW accepted in the same cycle as the previous B handshake.
    bus.AWADDR = 32'h0000_001C; bus.AWVALID = 1'b1; bus.AWREADY = 1'b1;
    bus.WDATA  = 32'hCAFE_0004; bus.WSTRB   = 4'hF; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
    tick();
    bus.AWVALID = 1'b0; bus.AWREADY = 1'b0;
    bus.WVALID  = 1'b0; bus.WREADY  = 1'b0;
    bus.BVALID = 1'b1; bus.BREADY = 1'b1;
    bus.AWADDR = 32'h0000_0020; bus.AWVALID = 1'b1; bus.AWREADY = 1'b1;
    tick();
    bus.BVALID = 1'b0; bus.BREADY = 1'b0;
    bus.AWVALID = 1'b0; bus.AWREADY = 1'b0;
    bus.WDATA = 32'hCAFE_0005; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
    tick();
    bus.WVALID = 1'b0; bus.WREADY = 1'b0;
    send_b(AXI_RESP_OKAY);
  endtask

  // Legal AXI4-Lite traffic with several outstanding transactions. Only the
  // generic rule set accepts it; the strict profile must reject it.
  task automatic legal_overlap();
    // Two AWs and two Ws accepted before any B.
    for (int i = 0; i < 2; i++) begin
      bus.AWADDR = 32'h100 + 4 * i; bus.AWVALID = 1'b1; bus.AWREADY = 1'b1;
      bus.WDATA  = 32'hA0 + i;      bus.WSTRB   = 4'hF; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
      tick();
    end
    bus.AWVALID = 1'b0; bus.AWREADY = 1'b0;
    bus.WVALID  = 1'b0; bus.WREADY  = 1'b0;
    send_b(AXI_RESP_OKAY);
    send_b(AXI_RESP_OKAY);

    // Two ARs accepted before any R.
    for (int i = 0; i < 2; i++) begin
      bus.ARADDR = 32'h100 + 4 * i; bus.ARVALID = 1'b1; bus.ARREADY = 1'b1;
      tick();
    end
    bus.ARVALID = 1'b0; bus.ARREADY = 1'b0;
    for (int i = 0; i < 2; i++) begin
      bus.RDATA = 32'hA0 + i; bus.RVALID = 1'b1; bus.RREADY = 1'b1;
      tick();
    end
    bus.RVALID = 1'b0; bus.RREADY = 1'b0;
  endtask

  // ------------------------------------------------------------------------
  // Illegal scenarios, one protocol violation each
  // ------------------------------------------------------------------------

  task automatic run_illegal(input string name);
    case (name)
      "aw_valid_drop": begin
        bus.AWVALID = 1'b1;
        tick();
        bus.AWVALID = 1'b0;
        tick();
      end

      "w_payload_change": begin
        bus.WDATA = 32'h1; bus.WSTRB = 4'hF; bus.WVALID = 1'b1;
        tick();
        bus.WDATA = 32'h2;
        tick();
      end

      "b_payload_change": begin
        bus.AWVALID = 1'b1; bus.AWREADY = 1'b1; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
        tick();
        bus.AWVALID = 1'b0; bus.AWREADY = 1'b0; bus.WVALID = 1'b0; bus.WREADY = 1'b0;
        bus.BRESP = AXI_RESP_OKAY; bus.BVALID = 1'b1;
        tick();
        bus.BRESP = AXI_RESP_SLVERR;
        tick();
      end

      "ar_payload_change": begin
        bus.ARADDR = 32'h4; bus.ARVALID = 1'b1;
        tick();
        bus.ARADDR = 32'h8;
        tick();
      end

      "r_valid_drop": begin
        bus.ARVALID = 1'b1; bus.ARREADY = 1'b1;
        tick();
        bus.ARVALID = 1'b0; bus.ARREADY = 1'b0;
        bus.RVALID = 1'b1;
        tick();
        bus.RVALID = 1'b0;
        tick();
      end

      // BVALID in the same cycle as the W handshake.
      "b_before_w": begin
        bus.AWVALID = 1'b1; bus.AWREADY = 1'b1;
        tick();
        bus.AWVALID = 1'b0; bus.AWREADY = 1'b0;
        bus.WVALID = 1'b1; bus.WREADY = 1'b1; bus.BVALID = 1'b1;
        tick();
      end

      "r_without_ar": begin
        bus.RVALID = 1'b1;
        tick();
      end

      "b_exokay": begin
        bus.AWVALID = 1'b1; bus.AWREADY = 1'b1; bus.WVALID = 1'b1; bus.WREADY = 1'b1;
        tick();
        bus.AWVALID = 1'b0; bus.AWREADY = 1'b0; bus.WVALID = 1'b0; bus.WREADY = 1'b0;
        send_b(AXI_RESP_EXOKAY);
      end

      "r_exokay": begin
        bus.ARVALID = 1'b1; bus.ARREADY = 1'b1;
        tick();
        bus.ARVALID = 1'b0; bus.ARREADY = 1'b0;
        bus.RRESP = AXI_RESP_EXOKAY; bus.RVALID = 1'b1; bus.RREADY = 1'b1;
        tick();
      end

      "valid_in_reset": begin
        ARESETn = 1'b0;
        bus.ARVALID = 1'b1;
        tick(2);
      end

      "valid_at_reset_exit": begin
        ARESETn = 1'b0;
        tick(2);
        ARESETn = 1'b1;
        bus.AWVALID = 1'b1;
        tick(2);
      end

      // Strict profile only: legal in AXI4-Lite, outside the project profile.
      "second_aw": begin
        bus.AWVALID = 1'b1; bus.AWREADY = 1'b1;
        tick(2);
      end

      "ready_in_reset": begin
        ARESETn = 1'b0;
        bus.AWREADY = 1'b1;
        tick(2);
      end

      default: begin
        $fatal(1, "unknown scenario '%s'", name);
      end
    endcase
  endtask

  initial begin
    if (!$value$plusargs("SCENARIO=%s", scenario)) begin
      $fatal(1, "missing +SCENARIO=<name>");
    end

    reset_bus();

    case (scenario)
      "legal_basic":   legal_basic();
      "legal_overlap": legal_overlap();
      default:         run_illegal(scenario);
    endcase

    tick(3);
    $display("SELFTEST PASS: %s (STRICT_PROFILE=%0d)", scenario, STRICT_PROFILE);
    $finish;
  end

endmodule
