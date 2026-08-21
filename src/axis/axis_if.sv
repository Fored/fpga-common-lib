interface axis_if #(
    parameter int DATA_WIDTH = 32
);
  logic tvalid;
  logic tready;
  logic [DATA_WIDTH-1:0] tdata;
  logic tlast;

  modport master(output tvalid, input tready, output tdata, output tlast);
  modport slave(input tvalid, output tready, input tdata, input tlast);
  modport monitor(input tvalid, input tready, input tdata, input tlast);
endinterface

interface axis_lite_if #(
    parameter type DATA_T = logic [31:0]
);
  logic  tvalid;
  DATA_T tdata;
  logic  tlast;

  modport master(output tvalid, output tdata, output tlast);
  modport slave(input tvalid, input tdata, input tlast);
  modport monitor(input tvalid, input tdata, input tlast);
endinterface

typedef struct packed {
  logic signed [31:0] im;
  logic signed [31:0] re;
} axis_complex32_t;

interface axis_complex_if #(
    parameter type COMPLEX_T = axis_complex32_t
);
  logic tvalid;
  logic tready;
  COMPLEX_T tdata;
  logic tlast;

  modport master(output tvalid, input tready, output tdata, output tlast);
  modport slave(input tvalid, output tready, input tdata, input tlast);
  modport monitor(input tvalid, input tready, input tdata, input tlast);
endinterface

interface axis_user_if #(
    parameter int DATA_WIDTH = 32,
    parameter int USER_WIDTH = 16
);
  logic tvalid;
  logic tready;
  logic [DATA_WIDTH-1:0] tdata;
  logic tlast;
  logic [USER_WIDTH-1:0] tuser;

  modport master(output tvalid, input tready, output tdata, output tlast, output tuser);
  modport slave(input tvalid, output tready, input tdata, input tlast, input tuser);
  modport monitor(input tvalid, input tready, input tdata, input tlast, input tuser);
endinterface
