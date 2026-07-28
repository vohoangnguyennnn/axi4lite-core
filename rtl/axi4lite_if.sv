interface axi4lite_if #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32
) (
  input logic ACLK,
  input logic ARESETn
);

  import axi4lite_pkg::*;

  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;

  // Write address channel
  logic [ADDR_WIDTH-1:0] AWADDR;
  logic [2:0]            AWPROT;
  logic                  AWVALID;
  logic                  AWREADY;

  // Write data channel
  logic [DATA_WIDTH-1:0] WDATA;
  logic [STRB_WIDTH-1:0] WSTRB;
  logic                  WVALID;
  logic                  WREADY;

  // Write response channel
  axi_resp_e BRESP;
  logic      BVALID;
  logic      BREADY;

  // Read address channel
  logic [ADDR_WIDTH-1:0] ARADDR;
  logic [2:0]            ARPROT;
  logic                  ARVALID;
  logic                  ARREADY;

  // Read data channel
  logic [DATA_WIDTH-1:0] RDATA;
  axi_resp_e             RRESP;
  logic                  RVALID;
  logic                  RREADY;

  // AXI4-Lite master signal ownership.
  modport master (
    input  ACLK,
    input  ARESETn,

    output AWADDR,
    output AWPROT,
    output AWVALID,
    input  AWREADY,

    output WDATA,
    output WSTRB,
    output WVALID,
    input  WREADY,

    input  BRESP,
    input  BVALID,
    output BREADY,

    output ARADDR,
    output ARPROT,
    output ARVALID,
    input  ARREADY,

    input  RDATA,
    input  RRESP,
    input  RVALID,
    output RREADY
  );

  // AXI4-Lite slave signal ownership.
  modport slave (
    input  ACLK,
    input  ARESETn,

    input  AWADDR,
    input  AWPROT,
    input  AWVALID,
    output AWREADY,

    input  WDATA,
    input  WSTRB,
    input  WVALID,
    output WREADY,

    output BRESP,
    output BVALID,
    input  BREADY,

    input  ARADDR,
    input  ARPROT,
    input  ARVALID,
    output ARREADY,

    output RDATA,
    output RRESP,
    output RVALID,
    input  RREADY
  );

  // Passive view used by protocol checkers and testbench monitors.
  modport monitor (
    input ACLK,
    input ARESETn,

    input AWADDR,
    input AWPROT,
    input AWVALID,
    input AWREADY,

    input WDATA,
    input WSTRB,
    input WVALID,
    input WREADY,

    input BRESP,
    input BVALID,
    input BREADY,

    input ARADDR,
    input ARPROT,
    input ARVALID,
    input ARREADY,

    input RDATA,
    input RRESP,
    input RVALID,
    input RREADY
  );

  // Elaboration-time checks for the v1.0 parameter profile.
  generate
    if ((DATA_WIDTH != 32) && (DATA_WIDTH != 64)) begin : g_invalid_data_width
      initial begin
        $fatal(1, "axi4lite_if: DATA_WIDTH must be 32 or 64, got %0d",
               DATA_WIDTH);
      end
    end

    if ((DATA_WIDTH % 8) != 0) begin : g_non_byte_data_width
      initial begin
        $fatal(1, "axi4lite_if: DATA_WIDTH must be byte-aligned, got %0d",
               DATA_WIDTH);
      end
    end

    if (((DATA_WIDTH == 32) || (DATA_WIDTH == 64)) &&
        (ADDR_WIDTH < $clog2(DATA_WIDTH / 8))) begin : g_invalid_addr_width
      initial begin
        $fatal(1,
               "axi4lite_if: ADDR_WIDTH (%0d) is too small for DATA_WIDTH (%0d)",
               ADDR_WIDTH, DATA_WIDTH);
      end
    end
  endgenerate

endinterface
