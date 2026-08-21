module deserializer_flat_tb;
  localparam int G_CH_NUM = 4;
  localparam int G_DATA_WIDTH = 13;

  logic clk;
  logic clk_user;
  logic rst;

  axis_if #(.DATA_WIDTH(G_DATA_WIDTH)) s_axis ();
  axis_if #(.DATA_WIDTH(G_DATA_WIDTH)) m_axis [G_CH_NUM] ();

  logic [G_CH_NUM * G_DATA_WIDTH - 1:0] m_axis_tdata_flat;
  logic [G_CH_NUM - 1:0]                m_axis_tvalid_flat;
  logic [G_CH_NUM - 1:0]                m_axis_tready_flat;
  logic [G_CH_NUM - 1:0]                m_axis_tlast_flat;

  assign clk_user = clk;

  for (genvar i = 0; i < G_CH_NUM; i++) begin : gen_m_axis
    assign m_axis[i].tdata  = m_axis_tdata_flat[i * G_DATA_WIDTH +: G_DATA_WIDTH];
    assign m_axis[i].tvalid = m_axis_tvalid_flat[i];
    assign m_axis_tready_flat[i] = m_axis[i].tready;
    assign m_axis[i].tlast  = m_axis_tlast_flat[i];
  end

  deserializer_flat #(
    .G_CH_NUM(G_CH_NUM),
    .G_DATA_WIDTH(G_DATA_WIDTH)
  ) dut (
    .clk_in(clk),
    .clk_user,
    .rst,
    .s_axis_tdata(s_axis.tdata),
    .s_axis_tvalid(s_axis.tvalid),
    .s_axis_tready(s_axis.tready),
    .s_axis_tlast(s_axis.tlast),
    .m_axis_tdata(m_axis_tdata_flat),
    .m_axis_tvalid(m_axis_tvalid_flat),
    .m_axis_tready(m_axis_tready_flat),
    .m_axis_tlast(m_axis_tlast_flat)
  );

endmodule
