// =========================
// Módulo: contador_4bits
// =========================
module contador_4bits (
    input clk,
    input reset,
    input En,
    input Ld,
    input d3, d2, d1, d0,
    output reg [3:0] estado
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            estado <= 4'b0000; // reset assíncrono
        end else begin
            if (En) begin
                if (Ld) begin
                    estado <= {d3, d2, d1, d0};  // Operação Load
                end else begin
                    estado <= estado + 1;   // Operação Increment
                end
            end
        // else: hold (estado mantém seu valor)
        end
    end
endmodule

// =========================
// Módulo: proximo_estado
// =========================
module proximo_estado (
    input wire Q3, Q2, Q1, Q0, // estado atual
    input wire p,              // botão pressionado
    input wire c,              // dígito correto
    input wire l,              // reset FSM
    output reg En,             // enable do contador
    output reg Ld,             // load do contador
    output reg d               // bit para load
);
    
    // Definição dos estados
    parameter IDLE = 4'b0000;
    parameter d1 = 4'b0001;
    parameter d1a = 4'b0010;
    parameter d2 = 4'b0011;
    parameter d2a = 4'b0100;
    parameter d3 = 4'b0101;
    parameter d3a = 4'b0110;
    parameter d4 = 4'b0111;
    parameter E = 4'b1111;
    parameter U = 4'b1000;
    
    wire [3:0] estado_atual = {Q3, Q2, Q1, Q0};

    always @(*) begin
        // valores padrão
        En = 0;
        Ld = 1;
        d = 0;

        if (l) begin
            // Reset ativo
            En = 1;
            Ld = 1;
            d = 0; // Load 0000 (IDLE)
        end else begin
            case (estado_atual)
                IDLE: begin // IDLE
                    if (p && c) begin // INC
                        En = 1;
                        Ld = 0; // INC
                    end else if (p && !c) begin  
                        En = 1;
                        Ld = 1;
                        d = 1; // Load 1111 (Erro)
                    end else begin 
                        En = 0; // Hold
                    end
                end
                d1, d2, d3, d4: begin
                    if (!p) begin
                        En = 1;
                        Ld = 0; // INC
                    end else begin
                        En = 0; // Hold
                    end
                end
                d1a, d2a, d3a: begin
                    if (p && c) begin 
                        En = 1;
                        Ld = 0; // INC
                    end else if (p && !c) begin
                        En = 1;
                        Ld = 1;
                        d = 1;  // Load 1111
                    end else begin
                        En = 0;  // Hold
                    end
                end
                E, U: begin
                    En = 0; // Hold
                end
                default: begin
                    // Estados não mapeados: Load 0000 (IDLE)
                    En = 1;
                    Ld = 1;
                    d = 0;
                end
            endcase
        end
    end
endmodule

// =========================
// Módulo: saida_sistema
// =========================
module saida_sistema (
    input wire Q3, Q2, Q1, Q0,
    output wire u,        // Unlock
    output wire s1, s0    // Bits para validação da senha correta
);

    wire [3:0] Q = {Q3, Q2, Q1, Q0};

    // Desbloqueio se estado final for 1000 (estado U)
    assign u = (Q == 4'b1000);
    // Estado da senha
    assign s1 = Q2;
    assign s0 = Q1;
endmodule

// =========================
// Módulo: sistema_fechadura
// =========================
module sistema_fechadura (
    input wire clk,
    input wire reset,     // reset contador
    input wire l,         // reset da FSM
    input wire p,         // botão pressionado
    input wire c,         // dígito correto
    output wire u,        // saída de desbloqueio
    output wire [1:0] s   // saída auxiliar
);
    // Sinais de conexão entre os módulos
    wire En, Ld, d;
    wire s1, s0;
    wire [3:0] estado_atual;
    assign s = {s1, s0};

    // Instancia a função proximo_estado
    proximo_estado pe (
        .Q3(estado_atual[3]), .Q2(estado_atual[2]), .Q1(estado_atual[1]), .Q0(estado_atual[0]),
        .p(p), .c(c), .l(l),
        .En(En), .Ld(Ld), .d(d)
    );
    
    // Instancia o contador de 4 bits
    contador_4bits contador (
        .clk(clk), .reset(reset),
        .En(En), .Ld(Ld),
        .d0(d), .d1(d), .d2(d), .d3(d),  // d = 0 para IDLE (0000), d = 1 para E (1111)
        .estado(estado_atual)
    );
    
    // Instancia a saída do sistema
    saida_sistema saida (
        .Q3(estado_atual[3]), .Q2(estado_atual[2]), .Q1(estado_atual[1]), .Q0(estado_atual[0]),
        .u(u), .s1(s1), .s0(s0)
    );
endmodule

// =========================
// Testbench: tb_sistema_fechadura
// =========================
`timescale 1ns / 1ps
module tb_sistema_fechadura;

    reg clk;
    reg reset;   // reset assincrono
    reg p;       // botão pressionado
    reg c;       // dígito correto
    reg l;       // reset FSM
    wire u;
    wire [1:0] s;

    // Instancia o sistema
    sistema_fechadura uut (
        .clk(clk), .reset(reset),
        .p(p), .c(c), .l(l),
        .u(u), .s(s)
    );

    // Clock 10ns
    initial clk = 0;
    always #10 clk = ~clk;

    // Task para simular o pressionar do botão
    task pressionar_botao;
        input correto;
        begin
            p = 1;
            c = correto;
            @(posedge clk);
            p = 0;
            c = 0;
            @(posedge clk);
        end
    endtask

    task verificar_fechadura;
        begin
            if(u)
                $display("STATUS : ABERTA\n");
            else
                $display("STATUS : FECHADA\n");
        end
    endtask

    initial begin
        // Inicialização
        l = 1; p = 0; c = 0; #20;
        l = 0; #20;
        
        $display("=== Inserindo senha ERRADA 4 9 5 1 ===\n");
        // Etapa 1: 4 correto
        pressionar_botao(1); #20;
        // Etapa 2: 9 correto
        pressionar_botao(1); #20;
        // Etapa 3: 5 correto
        pressionar_botao(1); #20;
        // Etapa 4: 1 incorreto
        pressionar_botao(0); #20;
        
        verificar_fechadura(); #20;
        
        $display("=== Resetando sistema ===\n");
        l = 1; #20;
        l = 0; #20;
                
        $display("=== Inserindo senha CORRETA 4 9 5 2 ===\n");
        // Etapa 1: 4 correto
        pressionar_botao(1); #20;
        // Etapa 2: 9 correto
        pressionar_botao(1); #20;
        // Etapa 3: 5 correto
        pressionar_botao(1); #20;
        // Etapa 4: 2 correto
        pressionar_botao(1); #20;
        
        verificar_fechadura(); #20;
        
        $stop;
    end
endmodule
