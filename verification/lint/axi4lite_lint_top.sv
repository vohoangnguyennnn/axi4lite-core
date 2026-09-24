// Lint wrapper for the full design.
//
// Interface ports are not accepted on a Verilator top-level module, so this
// wrapper exposes the native sides of a master -> AXI4-Lite -> slave loopback
// as plain ports. Every RTL module and checker is elaborated once per
// DATA_WIDTH configuration.
module axi4lite_lint_top
  import axi4lite_pkg::*;
#(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32,
  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8
) (
  input  logic                  ACLK,
  input  logic                  ARESETn,

  // Native requester driving the master adapter
  input  logic [ADDR_WIDTH-1:0] req_wr_addr,
  input  logic [DATA_WIDTH-1:0] req_wr_data,
  input  logic [STRB_WIDTH-1:0] req_wr_strb,
  input  logic [2:0]            req_wr_prot,
  input  logic                  req_wr_valid,
  output logic                  req_wr_ready,
  output logic [1:0]            req_wr_rsp_resp,
  output logic                  req_wr_rsp_valid,
  input  logic                  req_wr_rsp_ready,
  input  logic [ADDR_WIDTH-1:0] req_rd_addr,
  input  logic [2:0]            req_rd_prot,
  input  logic                  req_rd_valid,
  output logic                  req_rd_ready,
  output logic [DATA_WIDTH-1:0] req_rd_rsp_data,
  output logic [1:0]            req_rd_rsp_resp,
  output logic                  req_rd_rsp_valid,
  input  logic                  req_rd_rsp_ready,

  // Native target behind the slave adapter
  output logic [ADDR_WIDTH-1:0] tgt_wr_addr,
  output logic [DATA_WIDTH-1:0] tgt_wr_data,
  output logic [STRB_WIDTH-1:0] tgt_wr_strb,
  output logic [2:0]            tgt_wr_prot,
  output logic                  tgt_wr_valid,
  input  logic                  tgt_wr_ready,
  input  logic [1:0]            tgt_wr_rsp_resp,
  input  logic                  tgt_wr_rsp_valid,
  output logic                  tgt_wr_rsp_ready,
  output logic [ADDR_WIDTH-1:0] tgt_rd_addr,
  output logic [2:0]            tgt_rd_prot,
  output logic                  tgt_rd_valid,
  input  logic                  tgt_rd_ready,
  input  logic [DATA_WIDTH-1:0] tgt_rd_rsp_data,
  input  logic [1:0]            tgt_rd_rsp_resp,
  input  logic                  tgt_rd_rsp_valid,
  output logic                  tgt_rd_rsp_ready
);

  native_req_rsp_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
    native_req (ACLK, ARESETn);
  native_req_rsp_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
    native_tgt (ACLK, ARESETn);
  axi4lite_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
    axi (ACLK, ARESETn);

  axi4lite_master_adapter #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
    u_master (.native(native_req), .m_axi(axi));

  axi4lite_slave_adapter #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
    u_slave (.s_axi(axi), .native(native_tgt));

  axi4lite_protocol_checker #(.DATA_WIDTH(DATA_WIDTH)) u_axi_checker (.axi(axi));
  native_req_rsp_checker u_req_checker (.native(native_req));
  native_req_rsp_checker u_tgt_checker (.native(native_tgt));

  // Requester side
  assign native_req.wr_req_addr  = req_wr_addr;
  assign native_req.wr_req_data  = req_wr_data;
  assign native_req.wr_req_strb  = req_wr_strb;
  assign native_req.wr_req_prot  = req_wr_prot;
  assign native_req.wr_req_valid = req_wr_valid;
  assign req_wr_ready            = native_req.wr_req_ready;
  assign req_wr_rsp_resp         = native_req.wr_rsp_resp;
  assign req_wr_rsp_valid        = native_req.wr_rsp_valid;
  assign native_req.wr_rsp_ready = req_wr_rsp_ready;
  assign native_req.rd_req_addr  = req_rd_addr;
  assign native_req.rd_req_prot  = req_rd_prot;
  assign native_req.rd_req_valid = req_rd_valid;
  assign req_rd_ready            = native_req.rd_req_ready;
  assign req_rd_rsp_data         = native_req.rd_rsp_data;
  assign req_rd_rsp_resp         = native_req.rd_rsp_resp;
  assign req_rd_rsp_valid        = native_req.rd_rsp_valid;
  assign native_req.rd_rsp_ready = req_rd_rsp_ready;

  // Target side
  assign tgt_wr_addr             = native_tgt.wr_req_addr;
  assign tgt_wr_data             = native_tgt.wr_req_data;
  assign tgt_wr_strb             = native_tgt.wr_req_strb;
  assign tgt_wr_prot             = native_tgt.wr_req_prot;
  assign tgt_wr_valid            = native_tgt.wr_req_valid;
  assign native_tgt.wr_req_ready = tgt_wr_ready;
  assign native_tgt.wr_rsp_resp  = native_resp_e'(tgt_wr_rsp_resp);
  assign native_tgt.wr_rsp_valid = tgt_wr_rsp_valid;
  assign tgt_wr_rsp_ready        = native_tgt.wr_rsp_ready;
  assign tgt_rd_addr             = native_tgt.rd_req_addr;
  assign tgt_rd_prot             = native_tgt.rd_req_prot;
  assign tgt_rd_valid            = native_tgt.rd_req_valid;
  assign native_tgt.rd_req_ready = tgt_rd_ready;
  assign native_tgt.rd_rsp_data  = tgt_rd_rsp_data;
  assign native_tgt.rd_rsp_resp  = native_resp_e'(tgt_rd_rsp_resp);
  assign native_tgt.rd_rsp_valid = tgt_rd_rsp_valid;
  assign tgt_rd_rsp_ready        = native_tgt.rd_rsp_ready;

endmodule
