module axi4lite_master_adapter #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32
) (
  native_req_rsp_if.target native,
  axi4lite_if.master       m_axi
);

  import axi4lite_pkg::*;

  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;

  // Buffered native write request
  logic [ADDR_WIDTH-1:0] awaddr_q;
  logic [2:0]            awprot_q;
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [STRB_WIDTH-1:0] wstrb_q;
  logic                  wr_busy_q;
  logic                  aw_pending_q;
  logic                  w_pending_q;

  // Buffered native write response
  native_resp_e wr_rsp_resp_q;
  logic         wr_rsp_valid_q;

  // Buffered native read request
  logic [ADDR_WIDTH-1:0] araddr_q;
  logic [2:0]            arprot_q;
  logic                  rd_busy_q;
  logic                  ar_pending_q;

  // Buffered native read response
  logic [DATA_WIDTH-1:0] rd_rsp_data_q;
  native_resp_e          rd_rsp_resp_q;
  logic                  rd_rsp_valid_q;

  // Accept one native write request and retain ownership until its native
  // response handshake completes.
  assign native.wr_req_ready = m_axi.ARESETn && !wr_busy_q;
  assign native.wr_rsp_resp  = wr_rsp_resp_q;
  assign native.wr_rsp_valid = m_axi.ARESETn && wr_rsp_valid_q;

  // AXI write-address and write-data channels progress independently.
  assign m_axi.AWADDR  = awaddr_q;
  assign m_axi.AWPROT  = awprot_q;
  assign m_axi.AWVALID = m_axi.ARESETn && aw_pending_q;
  assign m_axi.WDATA   = wdata_q;
  assign m_axi.WSTRB   = wstrb_q;
  assign m_axi.WVALID  = m_axi.ARESETn && w_pending_q;

  // The response buffer decouples AXI B from native response backpressure.
  // B is accepted only after both write halves have transferred.
  assign m_axi.BREADY =
      m_axi.ARESETn && wr_busy_q && !aw_pending_q && !w_pending_q &&
      !wr_rsp_valid_q;

  // Accept one native read request and retain ownership until its native
  // response handshake completes.
  assign native.rd_req_ready = m_axi.ARESETn && !rd_busy_q;
  assign native.rd_rsp_data  = rd_rsp_data_q;
  assign native.rd_rsp_resp  = rd_rsp_resp_q;
  assign native.rd_rsp_valid = m_axi.ARESETn && rd_rsp_valid_q;

  // AXI read-address and read-data channels. R is accepted only after AR.
  assign m_axi.ARADDR  = araddr_q;
  assign m_axi.ARPROT  = arprot_q;
  assign m_axi.ARVALID = m_axi.ARESETn && ar_pending_q;
  assign m_axi.RREADY =
      m_axi.ARESETn && rd_busy_q && !ar_pending_q && !rd_rsp_valid_q;

  // Independent write datapath
  always_ff @(posedge m_axi.ACLK or negedge m_axi.ARESETn) begin
    if (!m_axi.ARESETn) begin
      awaddr_q       <= '0;
      awprot_q       <= '0;
      wdata_q        <= '0;
      wstrb_q        <= '0;
      wr_busy_q      <= 1'b0;
      aw_pending_q   <= 1'b0;
      w_pending_q    <= 1'b0;
      wr_rsp_resp_q  <= NATIVE_RESP_OKAY;
      wr_rsp_valid_q <= 1'b0;
    end else begin
      if (native.wr_req_valid && native.wr_req_ready) begin
        awaddr_q      <= native.wr_req_addr;
        awprot_q      <= native.wr_req_prot;
        wdata_q       <= native.wr_req_data;
        wstrb_q       <= native.wr_req_strb;
        wr_busy_q     <= 1'b1;
        aw_pending_q  <= 1'b1;
        w_pending_q   <= 1'b1;
      end

      if (m_axi.AWVALID && m_axi.AWREADY) begin
        aw_pending_q <= 1'b0;
      end

      if (m_axi.WVALID && m_axi.WREADY) begin
        w_pending_q <= 1'b0;
      end

      if (m_axi.BVALID && m_axi.BREADY) begin
        wr_rsp_resp_q  <= axi_to_native_resp(m_axi.BRESP);
        wr_rsp_valid_q <= 1'b1;
      end

      if (native.wr_rsp_valid && native.wr_rsp_ready) begin
        wr_busy_q      <= 1'b0;
        wr_rsp_valid_q <= 1'b0;
      end
    end
  end

  // Independent read datapath
  always_ff @(posedge m_axi.ACLK or negedge m_axi.ARESETn) begin
    if (!m_axi.ARESETn) begin
      araddr_q       <= '0;
      arprot_q       <= '0;
      rd_busy_q      <= 1'b0;
      ar_pending_q   <= 1'b0;
      rd_rsp_data_q  <= '0;
      rd_rsp_resp_q  <= NATIVE_RESP_OKAY;
      rd_rsp_valid_q <= 1'b0;
    end else begin
      if (native.rd_req_valid && native.rd_req_ready) begin
        araddr_q     <= native.rd_req_addr;
        arprot_q     <= native.rd_req_prot;
        rd_busy_q    <= 1'b1;
        ar_pending_q <= 1'b1;
      end

      if (m_axi.ARVALID && m_axi.ARREADY) begin
        ar_pending_q <= 1'b0;
      end

      if (m_axi.RVALID && m_axi.RREADY) begin
        rd_rsp_data_q  <= m_axi.RDATA;
        rd_rsp_resp_q  <= axi_to_native_resp(m_axi.RRESP);
        rd_rsp_valid_q <= 1'b1;
      end

      if (native.rd_rsp_valid && native.rd_rsp_ready) begin
        rd_busy_q      <= 1'b0;
        rd_rsp_valid_q <= 1'b0;
      end
    end
  end

  // Parameter checks for the v1.0 profile.
  generate
    if ((DATA_WIDTH != 32) && (DATA_WIDTH != 64)) begin : g_invalid_data_width
      initial begin
        $fatal(1,
               "axi4lite_master_adapter: DATA_WIDTH must be 32 or 64, got %0d",
               DATA_WIDTH);
      end
    end

    if ((DATA_WIDTH % 8) != 0) begin : g_non_byte_data_width
      initial begin
        $fatal(
          1,
          "axi4lite_master_adapter: DATA_WIDTH must be byte-aligned, got %0d",
          DATA_WIDTH
        );
      end
    end

    if (((DATA_WIDTH == 32) || (DATA_WIDTH == 64)) &&
        (ADDR_WIDTH < $clog2(DATA_WIDTH / 8))) begin : g_invalid_addr_width
      initial begin
        $fatal(
          1,
          "axi4lite_master_adapter: ADDR_WIDTH (%0d) is too small for DATA_WIDTH (%0d)",
          ADDR_WIDTH,
          DATA_WIDTH
        );
      end
    end
  endgenerate

  // AXI and native interface widths must match the adapter parameters.
  initial begin : p_check_interface_widths
    if (($bits(m_axi.AWADDR) != ADDR_WIDTH) ||
        ($bits(m_axi.ARADDR) != ADDR_WIDTH) ||
        ($bits(native.wr_req_addr) != ADDR_WIDTH) ||
        ($bits(native.rd_req_addr) != ADDR_WIDTH)) begin
      $fatal(1, "axi4lite_master_adapter: address width mismatch");
    end

    if (($bits(m_axi.WDATA) != DATA_WIDTH) ||
        ($bits(m_axi.RDATA) != DATA_WIDTH) ||
        ($bits(native.wr_req_data) != DATA_WIDTH) ||
        ($bits(native.rd_rsp_data) != DATA_WIDTH)) begin
      $fatal(1, "axi4lite_master_adapter: data width mismatch");
    end

    if (($bits(m_axi.WSTRB) != STRB_WIDTH) ||
        ($bits(native.wr_req_strb) != STRB_WIDTH)) begin
      $fatal(1, "axi4lite_master_adapter: strobe width mismatch");
    end
  end

endmodule
