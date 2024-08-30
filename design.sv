// Code your design here
`timescale 1ns / 1ps
module pipe_mips(clk1,clk2);
  input clk1,clk2 ;
  reg [31:0]PC,IF_ID_NPC,IF_ID_IR ; //BETWEEN FETCH AND DECODE STAGE
  reg [31:0]ID_EX_NPC,ID_EX_IR,ID_EX_IMM,ID_EX_A,ID_EX_B ;//BETWEEN  DECODE AND EXCUTE STAGE
  reg [31:0]EX_MEM_IR,EX_MEM_B,EX_MEM_ALUOUT;
  reg EX_MEM_COND ;                          //BETWEEN  EXCUTE AND MEM STAGE
  reg [31:0]MEM_WB_IR,MEM_WB_ALUOUT,MEM_WB_LMD ; //BETWEEN  MEM AND WB STAGE
  
  reg [2:0] ID_EX_TYPE ,EX_MEM_TYPE , MEM_WB_TYPE ;
  reg HALTED , TAKEN_BRANCH ;
  
  reg [31:0] reg_bank [31:0] ;
  reg [31:0] inst_mem [1023:0];
  
  parameter ADD = 6'b000000 , SUB = 6'b000001 , AND = 6'b000010 , OR = 6'b000011 , SLT = 6'b000100 , MUL = 6'b000101 ,LW = 6'b001000 , SW = 6'b001001 ,ADDI = 6'b001010 ,SUBI = 6'b001011  , SLTI = 6'b001100 , BNEQZ=6'b001101, BEQZ=6'b001110, HLT = 6'b111111 ;
  
  parameter RR_ALU = 3'b000 , RI_ALU =3'b001 , LOAD = 3'b010 , STORE = 3'b011 , BRANCH = 3'b100 , HALT = 3'b101 ;
  
 ///STAGEI - FETCH  
  always@(posedge clk1)
    begin
      if(HALTED==0)
        begin
          if(((EX_MEM_COND ==1)&&(EX_MEM_IR[31:26]==BEQZ)) || ((EX_MEM_COND ==0)&&(EX_MEM_IR[31:26]==BNEQZ)))
            begin
              IF_ID_IR<= inst_mem[EX_MEM_ALUOUT];
              TAKEN_BRANCH <= 1'b1 ;
              PC <= EX_MEM_ALUOUT+1 ;
              IF_ID_NPC <=  EX_MEM_ALUOUT+1 ;
            end
          else
            begin
              IF_ID_IR<= inst_mem[PC] ;
              PC <= PC+1 ;
              IF_ID_NPC <= PC+1 ;
            end
        end      
    end
  
  ///STAGEII - DECODE 
  
  always @(posedge clk2)
    begin
      if(HALTED==0)
        begin
          ID_EX_IR <= IF_ID_IR ;
          ID_EX_NPC <= IF_ID_NPC ;          
          ID_EX_IMM <= {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};
          if(IF_ID_IR[25:21]==5'b00000)
            begin
              ID_EX_A <= 5'b00000;
            end
          else
            begin
              ID_EX_A <= reg_bank[IF_ID_IR[25:21]];
            end
          if(IF_ID_IR[20:16]==5'b00000)
            begin
              ID_EX_B <= 5'b00000;
            end
          else
            begin
              ID_EX_B <= reg_bank[IF_ID_IR[20:16]];
            end
          case(IF_ID_IR[31:26])
            ADD,SUB,AND,OR,SLT,MUL : ID_EX_TYPE <= RR_ALU ;
            ADDI,SUBI,SLTI         : ID_EX_TYPE <= RI_ALU ;
            LW                     : ID_EX_TYPE <= LOAD ;
            SW                     : ID_EX_TYPE <= STORE ;
            BEQZ,BNEQZ             : ID_EX_TYPE <= BRANCH ;
            HLT                    : ID_EX_TYPE <= HALT ;
            default                : ID_EX_TYPE <= HALT ;            
          endcase          
        end      
    end
  ///STAGEIII - EXCUTE 
  
  always@(posedge clk1)
    begin
      if(HALTED == 0)
        begin
          EX_MEM_IR <= ID_EX_IR ;
          EX_MEM_TYPE <= ID_EX_TYPE ; 
          TAKEN_BRANCH <= 0 ;
          
          case(ID_EX_TYPE)
            RR_ALU : begin
              case(ID_EX_IR[31:26])
                ADD  : EX_MEM_ALUOUT<= ID_EX_A + ID_EX_B ;
                SUB  : EX_MEM_ALUOUT<= ID_EX_A - ID_EX_B ;
                MUL  : EX_MEM_ALUOUT<= ID_EX_A * ID_EX_B ;
                AND  : EX_MEM_ALUOUT<= ID_EX_A & ID_EX_B ;
                OR   : EX_MEM_ALUOUT<= ID_EX_A | ID_EX_B ;
                SLT  : EX_MEM_ALUOUT<= ID_EX_A < ID_EX_B ;
                default : EX_MEM_ALUOUT<= 32'hxxxxxxxx ;
              endcase
             end
            RI_ALU : begin
              case(ID_EX_IR[31:26])
                ADDI : EX_MEM_ALUOUT<= ID_EX_A + ID_EX_IMM  ;
                SUBI : EX_MEM_ALUOUT<= ID_EX_A - ID_EX_IMM ;
                SLTI : EX_MEM_ALUOUT<= ID_EX_A < ID_EX_IMM ;
                default : EX_MEM_ALUOUT<= 32'hxxxxxxxx ;
              endcase              
            end
            LOAD,STORE : begin
              case(ID_EX_IR[31:26])                
                LW : EX_MEM_ALUOUT<= ID_EX_A + ID_EX_IMM  ;
                SW : begin
                  EX_MEM_ALUOUT<= ID_EX_A + ID_EX_IMM  ;
                  EX_MEM_B<= ID_EX_B  ;
                end
              
              endcase
             // EX_MEM_ALUOUT<=ID_EX_A+ID_EX_IMM;
             // EX_MEM_B<=ID_EX_B;
            end
            BRANCH : begin
              EX_MEM_ALUOUT<= ID_EX_NPC + ID_EX_IMM ;
              EX_MEM_COND <= (ID_EX_A == 5'b00000) ;             
            end          
          endcase          
        end
    end
  ///STAGEIII - MEM
  
  always@(posedge clk2)
    begin
      if(HALTED==0)
        begin
          MEM_WB_IR <= EX_MEM_IR ;          
          MEM_WB_TYPE <= EX_MEM_TYPE ;
          case(EX_MEM_TYPE)
            RR_ALU,RI_ALU : MEM_WB_ALUOUT <= EX_MEM_ALUOUT ;
            LOAD         : MEM_WB_LMD <= inst_mem[EX_MEM_ALUOUT];
            STORE        : begin 
              if(TAKEN_BRANCH==0)
                inst_mem[EX_MEM_ALUOUT] <= EX_MEM_B ;              
            end            
          endcase           
        end
    end
  always @(posedge clk1)
    begin
      if(TAKEN_BRANCH==0)
        begin
          case(MEM_WB_TYPE)
            RR_ALU : reg_bank[MEM_WB_IR[15:11]] <= MEM_WB_ALUOUT ;
            RI_ALU : reg_bank[MEM_WB_IR[20:16]] <= MEM_WB_ALUOUT ;
            LOAD   : reg_bank[MEM_WB_IR[20:16]] <= MEM_WB_LMD ;
            HALT   : HALTED <= 1 ; 
          endcase
        end      
    end  
endmodule