module axis_length_unpacker_tb;

  logic clk;
  logic rst;

  axis_if #(.DATA_WIDTH(8)) s_axis ();
  axis_if #(.DATA_WIDTH(8)) m_axis ();

  logic [7:0] length;
  logic length_valid;
  logic frame_error;

  axis_length_unpacker #(
      .DATA_WIDTH(8),
      .WORDS_PER_ITEM(2)
  ) dut (
      .clk(clk),
      .rst(rst),
      .s_axis(s_axis.slave),
      .m_axis(m_axis.master),
      .length(length),
      .length_valid(length_valid),
      .frame_error(frame_error)
  );

endmodule
