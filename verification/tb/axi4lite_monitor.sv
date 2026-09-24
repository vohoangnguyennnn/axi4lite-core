// Passive monitor for axi4lite_if.
//
// AW and W handshakes are paired in order into one write request. Because a
// pair can complete on a later edge than either half, wr_req_evt is
// registered: it is high for one cycle after the edge that completes the pair.
// The other channels report combinationally in the handshake cycle.
module axi4lite_monitor
  import axi4lite_tb_pkg::*;
(
  axi4lite_if.monitor axi,
  output logic wr_req_evt,
  output txn_t wr_req_txn,
  output logic wr_rsp_evt,
  output txn_t wr_rsp_txn,
  output logic rd_req_evt,
  output txn_t rd_req_txn,
  output logic rd_rsp_evt,
  output txn_t rd_rsp_txn
);

  txn_t aw_q[$];
  txn_t w_q[$];

  always @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      aw_q.delete();
      w_q.delete();
      wr_req_evt <= 1'b0;
      wr_req_txn <= '0;
    end else begin
      txn_t aw;
      txn_t w;

      if (axi.AWVALID && axi.AWREADY) begin
        aw      = '0;
        aw.addr = 32'(axi.AWADDR);
        aw.prot = axi.AWPROT;
        aw_q.push_back(aw);
      end

      if (axi.WVALID && axi.WREADY) begin
        w      = '0;
        w.data = 64'(axi.WDATA);
        w.strb = 8'(axi.WSTRB);
        w_q.push_back(w);
      end

      wr_req_evt <= 1'b0;
      if ((aw_q.size() != 0) && (w_q.size() != 0)) begin
        aw         = aw_q.pop_front();
        w          = w_q.pop_front();
        aw.data    = w.data;
        aw.strb    = w.strb;
        wr_req_evt <= 1'b1;
        wr_req_txn <= aw;
      end
    end
  end

  always_comb begin
    wr_rsp_evt      = axi.BVALID && axi.BREADY;
    wr_rsp_txn      = '0;
    wr_rsp_txn.resp = axi.BRESP;

    rd_req_evt      = axi.ARVALID && axi.ARREADY;
    rd_req_txn      = '0;
    rd_req_txn.addr = 32'(axi.ARADDR);
    rd_req_txn.prot = axi.ARPROT;

    rd_rsp_evt      = axi.RVALID && axi.RREADY;
    rd_rsp_txn      = '0;
    rd_rsp_txn.data = 64'(axi.RDATA);
    rd_rsp_txn.resp = axi.RRESP;
  end

endmodule
