function [ P,W ] = gauspw( n )
% function to set up gauss integration point and its weight coefficient
% n --- number of gauss integration point
% P(n) --- coordinate of gauss integration point
% W(n) --- weight coefficient
switch n
    case 1
        P(1) = 0;
        W(1) = 2;
    case 2
        P(1) = -0.577350269189626;
        P(2) = 0.577350269189626;
        W(1) = 1.0;
        W(2) = 1.0;
    case 3
        P(1) = -0.774596669241483;
        P(2) = 0;
        P(3) = 0.774596669241483;
        %----------------------------
        W(1) = 0.555555555555556;
        W(2) = 0.888888888888889;
        W(3) = W(1);
end
end

