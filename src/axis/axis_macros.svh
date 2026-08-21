`ifndef AXIS_MACROS_SVH
`define AXIS_MACROS_SVH

`define AXIS(port_name, inp)  \
  .``port_name``_tdata(inp.tdata),   \
  .``port_name``_tvalid(inp.tvalid), \
  .``port_name``_tready(inp.tready), \
  .``port_name``_tlast(inp.tlast)

`define AXIS_LITE(port_name, inp)  \
  .``port_name``_tdata(inp.tdata),   \
  .``port_name``_tvalid(inp.tvalid), \
  .``port_name``_tlast(inp.tlast)

`define AXIS_BUS(port_name, bus)  \
  .``port_name``_tdata(bus``_tdata),   \
  .``port_name``_tvalid(bus``_tvalid), \
  .``port_name``_tready(bus``_tready), \
  .``port_name``_tlast(bus``_tlast)

`define AXIS_BUS_DECLARE(bus, slots, width = 32) \
  logic [(slots)-1:0] bus``_tvalid; \
  logic [(slots)-1:0] bus``_tready; \
  logic [(slots)*(width)-1:0] bus``_tdata; \
  logic [(slots)-1:0] bus``_tlast;

`define AXIS_TO_BUS(bus, index, inp, width = 32) \
  assign bus``_tdata[((index)+1)*(width)-1:(index)*(width)] = inp.tdata; \
  assign bus``_tvalid[(index)] = inp.tvalid; \
  assign inp.tready = bus``_tready[(index)]; \
  assign bus``_tlast[(index)] = inp.tlast;

`define AXIS_FROM_BUS(outp, bus, index, width = 32) \
  assign outp.tdata = bus``_tdata[((index)+1)*(width)-1:(index)*(width)]; \
  assign outp.tvalid = bus``_tvalid[(index)]; \
  assign bus``_tready[(index)] = outp.tready; \
  assign outp.tlast = bus``_tlast[(index)];

`define AXIS_TO_LITE(outp, inp) \
  assign outp.tdata = inp.tdata; \
  assign outp.tvalid = inp.tvalid; \
  assign inp.tready = 1'b1; \
  assign outp.tlast = inp.tlast;

`define AXIS_WO_TLAST(port_name, inp)  \
  .``port_name``_tdata(inp.tdata), \
  .``port_name``_tvalid(inp.tvalid), \
  .``port_name``_tready(inp.tready)

`define AXIS_UPPER(port_name, inp)  \
  .``port_name``_TDATA(inp.tdata),   \
  .``port_name``_TVALID(inp.tvalid), \
  .``port_name``_TREADY(inp.tready), \
  .``port_name``_TLAST(inp.tlast)

`define AXIS_UPPER_WO_TLAST(port_name, inp)  \
  .``port_name``_TDATA(inp.tdata), \
  .``port_name``_TVALID(inp.tvalid), \
  .``port_name``_TREADY(inp.tready)

`define AXIS_CONNECT(dst, operator, src) \
  dst.tdata operator src.tdata; \
  dst.tvalid operator src.tvalid; \
  dst.tlast operator src.tlast; \
  src.tready operator dst.tready;

`define AXIS_VALID_ENABLE(dst, src, enable) \
  assign dst.tvalid = src.tvalid && enable; \
  assign dst.tdata = src.tdata; \
  assign dst.tlast = src.tlast;

`define MARK_DEBUG_AXIS_IF(sig, width = 32) \
  (* mark_debug = "true" *) wire sig``_tvalid_dbg = sig.tvalid; \
  (* mark_debug = "true" *) wire sig``_tready_dbg = sig.tready; \
  (* mark_debug = "true" *) wire [(width)-1:0] sig``_tdata_dbg = sig.tdata; \
  (* mark_debug = "true" *) wire sig``_tlast_dbg = sig.tlast

`define MARK_DEBUG_AXIS_COMPLEX_IF(sig) \
  (* mark_debug = "true" *) wire sig``_tvalid_dbg = sig.tvalid; \
  (* mark_debug = "true" *) wire sig``_tready_dbg = sig.tready; \
  (* mark_debug = "true" *) wire signed [31:0] sig``_tdata_re_dbg = sig.tdata.re; \
  (* mark_debug = "true" *) wire signed [31:0] sig``_tdata_im_dbg = sig.tdata.im; \
  (* mark_debug = "true" *) wire sig``_tlast_dbg = sig.tlast

`endif
