module axi4lite_slave_adapter #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32
) (
  axi4lite_if.slave           s_axi,
  native_req_rsp_if.requester native
);

  import axi4lite_pkg::*;

  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;

  // Write-address holding register
  logic [ADDR_WIDTH-1:0] awaddr_q;
  logic [2:0]            awprot_q;
  logic                  have_aw_q;

  // Write-data holding register
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [STRB_WIDTH-1:0] wstrb_q;
  logic                  have_w_q;

  // Write request/response state
  logic      wr_req_sent_q;
  axi_resp_e bresp_q;
  logic      bvalid_q;

  // Read-address holding register
  logic [ADDR_WIDTH-1:0] araddr_q;
  logic [2:0]            arprot_q;
  logic                  have_ar_q;

  // Read request/response state
  logic                  rd_req_sent_q;
  logic [DATA_WIDTH-1:0] rdata_q;
  axi_resp_e             rresp_q;
  logic                  rvalid_q;

  // AXI write channels. Address and data are accepted independently.
  assign s_axi.AWREADY = s_axi.ARESETn && !have_aw_q;
  assign s_axi.WREADY  = s_axi.ARESETn && !have_w_q;
  assign s_axi.BRESP   = bresp_q;
  assign s_axi.BVALID  = s_axi.ARESETn && bvalid_q;

  // A native write request becomes valid only after both AXI write halves
  // have been captured. The holding registers remain occupied until B.
  assign native.wr_req_addr  = awaddr_q;
  assign native.wr_req_data  = wdata_q;
  assign native.wr_req_strb  = wstrb_q;
  assign native.wr_req_prot  = awprot_q;
  assign native.wr_req_valid = s_axi.ARESETn && have_aw_q && have_w_q && !wr_req_sent_q;
  assign native.wr_rsp_ready = s_axi.ARESETn && wr_req_sent_q && !bvalid_q;

  // AXI read channels.
  assign s_axi.ARREADY = s_axi.ARESETn && !have_ar_q;
  assign s_axi.RDATA   = rdata_q;
  assign s_axi.RRESP   = rresp_q;
  assign s_axi.RVALID  = s_axi.ARESETn && rvalid_q;

  // The read address remains buffered until the AXI read response completes.
  assign native.rd_req_addr  = araddr_q;
  assign native.rd_req_prot  = arprot_q;
  assign native.rd_req_valid =
      s_axi.ARESETn && have_ar_q && !rd_req_sent_q;
  assign native.rd_rsp_ready =
      s_axi.ARESETn && rd_req_sent_q && !rvalid_q;

  // Independent write datapath
  always_ff @(posedge s_axi.ACLK or negedge s_axi.ARESETn) begin
    if (!s_axi.ARESETn) begin
      awaddr_q      <= '0;
      awprot_q      <= '0;
      have_aw_q     <= 1'b0;
      wdata_q       <= '0;
      wstrb_q       <= '0;
      have_w_q      <= 1'b0;
      wr_req_sent_q <= 1'b0;
      bresp_q       <= AXI_RESP_OKAY;
      bvalid_q      <= 1'b0;
    end else begin
      if (s_axi.AWVALID && s_axi.AWREADY) begin
        awaddr_q  <= s_axi.AWADDR;
        awprot_q  <= s_axi.AWPROT;
        have_aw_q <= 1'b1;
      end

      if (s_axi.WVALID && s_axi.WREADY) begin
        wdata_q   <= s_axi.WDATA;
        wstrb_q   <= s_axi.WSTRB;
        have_w_q  <= 1'b1;
      end

      if (native.wr_req_valid && native.wr_req_ready) begin
        wr_req_sent_q <= 1'b1;
      end

      if (native.wr_rsp_valid && native.wr_rsp_ready) begin
        bresp_q  <= native_to_axi_resp(native.wr_rsp_resp);
        bvalid_q <= 1'b1;
      end

      if (s_axi.BVALID && s_axi.BREADY) begin
        have_aw_q     <= 1'b0;
        have_w_q      <= 1'b0;
        wr_req_sent_q <= 1'b0;
        bvalid_q      <= 1'b0;
      end
    end
  end

  // Independent read datapath
  always_ff @(posedge s_axi.ACLK or negedge s_axi.ARESETn) begin
    if (!s_axi.ARESETn) begin
      araddr_q      <= '0;
      arprot_q      <= '0;
      have_ar_q     <= 1'b0;
      rd_req_sent_q <= 1'b0;
      rdata_q       <= '0;
      rresp_q       <= AXI_RESP_OKAY;
      rvalid_q      <= 1'b0;
    end else begin
      if (s_axi.ARVALID && s_axi.ARREADY) begin
        araddr_q  <= s_axi.ARADDR;
        arprot_q  <= s_axi.ARPROT;
        have_ar_q <= 1'b1;
      end

      if (native.rd_req_valid && native.rd_req_ready) begin
        rd_req_sent_q <= 1'b1;
      end

      if (native.rd_rsp_valid && native.rd_rsp_ready) begin
        rdata_q  <= native.rd_rsp_data;
        rresp_q  <= native_to_axi_resp(native.rd_rsp_resp);
        rvalid_q <= 1'b1;
      end

      if (s_axi.RVALID && s_axi.RREADY) begin
        have_ar_q     <= 1'b0;
        rd_req_sent_q <= 1'b0;
        rvalid_q      <= 1'b0;
      end
    end
  end

  // Parameter checks for the v1.0 profile.
  generate
    if ((DATA_WIDTH != 32) && (DATA_WIDTH != 64)) begin : g_invalid_data_width
      initial begin
        $fatal(1,
               "axi4lite_slave_adapter: DATA_WIDTH must be 32 or 64, got %0d",
               DATA_WIDTH);
      end
    end

    if ((DATA_WIDTH % 8) != 0) begin : g_non_byte_data_width
      initial begin
        $fatal(
          1,
          "axi4lite_slave_adapter: DATA_WIDTH must be byte-aligned, got %0d",
          DATA_WIDTH
        );
      end
    end

    if (((DATA_WIDTH == 32) || (DATA_WIDTH == 64)) &&
        (ADDR_WIDTH < $clog2(DATA_WIDTH / 8))) begin : g_invalid_addr_width
      initial begin
        $fatal(
          1,
          "axi4lite_slave_adapter: ADDR_WIDTH (%0d) is too small for DATA_WIDTH (%0d)",
          ADDR_WIDTH,
          DATA_WIDTH
        );
      end
    end
  endgenerate

  // AXI and native interface widths must match the adapter parameters.
  initial begin : p_check_interface_widths
    if (($bits(s_axi.AWADDR) != ADDR_WIDTH) ||
        ($bits(s_axi.ARADDR) != ADDR_WIDTH) ||
        ($bits(native.wr_req_addr) != ADDR_WIDTH) ||
        ($bits(native.rd_req_addr) != ADDR_WIDTH)) begin
      $fatal(1, "axi4lite_slave_adapter: address width mismatch");
    end

    if (($bits(s_axi.WDATA) != DATA_WIDTH) ||
        ($bits(s_axi.RDATA) != DATA_WIDTH) ||
        ($bits(native.wr_req_data) != DATA_WIDTH) ||
        ($bits(native.rd_rsp_data) != DATA_WIDTH)) begin
      $fatal(1, "axi4lite_slave_adapter: data width mismatch");
    end

    if (($bits(s_axi.WSTRB) != STRB_WIDTH) ||
        ($bits(native.wr_req_strb) != STRB_WIDTH)) begin
      $fatal(1, "axi4lite_slave_adapter: strobe width mismatch");
    end
  end

endmodule
