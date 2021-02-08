function [u,ux,uy,K,Ael,sNinv] = SimData(E,nu,th,constraint,cond,force,x,y,Tri)
%%% Function to simulate data (inclusions)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 10.2.2018 Danny Smyl
%%% Aalto University, Espoo, Finland
%%% Email: danny.smyl@aalto.fi
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

elem = Tri.ConnectivityList;
nel=length(elem(:,1));
np=2*length(x);
Eloc = incenter(Tri);
Ex=Eloc(:,1);
Ey=Eloc(:,2);

m = [x(elem(:)),y(elem(:)),];
mu=unique(m,'rows');

%%% Plot Mesh %%%
% figure(10)
% triplot(elem,x,y),daspect([1 1 1])
% the=text(mu(:,1),mu(:,2),...
%     num2cell(1:size(mu,1)),...
%     'fontsize',12);

elem =[elem, ones(nel,1), ones(nel,1), zeros(nel,1)];
sNinv = length(Ex);

K=sparse(np,np);
F=zeros(np,1);

for i=1:nel
    nod1=elem(i,1);
    nod2=elem(i,2);
    nod3=elem(i,3);
    
    tm  =elem(i,4);
    tp  =elem(i,5);
    
    id=[2*nod1-1  2*nod1  2*nod2-1  2*nod2  2*nod3-1  2*nod3];
    
    E1=E(i)/(1-nu*nu);
    G=E(i)/2/(1+nu);
    C=[E1  nu*E1   0
        nu*E1     E1   0
        0      0    G ];
    
    y32=y(nod3)-y(nod2);
    y13=y(nod1)-y(nod3);
    y21=y(nod2)-y(nod1);
    
    x23=x(nod2)-x(nod3);
    x31=x(nod3)-x(nod1);
    x12=x(nod1)-x(nod2);
    
    Ael=abs((x12*y13-x31*y21))/2;
    
    B=[ y32     0   y13     0   y21     0
        0   x23     0   x31     0   x12
        x23   y32   x31   y13   x12   y21 ]/2/Ael;
    
    DB=C*B;
    kelem=Ael*th*B'*DB;
    
    
    K(id,id)=K(id,id)+kelem;
end

for i=1:length(force(:,1))
    z1 =force(i,1);
    dir=force(i,2);
    f =force(i,3);
    l =2*(z1-1)+dir;
    F(l)=F(l)+f;
end

q=max(diag(K))*constraint;

for i=1:length(cond(:,1))
    z2 = cond(i,1);
    dir = cond(i,2);
    l=2*(z2-1) + dir;
    K(l,l)=q;
end

u=K\F;

%% odd are x displacements
countx=0;
county=0;
for gg = 1:length(u)
    if mod(gg,2)==1
        countx = countx +1;
        ux(countx)=u(gg);
    else
        county = county +1;
        uy(county)=u(gg);
    end
end


