package axi4lite_pkg;

  // AXI read and write response encodings.
  //
  // AXI4-Lite v1.0 supports OKAY, SLVERR, and DECERR. EXOKAY is kept in
  // this type so every 2-bit AXI response has an explicit name, but the
  // project does not implement exclusive accesses and must not generate it.
  typedef enum logic [1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
  } axi_resp_e;

  // Response semantics used by the native request/response interface.
  //
  // Encoding 2'b01 is intentionally omitted. It is reserved by the native
  // protocol and maps defensively to a target error if observed.
  typedef enum logic [1:0] {
    NATIVE_RESP_OKAY       = 2'b00,
    NATIVE_RESP_TARGET_ERR = 2'b10,
    NATIVE_RESP_DECODE_ERR = 2'b11
  } native_resp_e;

  // Map a native backend response onto the AXI response channel.
  function automatic axi_resp_e native_to_axi_resp(input native_resp_e resp);
    unique case (resp)
      NATIVE_RESP_OKAY:       return AXI_RESP_OKAY;
      NATIVE_RESP_TARGET_ERR: return AXI_RESP_SLVERR;
      NATIVE_RESP_DECODE_ERR: return AXI_RESP_DECERR;
      default:                return AXI_RESP_SLVERR;
    endcase
  endfunction

  // Map an AXI response onto the native response channel.
  //
  // EXOKAY is outside the project profile. Mapping it to TARGET_ERR allows
  // the native transaction to complete while a protocol checker reports the
  // unsupported response.
  function automatic native_resp_e axi_to_native_resp(input axi_resp_e resp);
    unique case (resp)
      AXI_RESP_OKAY:   return NATIVE_RESP_OKAY;
      AXI_RESP_SLVERR: return NATIVE_RESP_TARGET_ERR;
      AXI_RESP_DECERR: return NATIVE_RESP_DECODE_ERR;
      AXI_RESP_EXOKAY: return NATIVE_RESP_TARGET_ERR;
      default:         return NATIVE_RESP_TARGET_ERR;
    endcase
  endfunction

endpackage
