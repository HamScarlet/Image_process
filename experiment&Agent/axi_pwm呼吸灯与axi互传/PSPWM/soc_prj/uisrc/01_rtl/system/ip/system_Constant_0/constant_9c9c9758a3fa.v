
module constant_9c9c9758a3fa #(parameter WIDTH = 3, 
        parameter OUT_MODE = 1) (
    output [(WIDTH - 1):0] dout) ;
    assign dout = (OUT_MODE ? {WIDTH{1'b1}} : 'b0) ; 
endmodule


