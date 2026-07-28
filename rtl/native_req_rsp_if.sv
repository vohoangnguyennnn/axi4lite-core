interface native_req_rsp_if #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32
) (
  input logic ACLK,
  input logic ARESETn
);

  import axi4lite_pkg::*;

  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;

  // Write request channel
  logic [ADDR_WIDTH-1:0] wr_req_addr;
  logic [DATA_WIDTH-1:0] wr_req_data;
  logic [STRB_WIDTH-1:0] wr_req_strb;
  logic [2:0]            wr_req_prot;
  logic                  wr_req_valid;
  logic                  wr_req_ready;

  // Write response channel
  native_resp_e wr_rsp_resp;
  logic         wr_rsp_valid;
  logic         wr_rsp_ready;

  // Read request channel
  logic [ADDR_WIDTH-1:0] rd_req_addr;
  logic [2:0]            rd_req_prot;
  logic                  rd_req_valid;
  logic                  rd_req_ready;

  // Read response channel
  logic [DATA_WIDTH-1:0] rd_rsp_data;
  native_resp_e          rd_rsp_resp;
  logic                  rd_rsp_valid;
  logic                  rd_rsp_ready;

  // Request source and response destination.
  modport requester (
    input  ACLK,
    input  ARESETn,

    output wr_req_addr,
    output wr_req_data,
    output wr_req_strb,
    output wr_req_prot,
    output wr_req_valid,
    input  wr_req_ready,

    input  wr_rsp_resp,
    input  wr_rsp_valid,
    output wr_rsp_ready,

    output rd_req_addr,
    output rd_req_prot,
    output rd_req_valid,
    input  rd_req_ready,

    input  rd_rsp_data,
    input  rd_rsp_resp,
    input  rd_rsp_valid,
    output rd_rsp_ready
  );

  // Request destination and response source.
  modport target (
    input  ACLK,
    input  ARESETn,

    input  wr_req_addr,
    input  wr_req_data,
    input  wr_req_strb,
    input  wr_req_prot,
    input  wr_req_valid,
    output wr_req_ready,

    output wr_rsp_resp,
    output wr_rsp_valid,
    input  wr_rsp_ready,

    input  rd_req_addr,
    input  rd_req_prot,
    input  rd_req_valid,
    output rd_req_ready,

    output rd_rsp_data,
    output rd_rsp_resp,
    output rd_rsp_valid,
    input  rd_rsp_ready
  );

  // Passive view used by native protocol checkers and testbench monitors.
  modport monitor (
    input ACLK,
    input ARESETn,

    input wr_req_addr,
    input wr_req_data,
    input wr_req_strb,
    input wr_req_prot,
    input wr_req_valid,
    input wr_req_ready,

    input wr_rsp_resp,
    input wr_rsp_valid,
    input wr_rsp_ready,

    input rd_req_addr,
    input rd_req_prot,
    input rd_req_valid,
    input rd_req_ready,

    input rd_rsp_data,
    input rd_rsp_resp,
    input rd_rsp_valid,
    input rd_rsp_ready
  );

  // Elaboration-time checks for the v1.0 parameter profile.
  generate
    if ((DATA_WIDTH != 32) && (DATA_WIDTH != 64)) begin : g_invalid_data_width
      initial begin
        $fatal(1, "native_req_rsp_if: DATA_WIDTH must be 32 or 64, got %0d",
               DATA_WIDTH);
      end
    end

    if ((DATA_WIDTH % 8) != 0) begin : g_non_byte_data_width
      initial begin
        $fatal(1,
               "native_req_rsp_if: DATA_WIDTH must be byte-aligned, got %0d",
               DATA_WIDTH);
      end
    end

    if (((DATA_WIDTH == 32) || (DATA_WIDTH == 64)) &&
        (ADDR_WIDTH < $clog2(DATA_WIDTH / 8))) begin : g_invalid_addr_width
      initial begin
        $fatal(
          1,
          "native_req_rsp_if: ADDR_WIDTH (%0d) is too small for DATA_WIDTH (%0d)",
          ADDR_WIDTH,
          DATA_WIDTH
        );
      end
    end
  endgenerate

endinterface
