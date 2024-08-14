module top (
    input clk,
    input rst,
    output [15:0] led
);

  light light0 (
    .clk(clk),
    .rst(rst),
    .led(led)
  );

endmodule
