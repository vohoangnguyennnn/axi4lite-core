// Passive monitor for native_req_rsp_if.
//
// Each *_evt output is high in a cycle that completes a handshake on that
// channel, with the normalized transaction on the matching *_txn output.
module native_monitor
  import axi4lite_tb_pkg::*;
(
  native_req_rsp_if.monitor native,
  output logic wr_req_evt,
  output txn_t wr_req_txn,
  output logic wr_rsp_evt,
  output txn_t wr_rsp_txn,
  output logic rd_req_evt,
  output txn_t rd_req_txn,
  output logic rd_rsp_evt,
  output txn_t rd_rsp_txn
);

  always_comb begin
    wr_req_evt      = native.wr_req_valid && native.wr_req_ready;
    wr_req_txn      = '0;
    wr_req_txn.addr = 32'(native.wr_req_addr);
    wr_req_txn.data = 64'(native.wr_req_data);
    wr_req_txn.strb = 8'(native.wr_req_strb);
    wr_req_txn.prot = native.wr_req_prot;

    wr_rsp_evt      = native.wr_rsp_valid && native.wr_rsp_ready;
    wr_rsp_txn      = '0;
    wr_rsp_txn.resp = native.wr_rsp_resp;

    rd_req_evt      = native.rd_req_valid && native.rd_req_ready;
    rd_req_txn      = '0;
    rd_req_txn.addr = 32'(native.rd_req_addr);
    rd_req_txn.prot = native.rd_req_prot;

    rd_rsp_evt      = native.rd_rsp_valid && native.rd_rsp_ready;
    rd_rsp_txn      = '0;
    rd_rsp_txn.data = 64'(native.rd_rsp_data);
    rd_rsp_txn.resp = native.rd_rsp_resp;
  end

endmodule
