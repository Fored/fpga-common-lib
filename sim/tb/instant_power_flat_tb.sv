module instant_power_flat_tb #(
  parameter int DATA_WIDTH = 32
);

  logic clk;

  axis_lite_if #(.DATA_T(logic [DATA_WIDTH-1:0])) s_axis ();
  axis_lite_if #(.DATA_T(logic [DATA_WIDTH-1:0])) m_axis ();

  instant_power_flat #(
    .G_DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk,

    .s_axis_tdata (s_axis.tdata),
    .s_axis_tvalid(s_axis.tvalid),
    .s_axis_tlast (s_axis.tlast),

    .m_axis_tdata (m_axis.tdata),
    .m_axis_tvalid(m_axis.tvalid),
    .m_axis_tlast (m_axis.tlast)
  );

endmodule
