# axi4lite-core

[![CI](https://github.com/vohoangnguyennnn/axi4lite-core/actions/workflows/ci.yml/badge.svg)](https://github.com/vohoangnguyennnn/axi4lite-core/actions/workflows/ci.yml)

AXI4-Lite master and slave adapters in synthesizable SystemVerilog, with SVA
protocol checkers, a randomized regression, functional coverage, and CI.

The adapters translate between the AMBA AXI4-Lite protocol and a simple
valid/ready **native request/response interface**:

- `axi4lite_master_adapter` lets a native requester (for example a CPU
  load/store unit) issue AXI4-Lite transactions.
- `axi4lite_slave_adapter` lets an AXI4-Lite master reach a native target
  (for example a register file or a peripheral).

```
                    axi4lite_master_adapter            axi4lite_slave_adapter
 native requester  +-----------------------+  AXI4-Lite  +-----------------------+  native target
 ----------------->| native      m_axi     |------------>| s_axi       native    |--------------->
    (CPU, DMA)     | (target)    (master)  |  AW W B AR R| (slave)     (requester)|  (registers,
 <-----------------|                       |<------------|                       |<---------------  peripherals)
                   +-----------------------+             +-----------------------+
```

## Contents

- [Features and scope](#features-and-scope)
- [Repository layout](#repository-layout)
- [Interfaces](#interfaces)
- [Adapters](#adapters)
- [Integration](#integration)
- [Verification](#verification)
- [Known limitations](#known-limitations)
- [References](#references)
- [License](#license)

## Features and scope

**Supported**

- All AXI4-Lite channels and signals: `AW`, `W`, `B`, `AR`, `R`, with
  `AxPROT` and `WSTRB`.
- `DATA_WIDTH` of 32 or 64 bits, the widths AXI4-Lite allows. `ADDR_WIDTH`
  is a parameter (default 32).
- Responses `OKAY`, `SLVERR`, and `DECERR`, mapped to and from native
  responses.
- Independent read and write paths, so a read and a write can be in flight
  at the same time.
- Write address and write data accepted in any order by the slave adapter:
  AW first, W first, or both in the same cycle.
- Registered outputs on both sides. No combinational path crosses an
  adapter.

**Not supported, by design**

- Exclusive accesses. AXI4-Lite has none, so `EXOKAY` is never generated.
  An `EXOKAY` received by the master adapter is reported as a native target
  error.
- More than one outstanding transaction per direction in each adapter.
  AXI4-Lite does not require it, and the adapters apply backpressure instead
  (see [Latency and throughput](#latency-and-throughput)).
- Ordering between reads and writes. AXI does not order the read and write
  channels against each other, and the adapters do not add ordering (see
  [Read/write ordering](#readwrite-ordering)).

## Repository layout

```
rtl/
  axi4lite_pkg.sv              Response enums and native <-> AXI response mapping
  axi4lite_if.sv               AXI4-Lite interface (master / slave / monitor modports)
  native_req_rsp_if.sv         Native request/response interface
  axi4lite_master_adapter.sv   Native requester -> AXI4-Lite master
  axi4lite_slave_adapter.sv    AXI4-Lite slave -> native target
verification/
  checkers/                    SVA protocol checkers for both interfaces
  lint/                        Lint wrapper that elaborates the whole design
  tb/                          Reusable bench components (drivers, models, monitors, scoreboard)
  tests/
    checker/                   Checker self-test (legal and illegal scenarios)
    master/ slave/ loopback/   Randomized regression benches
    common/                    Shared suite runner and simulation main
scripts/
  run_lint.sh                  Verilator lint at DATA_WIDTH 32 and 64
  run_regression.sh            Runs the test suites
  coverage_report.py           Merges and checks functional coverage
.github/workflows/ci.yml       CI: lint, regression, and coverage
```

## Interfaces

### `axi4lite_if`

```systemverilog
axi4lite_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) axi (ACLK, ARESETn);
```

| Channel | Signals |
|---|---|
| Write address | `AWADDR`, `AWPROT[2:0]`, `AWVALID`, `AWREADY` |
| Write data | `WDATA`, `WSTRB[DATA_WIDTH/8-1:0]`, `WVALID`, `WREADY` |
| Write response | `BRESP[1:0]`, `BVALID`, `BREADY` |
| Read address | `ARADDR`, `ARPROT[2:0]`, `ARVALID`, `ARREADY` |
| Read data | `RDATA`, `RRESP[1:0]`, `RVALID`, `RREADY` |

Modports: `master`, `slave`, and `monitor` (all inputs, for checkers and
monitors). `BRESP` and `RRESP` are plain 2-bit vectors, so Verilog or VHDL
IP and verification IP connect without enum casts. Decode them with
`axi4lite_pkg::axi_resp_e`.

The interface calls `$fatal` at the start of simulation if `DATA_WIDTH` is
not 32 or 64, or if `ADDR_WIDTH` has fewer bits than the byte offset within
one data word.

### `native_req_rsp_if`

```systemverilog
native_req_rsp_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) native (ACLK, ARESETn);
```

| Channel | Signals | Driven by |
|---|---|---|
| Write request | `wr_req_addr`, `wr_req_data`, `wr_req_strb`, `wr_req_prot`, `wr_req_valid` / `wr_req_ready` | requester / target |
| Write response | `wr_rsp_resp`, `wr_rsp_valid` / `wr_rsp_ready` | target / requester |
| Read request | `rd_req_addr`, `rd_req_prot`, `rd_req_valid` / `rd_req_ready` | requester / target |
| Read response | `rd_rsp_data`, `rd_rsp_resp`, `rd_rsp_valid` / `rd_rsp_ready` | target / requester |

Modports: `requester`, `target`, and `monitor`.

**Protocol rules.** All of them are checked by
`verification/checkers/native_req_rsp_checker.sv`:

1. A transfer happens on a rising edge where `valid` and `ready` are both
   high. Once `valid` is high, it and the payload must stay stable until
   that transfer.
2. At most one request per direction is outstanding. A new request may
   transfer only after the response to the previous one has transferred.
3. A response may be presented only after its request transferred on an
   earlier edge. Responses in the same cycle as the request are not allowed.
4. Reads and writes are independent of each other.
5. During reset, every `valid` and `ready` is low.

**Response encoding** (`axi4lite_pkg`):

| Native `*_rsp_resp` | Value | AXI `xRESP` |
|---|---|---|
| `NATIVE_RESP_OKAY` | `2'b00` | `OKAY` |
| `NATIVE_RESP_TARGET_ERR` | `2'b10` | `SLVERR` |
| `NATIVE_RESP_DECODE_ERR` | `2'b11` | `DECERR` |
| reserved | `2'b01` | forbidden. If it appears anyway, the slave adapter returns `SLVERR`. |

In the other direction, AXI `EXOKAY` (`2'b01`) and unknown values map to
`NATIVE_RESP_TARGET_ERR`.

## Adapters

Both adapters take `ADDR_WIDTH` and `DATA_WIDTH` parameters. These must
match the connected interfaces; a mismatch calls `$fatal` at the start of
simulation.

### `axi4lite_master_adapter`

```systemverilog
axi4lite_master_adapter #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) u_master (
  .native (native),  // native_req_rsp_if.target
  .m_axi  (axi)      // axi4lite_if.master
);
```

- A native write request is registered. `AWVALID` and `WVALID` are then
  raised together, and each drops independently when its own handshake
  completes.
- `BREADY` is raised only after both AW and W have transferred. The B
  response is registered and presented on `wr_rsp_*`.
- A read request is registered and drives `ARVALID`. `RREADY` is raised
  after AR has transferred. `RDATA` and `RRESP` are registered and presented
  on `rd_rsp_*`.
- `wr_req_ready` and `rd_req_ready` stay low from request acceptance until
  the native response transfers. This gives one outstanding transaction per
  direction.

```
Write through the master adapter, AXI slave answering at the earliest legal cycle

cycle                   0     1     2     3     4
native wr_req  (V&R)   HS                      HS   <- next request
AXI AW + W     (V&R)         HS
AXI B          (V&R)               HS
native wr_rsp  (V&R)                     HS
```

### `axi4lite_slave_adapter`

```systemverilog
axi4lite_slave_adapter #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) u_slave (
  .s_axi  (axi),     // axi4lite_if.slave
  .native (native)   // native_req_rsp_if.requester
);
```

- `AWREADY` and `WREADY` are high while their holding register is empty,
  so AW and W are captured independently and in any order.
- The native write request is raised once both halves are captured.
  `BVALID` is raised after the native response arrives. BVALID therefore
  always comes after both AW and W handshakes, as AXI requires.
- The AW and W registers are released when B transfers. Until then,
  `AWREADY` and `WREADY` stay low.
- Reads work the same way: AR is captured, the native read request is
  raised, and the native response becomes `RVALID`, `RDATA`, and `RRESP`.
- An AXI master may issue further AW, W, or AR before the current response.
  The adapter holds them off with `xREADY` low until the current
  transaction completes.

```
Write through the slave adapter, native target answering at the earliest legal cycle

cycle                   0     1     2     3     4
AXI AW + W     (V&R)   HS                      HS   <- next write
native wr_req  (V&R)         HS
native wr_rsp  (V&R)               HS
AXI B          (V&R)                     HS
```

### Latency and throughput

These numbers were measured in simulation. Every partner (requester, AXI
slave, AXI master, native target) is always ready and responds at the
earliest cycle its protocol allows. Latency counts from the request
handshake to the response handshake, and reads and writes behave the same.

| Path | Latency | Max throughput per direction |
|---|---|---|
| Master adapter (native request -> native response) | 3 cycles | 1 transaction / 4 cycles |
| Slave adapter (AXI AW+W or AR -> AXI B or R) | 3 cycles | 1 transaction / 4 cycles |
| Loopback, master -> slave (native -> native) | 5 cycles | 1 transaction / 6 cycles |

If a partner is slower, its extra cycles add directly to these numbers.
Because read and write run in parallel, the combined throughput is twice
the per-direction figure.

## Integration

### Compile order

Compile `rtl/axi4lite_pkg.sv` first, then the interfaces, then the
adapters:

```
rtl/axi4lite_pkg.sv
rtl/axi4lite_if.sv
rtl/native_req_rsp_if.sv
rtl/axi4lite_master_adapter.sv
rtl/axi4lite_slave_adapter.sv
```

### Clock and reset

- Both adapters use one clock (`ACLK`) and an active-low reset (`ARESETn`)
  taken from the connected interfaces. There is no clock-domain crossing.
- `ARESETn` is applied asynchronously, but **it must be released
  synchronously to `ACLK`**, as the AXI specification requires. Drive it
  from a reset synchronizer in the `ACLK` domain.
- During reset every VALID and READY output is low. The first VALID can
  rise only on a clock edge after reset is released.

### Read/write ordering

Reads and writes go through independent paths. A read issued while an
earlier write is still in flight can reach the target first, and return
the old data.

If ordering matters to you, enforce it upstream. For example, a CPU
load/store unit should wait for the write response before issuing a load
to the same address. MMIO sequences such as "write a command register, then
read a status register" need the same care.

### Using the core in a RISC-V SoC

The core suits a **peripheral / MMIO bus**: UART, GPIO, timers, CLINT/PLIC,
and IP configuration registers. Notes for integration:

- **Stores smaller than a word.** For `sb` and `sh`, the load/store unit
  must place the data on the correct byte lanes and generate `WSTRB`. The
  adapter passes both through unchanged.
- **Loads smaller than a word.** AXI4-Lite always returns a full data word.
  For `lb`, `lh`, `lbu`, and `lhu`, the CPU extracts the byte or half-word
  and sign- or zero-extends it.
- **Misaligned accesses.** A single AXI4-Lite transfer cannot cross a word
  boundary. Raise a misaligned exception, or split the access into two.
- **Access faults.** `SLVERR` and `DECERR` arrive as `TARGET_ERR` and
  `DECODE_ERR`. Map them to access-fault exceptions: instruction access
  fault (`mcause` 1), load access fault (5), or store/AMO access fault (7).
- **Protection bits.** Set `AxPROT[0]` for privileged (M/S-mode) accesses
  and `ARPROT[2]` for instruction fetches.
- **Atomics.** The A extension has no bus support, because AXI4-Lite has no
  exclusive access. With a single core and no other bus masters, LR/SC and
  AMOs can be implemented inside the core.
- **Main memory path.** With one transaction every 4 cycles per direction,
  put instruction fetch and data memory on caches or tightly coupled memory,
  not directly on this bus.

## Verification

### Requirements

- [Verilator](https://verilator.org) 5.x. The flow is tested with 5.020,
  the version packaged in Ubuntu 24.04 (`sudo apt-get install verilator`).
- GNU make, bash, a C++ compiler (needed by Verilator), and Python 3 for the
  coverage report.

### Quick start

```sh
make lint                  # Verilator -Wall on all RTL and checkers, DATA_WIDTH 32 and 64
make test                  # every test suite
make coverage              # every test suite, then the functional coverage check
make test-loopback SEED=42 # one suite with a fixed seed
make help                  # all targets
```

| Target | What it runs |
|---|---|
| `lint` | `scripts/run_lint.sh`. Any warning fails, and there are no waivers on the RTL. |
| `test` | All suites below |
| `test-checker` | Checker self-test |
| `test-master` / `test-slave` / `test-loopback` | One regression suite |
| `coverage` | `test`, then `scripts/coverage_report.py` |
| `clean` | Removes `build/` |

`SEED` accepts `1..2147483647`, the range Verilator allows. When omitted, a
time-based seed is chosen, and the seed in use is always printed. Build
output goes to `build/`, or to `REGRESSION_BUILD_ROOT` if you set it.

### Test suites

| Suite | Topology | Checks |
|---|---|---|
| `checker` | The bench drives both sides of an AXI4-Lite bus directly | 15 scenarios, each run under both checker rule sets (30 runs). Legal traffic must pass, and each illegal scenario must trip its intended assertion. |
| `master` | Random native requester -> master adapter -> random AXI slave | Scoreboard plus all checkers |
| `slave` | Random AXI master -> slave adapter -> random native target | Scoreboard plus all checkers |
| `loopback` | Random requester -> master adapter -> slave adapter -> random target | End-to-end scoreboard plus all checkers |

The `master`, `slave`, and `loopback` suites build at `DATA_WIDTH` 32 and
64, and run four variants on each build:

| Variant | Behavior |
|---|---|
| `random` | Requests, READY, and responses at 50% probability per cycle; 20% error responses |
| `fast` | Everything at 100%: back-to-back transfers, no stalls |
| `slow` | Everything at 15%: long backpressure on every channel |
| `reset` | `random` traffic, plus an asynchronous reset at cycle 1500 with transactions in flight |

How the benches check the design:

- The random AXI master drives AW and W with independent delays and keeps up
  to 2 writes and 2 reads outstanding. This exercises AW-first, W-first,
  same-cycle, and slave backpressure.
- Monitors turn handshakes into transactions.
- An in-order scoreboard compares both ends of each path: address, data,
  strobes, PROT, and response code.
- A run passes only if every scoreboard queue is empty at the end and the
  expected number of transactions completed.

**Reproducing a failure.** The runner prints the exact command to rerun a
failing case, for example:

```sh
build/loopback/dw32/sim +verilator+seed+42 +REQ_RATE=50 +RSP_READY_RATE=50 \
    +READY_RATE=50 +RSP_RATE=50 +ERR_RATE=20
```

| Bench plusarg | Meaning (default) |
|---|---|
| `+NUM_TXN` | Transactions per direction (500) |
| `+REQ_RATE`, `+RSP_READY_RATE` | % chance of a new request / response READY per cycle (50) |
| `+READY_RATE`, `+RSP_RATE` | % chance of request READY / starting a pending response (50) |
| `+ERR_RATE` | % of responses that are errors (20) |
| `+AXI_OUTSTANDING` | Outstanding transactions from the random AXI master (2) |
| `+RESET_AT`, `+RESET_LEN` | Mid-run reset at this cycle, for this many cycles (off, 5) |
| `+TIMEOUT` | Watchdog in cycles (500000) |

### Protocol checkers

`axi4lite_protocol_checker` binds to any `axi4lite_if` through its
`monitor` modport:

```systemverilog
axi4lite_protocol_checker #(
  .STRICT_PROFILE (1'b1),  // 1: also enforce this project's profile
  .DATA_WIDTH     (32)     // must match the interface
) u_axi_checker (.axi(axi));
```

| Assertion | Rule |
|---|---|
| `a_axi_{aw,w,b,ar,r}_stable` | Once VALID is high, VALID and payload stay stable until the handshake |
| `a_axi_bvalid_has_aw_and_w` | BVALID only after both AW and W handshakes, on an earlier edge |
| `a_axi_rvalid_has_ar` | RVALID only after an AR handshake, on an earlier edge |
| `a_axi_no_exokay_{b,r}` | No `EXOKAY`, because AXI4-Lite has no exclusive access |
| `a_axi_valid_ready_known` | VALID and READY are never X or Z outside reset |
| `a_axi_*_payload_known` | No X or Z payload while VALID is high. For WDATA, only strobed byte lanes are checked. |
| `a_axi_reset_valid_low` | Every VALID is low during reset |
| `a_axi_reset_exit_valid_low` | Every VALID is still low on the first edge after reset is released |
| `a_checker_capacity` | Outstanding transactions stay within `MAX_OUTSTANDING` (checker limit, default 16) |
| `a_profile_no_second_{aw,w,ar}` | Only with `STRICT_PROFILE=1`: at most one transaction in flight per direction |
| `a_profile_reset_ready_low` | Only with `STRICT_PROFILE=1`: every READY is low during reset |

With `STRICT_PROFILE=0`, the checker applies only the AXI4-Lite rules. Use
that setting on a bus where the other side is third-party IP that may keep
several transactions outstanding.

`native_req_rsp_checker` enforces the
[native protocol rules](#native_req_rsp_if) listed above.

### Functional coverage

The checkers also contain 23 `cover property` points. They cover:

- AW/W ordering: AW first, W first, same cycle, and one half stalled while
  the other transfers.
- Backpressure on every channel.
- Concurrent reads and writes.
- Every `BRESP` and `RRESP` code.
- `WSTRB` with no lanes, some lanes, and all lanes.
- Reset while a transaction is in flight.

`make coverage` merges the hits from all runs of the three regression suites
and fails if any point was never hit. The report lists hits per suite, which
also shows how the design behaves. For example, `c_b_backpressure` is hit
only in the `slave` suite, because the master adapter raises `BREADY` only
after AW and W complete and so never stalls B.

### Continuous integration

`.github/workflows/ci.yml` runs on every pull request, on pushes to `main`,
and on manual dispatch:

- It installs Verilator on `ubuntu-24.04`, then runs `make lint` and
  `make coverage`.
- The seed comes from the run ID, or from the `seed` input of a manual run.
  It is printed in the log so a failure can be reproduced locally with
  `make coverage SEED=<seed>`.
- On failure, logs are uploaded as an artifact.

## Known limitations

- **One outstanding transaction per direction in each adapter.** This is
  correct AXI4-Lite, but it limits throughput (see
  [Latency and throughput](#latency-and-throughput)).
- **No read/write ordering.** See [Read/write ordering](#readwrite-ordering).
- **X/Z assertions are not exercised.** Verilator simulates two-state, so
  it cannot produce X values. These assertions need a four-state simulator.
- **No formal verification** of the adapters yet.
- **No waveform dumps** from the regression benches yet.

## References

- Arm, *AMBA AXI Protocol Specification* (IHI 0022). See the AXI4-Lite
  chapter, and the sections on channel handshakes, transaction dependencies,
  and reset.

## License

Apache License 2.0. See [LICENSE](LICENSE).
