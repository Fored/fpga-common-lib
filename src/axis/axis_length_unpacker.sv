module axis_length_unpacker #(
    parameter int DATA_WIDTH     = 8,
    parameter int WORDS_PER_ITEM = 1
) (
    input logic clk,
    input logic rst,

    axis_if.slave  s_axis,
    axis_if.master m_axis,

    output logic [DATA_WIDTH-1:0] length,
    output logic length_valid,
    output logic frame_error
);

  localparam int MULTIPLIER_WIDTH =
      (WORDS_PER_ITEM <= 1) ? 0 : $clog2(WORDS_PER_ITEM);
  localparam int REMAINING_WIDTH = DATA_WIDTH + MULTIPLIER_WIDTH;

  typedef enum logic {
    ST_LENGTH,
    ST_PAYLOAD
  } state_t;

  state_t state;
  logic [REMAINING_WIDTH-1:0] remaining_words;

  wire input_fire = s_axis.tvalid && s_axis.tready;
  wire logical_last = remaining_words == REMAINING_WIDTH'(1);
  wire [REMAINING_WIDTH-1:0] input_payload_words =
      REMAINING_WIDTH'(s_axis.tdata) * REMAINING_WIDTH'(WORDS_PER_ITEM);

  assign s_axis.tready = (state == ST_PAYLOAD) ? m_axis.tready : 1'b1;

  assign m_axis.tvalid = state == ST_PAYLOAD && s_axis.tvalid;
  assign m_axis.tdata  = s_axis.tdata;
  assign m_axis.tlast  = state == ST_PAYLOAD && (logical_last || s_axis.tlast);

  initial begin
    if (DATA_WIDTH <= 0) begin
      $fatal(1, "axis_length_unpacker DATA_WIDTH must be greater than zero");
    end

    if (WORDS_PER_ITEM <= 0) begin
      $fatal(1, "axis_length_unpacker WORDS_PER_ITEM must be greater than zero");
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= ST_LENGTH;
      remaining_words <= '0;
      length <= '0;
      length_valid <= 1'b0;
      frame_error <= 1'b0;
    end else begin
      length_valid <= 1'b0;
      frame_error <= 1'b0;

      if (input_fire) begin
        unique case (state)
          ST_LENGTH: begin
            length <= s_axis.tdata;
            length_valid <= 1'b1;

            if (s_axis.tdata == '0) begin
              remaining_words <= '0;
            end else if (s_axis.tlast) begin
              remaining_words <= '0;
              frame_error <= 1'b1;
            end else begin
              remaining_words <= input_payload_words;
              state <= ST_PAYLOAD;
            end
          end

          default: begin
            if (s_axis.tlast) begin
              if (!logical_last) begin
                frame_error <= 1'b1;
              end
              remaining_words <= '0;
              state <= ST_LENGTH;
            end else if (logical_last) begin
              remaining_words <= '0;
              state <= ST_LENGTH;
            end else begin
              remaining_words <= remaining_words - 1'b1;
            end
          end
        endcase
      end
    end
  end

endmodule
