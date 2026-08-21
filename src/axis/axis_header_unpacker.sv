module axis_header_unpacker #(
    parameter int DATA_WIDTH   = 8,
    parameter int HEADER_WORDS = 1
) (
    input logic clk,
    input logic rst,

    axis_if.slave  s_axis,
    axis_if.master m_axis,

    output logic [HEADER_WORDS*DATA_WIDTH-1:0] header,
    output logic header_valid,
    output logic header_error
);

  localparam int HEADER_INDEX_WIDTH = (HEADER_WORDS <= 1) ? 1 : $clog2(HEADER_WORDS);
  localparam logic [HEADER_INDEX_WIDTH-1:0] LAST_HEADER_INDEX =
      HEADER_INDEX_WIDTH'(HEADER_WORDS - 1);

  typedef enum logic [0:0] {
    ST_HEADER,
    ST_PAYLOAD
  } state_t;

  state_t state;
  logic [HEADER_INDEX_WIDTH-1:0] header_index;

  wire input_fire = s_axis.tvalid && s_axis.tready;
  wire last_header_word = header_index == LAST_HEADER_INDEX;

  assign s_axis.tready = (state == ST_PAYLOAD) ? m_axis.tready : 1'b1;

  assign m_axis.tvalid = state == ST_PAYLOAD && s_axis.tvalid;
  assign m_axis.tdata  = s_axis.tdata;
  assign m_axis.tlast  = state == ST_PAYLOAD && s_axis.tlast;

  initial begin
    if (DATA_WIDTH <= 0) begin
      $fatal(1, "axis_header_unpacker DATA_WIDTH must be greater than zero");
    end

    if (HEADER_WORDS <= 0) begin
      $fatal(1, "axis_header_unpacker HEADER_WORDS must be greater than zero");
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= ST_HEADER;
      header_index <= '0;
      header <= '0;
      header_valid <= 1'b0;
      header_error <= 1'b0;
    end else begin
      header_valid <= 1'b0;
      header_error <= 1'b0;

      if (input_fire) begin
        unique case (state)
          ST_HEADER: begin
            header[HEADER_WORDS*DATA_WIDTH-1-header_index*DATA_WIDTH-:DATA_WIDTH] <= s_axis.tdata;

            if (last_header_word) begin
              header_valid <= 1'b1;
              header_index <= '0;
              state <= s_axis.tlast ? ST_HEADER : ST_PAYLOAD;
            end else if (s_axis.tlast) begin
              header_index <= '0;
              header_error <= 1'b1;
            end else begin
              header_index <= header_index + 1'b1;
            end
          end

          default: begin
            if (s_axis.tlast) begin
              state <= ST_HEADER;
            end
          end
        endcase
      end
    end
  end

endmodule
