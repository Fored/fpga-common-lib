module adder_tree_complex_tb #(
    parameter int CH_NUM = 4
);

  localparam int DATA_WIDTH = 8;
  localparam int SUM_WIDTH = DATA_WIDTH + $clog2(CH_NUM);

  logic clk;
  logic rst;
  logic signed [DATA_WIDTH-1:0] s_re [CH_NUM];
  logic signed [DATA_WIDTH-1:0] s_im [CH_NUM];
  logic s_valid;
  logic s_last;

  logic signed [SUM_WIDTH-1:0] m_re;
  logic signed [SUM_WIDTH-1:0] m_im;
  logic m_valid;
  logic m_last;

  adder_tree_complex #(
      .G_CH_NUM(CH_NUM),
      .G_DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk    (clk),
      .rst    (rst),
      .s_re   (s_re),
      .s_im   (s_im),
      .s_valid(s_valid),
      .s_last (s_last),
      .m_re   (m_re),
      .m_im   (m_im),
      .m_valid(m_valid),
      .m_last (m_last)
  );

endmodule
