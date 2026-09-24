// Random AXI4-Lite master.
//
// AW and W are driven from independent queues with independent random
// delays, so a write can present AW first, W first, or both together. Up to
// +AXI_OUTSTANDING writes and reads may be in flight, which exercises slave
// backpressure when the slave accepts fewer. Transactions lost to a mid-run
// reset are reissued until NUM_TXN of each direction complete.
//
// Plusargs: +NUM_TXN (default 500), +REQ_RATE (% chance per cycle to create a
// transaction or raise an idle VALID, default 50), +RSP_READY_RATE (% chance
// per cycle that BREADY/RREADY is high, default 50), +AXI_OUTSTANDING
// (default 2).
module axi4lite_master_driver
  import axi4lite_tb_pkg::*;
(
  axi4lite_if.master axi,
  output logic       done
);

  int unsigned num_txn;
  int unsigned req_rate;
  int unsigned rsp_ready_rate;
  int unsigned max_outstanding;

  int unsigned wr_created;
  int unsigned wr_done_cnt;
  int unsigned rd_created;
  int unsigned rd_done_cnt;

  // Pending halves. The front entry is the one currently driven when the
  // matching VALID is high.
  txn_t aw_q[$];
  txn_t w_q[$];
  txn_t ar_q[$];

  initial begin
    num_txn         = plusarg_int("NUM_TXN", 500);
    req_rate        = plusarg_int("REQ_RATE", 50);
    rsp_ready_rate  = plusarg_int("RSP_READY_RATE", 50);
    max_outstanding = plusarg_int("AXI_OUTSTANDING", 2);
    wr_created      = 0;
    wr_done_cnt     = 0;
    rd_created      = 0;
    rd_done_cnt     = 0;
  end

  assign done = (wr_done_cnt >= num_txn) && (rd_done_cnt >= num_txn);

  always @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      aw_q.delete();
      w_q.delete();
      ar_q.delete();
      wr_created  = wr_done_cnt;
      rd_created  = rd_done_cnt;
      axi.AWADDR  <= '0;
      axi.AWPROT  <= '0;
      axi.AWVALID <= 1'b0;
      axi.WDATA   <= '0;
      axi.WSTRB   <= '0;
      axi.WVALID  <= 1'b0;
      axi.BREADY  <= 1'b0;
      axi.ARADDR  <= '0;
      axi.ARPROT  <= '0;
      axi.ARVALID <= 1'b0;
      axi.RREADY  <= 1'b0;
    end else begin
      logic aw_hs;
      logic w_hs;
      logic ar_hs;
      txn_t t;

      aw_hs = axi.AWVALID && axi.AWREADY;
      w_hs  = axi.WVALID  && axi.WREADY;
      ar_hs = axi.ARVALID && axi.ARREADY;

      // Create new transactions.
      if ((wr_created < num_txn) &&
          (wr_created - wr_done_cnt < max_outstanding) && chance(req_rate)) begin
        t      = '0;
        t.addr = $urandom;
        t.prot = $urandom;
        t.data = {$urandom, $urandom};
        t.strb = $urandom;
        aw_q.push_back(t);
        w_q.push_back(t);
        wr_created++;
      end

      if ((rd_created < num_txn) &&
          (rd_created - rd_done_cnt < max_outstanding) && chance(req_rate)) begin
        t      = '0;
        t.addr = $urandom;
        t.prot = $urandom;
        ar_q.push_back(t);
        rd_created++;
      end

      // AW channel
      if (aw_hs) void'(aw_q.pop_front());
      if (!axi.AWVALID || aw_hs) begin
        if ((aw_q.size() != 0) && chance(req_rate)) begin
          axi.AWVALID <= 1'b1;
          axi.AWADDR  <= aw_q[0].addr;
          axi.AWPROT  <= aw_q[0].prot;
        end else begin
          axi.AWVALID <= 1'b0;
        end
      end

      // W channel
      if (w_hs) void'(w_q.pop_front());
      if (!axi.WVALID || w_hs) begin
        if ((w_q.size() != 0) && chance(req_rate)) begin
          axi.WVALID <= 1'b1;
          axi.WDATA  <= w_q[0].data[$bits(axi.WDATA)-1:0];
          axi.WSTRB  <= w_q[0].strb[$bits(axi.WSTRB)-1:0];
        end else begin
          axi.WVALID <= 1'b0;
        end
      end

      // B channel
      axi.BREADY <= chance(rsp_ready_rate);
      if (axi.BVALID && axi.BREADY) wr_done_cnt++;

      // AR channel
      if (ar_hs) void'(ar_q.pop_front());
      if (!axi.ARVALID || ar_hs) begin
        if ((ar_q.size() != 0) && chance(req_rate)) begin
          axi.ARVALID <= 1'b1;
          axi.ARADDR  <= ar_q[0].addr;
          axi.ARPROT  <= ar_q[0].prot;
        end else begin
          axi.ARVALID <= 1'b0;
        end
      end

      // R channel
      axi.RREADY <= chance(rsp_ready_rate);
      if (axi.RVALID && axi.RREADY) rd_done_cnt++;
    end
  end

endmodule
