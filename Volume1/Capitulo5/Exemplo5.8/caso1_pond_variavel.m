% clear all, 
% close all, 
clc

run('../../../Bibliotecas/parametrosFiguras.m')
%%
s = tf('s');
Ts = 0.1; % perído de amostragem em minutos

G = 4/(1.25*s+1)^2; % modelo por função de transferência do processo

Gz = c2d(G,Ts,'zoh'); % modelo discretizado
num = Gz.num{1}; % numerador do modelo discreto
den = Gz.den{1}; % denominador do modelo discreto
na = size(den,2)-1; % ordem do denominador
nb = size(num,2)-2; % ordem do numerador
dd = Gz.inputdelay; % atraso discreto


%% parâmetros de ajuste

N1 = 1; %horizonte de predição inicial
N2 = 15; % horizonte de predição final
N = N2-N1+1; % horizonte de predição
Nu = 5; % horizonte de controle


pinf = 50; % ponderação abaixo do limite inferior
pint = 1; % ponderação entre os limites
psup = 50; % ponderação acima do limite superior
lambda = 5; % ponderação do esforço de controle



Nss=100; % horizonte de modelo
Gcoef = step(G,Ts:Ts:Nss*Ts); % coeficientes da resposta ao degrau

%% montando as matrizes do DMC

G = zeros(N2,Nu);
G(:,1) = Gcoef(1:N2,1);


for i=2:Nu
    G(i:end,i) = G(1:end-(i-1),1);    
end

G = G(N1:end,:);

Qu = lambda*eye(Nu);

Ylivre = ones(Nss,1)*0; %%% 0 é o valor inicial da saída do sistema

%% inicialização vetores
nin = Nss+1;
nit = round(25/Ts) + nin; % número de iterações da simulação

h0 = 8; % estado inicial da saída
u0 = 2; % estado inicial da entrada

entradas = u0*ones(nit,1); % vetor o sinal de controle
du = zeros(nit,1); % vetor de incrementos de controle

saidas = h0*ones(nit,1); % vetor com as saídas do sistema

perts = zeros(nit,1); % vetor com as perturbações do sistema
perts(nin+round(5/Ts):end) = 1;
perts(nin+round(15/Ts):end) = -2;

bandasup = 2*ones(nit,1);
bandasup(nin+round(12/Ts):end) = 1;
bandainf = -3*ones(nit,1);
bandainf(nin+round(12/Ts):end) = -1;

refs = 0*ones(nit,1); % vetor de referências


%% simulação sem filtro de referência
for k = nin:nit
    %% modelo processo, não mexer
    saidas(k) = -den(2:end)*saidas(k-1:-1:k-na) + num*(entradas(k-dd:-1:k-nb-dd-1) - perts(k-dd:-1:k-dd-nb-1));
    
   
    %% Controlador
    Ylivre = Ylivre + Gcoef(1:Nss,1)*du(k-1);
    
    eta = saidas(k)-Ylivre(1); %%% erro de predição
    
    Ylivre(1:end-1) = Ylivre(2:end); %%% deslocamento do vetor
    
    %%% resposta livre
    f = Ylivre(N1:N2,1)+eta;
    
    %%% referências
    R = ones(N,1)*refs(k);
    
    %%% ponderação variável de acordo com a resposta livre
    Qy = zeros(N);

    for j=1:N
        if(f(j)>=bandasup(k))
            Qy(j,j) = psup;
        elseif(f(j)<=bandainf(k))
            Qy(j,j) = pinf;
        else
            Qy(j,j) = pint;
        end
    end
    
    %%% calculo do incremento de controle ótimo  
    X = inv(G'*Qy*G+Qu)*G'*Qy*(R-f);
    du(k) = X(1); 
    
    %%% calculo da ação de controle real
    entradas(k) = entradas(k-1) + du(k);
    
    
end

%% plots
t = ((nin-10:nit)-nin+10)*Ts;
vx = nin-10:nit;


cores = gray(3);
cores = cores(1:end-1,:);


hf = figure
h=subplot(2,1,1)
plot(t,52+saidas(vx),'LineWidth',tamlinha,'Color',cores(1,:))
hold on
plot(t,52+refs(vx),':','Color',cores(1,:),'LineWidth',tamlinha,'Color',cores(2,:))

plot(t,bandasup(vx)+52,'--','LineWidth',tamlinha,'Color',cores(2,:))
plot(t,bandainf(vx)+52,'--','LineWidth',tamlinha,'Color',cores(2,:))



ylabel('Nível (%)', 'FontSize', tamletra);
xlim([0 26]);
ylim([48 61])
hl = legend('Caso 1','Referência','Limites')

grid on


set(h, 'FontSize', tamletra);

h=subplot(2,1,2)
plot(t,30+entradas(vx),'LineWidth',tamlinha,'Color',cores(1,:))
ylabel('Manipulada (%)', 'FontSize', tamletra);
xlabel('Tempo (minutos)', 'FontSize', tamletra);
xlim([0 25]);
ylim([14 34])
set(h, 'FontSize', tamletra);

grid on

hf.Position = tamfigura;
hl.Position = [0.7077 0.5411 0.2054 0.1242];




