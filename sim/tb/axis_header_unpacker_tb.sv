module axis_header_unpacker_tb;

  logic clk;
  logic rst;

  axis_if #(.DATA_WIDTH(8)) s_axis ();
  axis_if #(.DATA_WIDTH(8)) m_axis ();

  logic [31:0] header;
  logic header_valid;
  logic header_error;

  axis_header_unpacker #(
      .DATA_WIDTH(8),
      .HEADER_WORDS(4)
  ) dut (
      .clk(clk),
      .rst(rst),
      .s_axis(s_axis.slave),
      .m_axis(m_axis.master),
      .header(header),
      .header_valid(header_valid),
      .header_error(header_error)
  );

endmodule
