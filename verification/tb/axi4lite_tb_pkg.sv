// Shared testbench types and helpers.
package axi4lite_tb_pkg;

  // Normalized transaction observed on any channel. Fields that a channel
  // does not carry are zero. Responses use the 2-bit AXI encoding; the native
  // encodings for OKAY/TARGET_ERR/DECODE_ERR are identical to
  // OKAY/SLVERR/DECERR, so both sides compare directly.
  typedef struct packed {
    logic [31:0] addr;
    logic [63:0] data;
    logic [7:0]  strb;
    logic [2:0]  prot;
    logic [1:0]  resp;
  } txn_t;

  // True with a probability of pct percent.
  function automatic bit chance(input int unsigned pct);
    return $urandom_range(99) < pct;
  endfunction

  // Integer plusarg +<name>=<value>, or dflt when absent.
  function automatic int unsigned plusarg_int(input string name,
                                              input int unsigned dflt);
    int unsigned value;
    if ($value$plusargs({name, "=%d"}, value)) begin
      return value;
    end
    return dflt;
  endfunction

  function automatic string txn_str(input txn_t t);
    return $sformatf("addr=%08h data=%016h strb=%02h prot=%0d resp=%0d",
                     t.addr, t.data, t.strb, t.prot, t.resp);
  endfunction

endpackage
