`timescale 1ns / 1ps

`define headerSize 1080
`define imageSize 512*512

module tb(
    );
    
    reg clk;
    reg reset;
    reg [7:0] imgData;
    integer file, file1, i;
    integer scan_status; // ADDED: Variable to capture fscanf return value
    reg imgDataValid;
    integer sentSize;
    wire intr;
    wire [7:0] outData;
    wire outDataValid;
    integer receivedData = 0;

    // Clock Generation
    initial
    begin
        clk = 1'b0;
        forever
        begin
            #5 clk = ~clk;
        end
    end
    
    initial
    begin
        reset = 0;
        sentSize = 0;
        imgDataValid = 0;
        
        // Open files
        // NOTE: In Vivado, these files must be in the valid simulation directory
        // usually: project_name/project_name.sim/sim_1/behav/xsim/
        file = $fopen("lena_gray.bmp","rb");
        file1 = $fopen("blurred_lena.bmp","wb");
        
        // ERROR CHECKING: Check if file opened successfully
        if (file == 0) begin
            $display("ERROR: Can not open input file 'lena_gray.bmp'. Check file path!");
            $stop;
        end
        if (file1 == 0) begin
            $display("ERROR: Can not open output file 'blurred_lena.bmp'.");
            $stop;
        end

        #100;
        reset = 1;
        #100;
        
        // Read and Copy Header
        for(i = 0; i < `headerSize; i = i + 1)
        begin
            scan_status = $fscanf(file, "%c", imgData); // Captured return value
            $fwrite(file1, "%c", imgData);
        end
        
        // Send initial chunk (4 rows)
        for(i = 0; i < 4*512; i = i + 1)
        begin
            @(posedge clk);
            scan_status = $fscanf(file, "%c", imgData);
            imgDataValid <= 1'b1;
        end
        
        sentSize = 4*512;
        
        @(posedge clk);
        imgDataValid <= 1'b0;
        
        // Loop to send the rest of the image upon Interrupt
        while(sentSize < `imageSize)
        begin
            @(posedge intr); // Wait for interrupt from DUT
            
            for(i = 0; i < 512; i = i + 1)
            begin
                @(posedge clk);
                scan_status = $fscanf(file, "%c", imgData);
                imgDataValid <= 1'b1;    
            end
            
            @(posedge clk);
            imgDataValid <= 1'b0;
            sentSize = sentSize + 512;
        end
        
        // Flush / Finish sequence
        @(posedge clk);
        imgDataValid <= 1'b0;
        
        @(posedge intr);
        for(i = 0; i < 512; i = i + 1)
        begin
            @(posedge clk);
            imgData <= 0;
            imgDataValid <= 1'b1;    
        end
        
        @(posedge clk);
        imgDataValid <= 1'b0;
        
        @(posedge intr);
        for(i = 0; i < 512; i = i + 1)
        begin
            @(posedge clk);
            imgData <= 0;
            imgDataValid <= 1'b1;    
        end
        
        @(posedge clk);
        imgDataValid <= 1'b0;
        
        $fclose(file);
    end
    
    // Receive Data Logic
    always @(posedge clk)
    begin
         if(outDataValid)
         begin
             $fwrite(file1, "%c", outData);
             receivedData = receivedData + 1;
         end 
         
         if(receivedData == `imageSize)
         begin
            $fclose(file1);
            $display("Simulation Finished Successfully. Image Created.");
            $stop;
         end
    end
    
    imageProcessTop dut(
        .axi_clk(clk),
        .axi_reset_n(reset),
        //slave interface
        .i_data_valid(imgDataValid),
        .i_data(imgData),
        .o_data_ready(),
        //master interface
        .o_data_valid(outDataValid),
        .o_data(outData),
        .i_data_ready(1'b1),
        //interrupt
        .o_intr(intr)
    );   
        
endmodule