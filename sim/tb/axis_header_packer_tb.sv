module axis_header_packer_tb;

  logic clk;
  logic rst;

  axis_if #(.DATA_WIDTH(8)) s_axis ();
  axis_if #(.DATA_WIDTH(8)) m_axis ();

  logic [31:0] header;

  axis_header_packer #(
      .DATA_WIDTH(8),
      .HEADER_WORDS(4)
  ) dut (
      .clk(clk),
      .rst(rst),
      .s_axis(s_axis.slave),
      .m_axis(m_axis.master),
      .header(header)
  );

endmodule
