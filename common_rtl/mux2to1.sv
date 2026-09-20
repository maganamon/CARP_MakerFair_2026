module mux2to1 #(parameter int WIDTH = 4)
(
    input  logic [WIDTH-1:0] a,  // Data input 0
    input  logic [WIDTH-1:0] b,  // Data input 1
    input  logic             sel,  // Select line (0 selects in0, 1 selects in1)
    output logic [WIDTH-1:0] f   // Mux output
);

    // Continuous assignment using the conditional (ternary) operator
    assign f = sel ? b : a;

endmodule
