module serializer_flat_tb;
  localparam int G_CH_NUM = 4;
  localparam int G_DATA_WIDTH = 13;

  logic clk_out;
  logic clk_user;
  logic rst;
  logic [6:0] data_in_num;

  axis_if #(.DATA_WIDTH(G_DATA_WIDTH)) s_axis [G_CH_NUM] ();
  axis_if #(.DATA_WIDTH(G_DATA_WIDTH)) m_axis ();

  logic [G_CH_NUM * G_DATA_WIDTH - 1:0] s_axis_tdata_flat;
  logic [G_CH_NUM - 1:0]                s_axis_tvalid_flat;
  logic [G_CH_NUM - 1:0]                s_axis_tready_flat;
  logic [G_CH_NUM - 1:0]                s_axis_tlast_flat;

  for (genvar i = 0; i < G_CH_NUM; i++) begin : gen_s_axis
    assign s_axis_tdata_flat[i * G_DATA_WIDTH +: G_DATA_WIDTH] = s_axis[i].tdata;
    assign s_axis_tvalid_flat[i] = s_axis[i].tvalid;
    assign s_axis[i].tready = s_axis_tready_flat[i];
    assign s_axis_tlast_flat[i] = s_axis[i].tlast;
  end

  serializer_flat #(
    .G_CH_NUM(G_CH_NUM),
    .G_DATA_WIDTH(G_DATA_WIDTH),
    .G_CLOCKING_MODE("independent_clock")
  ) dut (
    .clk_out,
    .clk_user,
    .rst,
    .data_in_num,
    .s_axis_tdata(s_axis_tdata_flat),
    .s_axis_tvalid(s_axis_tvalid_flat),
    .s_axis_tready(s_axis_tready_flat),
    .s_axis_tlast(s_axis_tlast_flat),
    .m_axis_tdata(m_axis.tdata),
    .m_axis_tvalid(m_axis.tvalid),
    .m_axis_tready(m_axis.tready),
    .m_axis_tlast(m_axis.tlast)
  );

endmodule
