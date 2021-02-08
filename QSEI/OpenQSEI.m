%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                  OpenQSEI Main Script                 %%%%
%%%% This is an executable example of a compliant material %%%%
%%%% with a unicorn inclusion                              %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Danny Smyl
%%% Date: 10.2.2018
%%% Location: Aalto University, Espoo, Finland
%%% Corresponding Email: danny.smyl@aalto.fi
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all, close all, clc

%%% add path to your directory of choice %%%
addpath (genpath ('C:\Users\Omistaja\Documents\MATLAB\Sven\DIC\openQSEI-master'))

%%% triangular mesh generation: rectangular geometires %%%
Lx=10;
Ly=10;
elwidth=Ly/20;

[g,x,y,Ex,Ey,Tri,constraint,nel,nelx,nely] = meshgen(Lx,Ly,elwidth);
ginv = [Ex,Ey];

%%% homgeneous Poisson ratio %%%
nu = 0.35;
%%% homogeneous plate thickness %%%
th = 0.05;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Constraint selection %%%
%%% '1' is on '0' is off %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% '1' is on '0' is off %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SET_MIN_D =1;
SET_MAX_D =1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Selection of prior type  %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%TV prior%%%
SET_TV_ON = 1;%%%% Health Warning: TV is not appropriate for highly inhomgeneous background %%%%

%%%Weighted smoothness prior%%%
FIRST_ORDER = 0;

%%%Tikhonov uninformative prior%%%%
L_ON = 0;

%%% Tikhonov regularization parameter %%%
lambda = 10^-5;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%Adhoc Noise Weighting%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
adhoc_weighting = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%Jacobian Central Differencing%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CD_Level_2 = 0; %%%Level_2 set to "1" is a higher order J approx (expensive) %%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Rectangular (1) or randomized (0) target distribution of E %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Rectangular_Inclusion = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Load Boundary info %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% User-defined nodal force vector%%%
load force
%%% Cond is the assignment of user-defined boundary conditions%%%
load cond

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%% Designing a rectangular inclusion %%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if Rectangular_Inclusion
    Emax = 300;
    Emin = 1;
    E=Emax*ones(nel,1);
    idx1 = find(Ex >= 2.25 & Ex <= 4.75 & Ey >= 2.25 & Ey <= 4.75);
    E(idx1) = Emin;
    Esim = E;
else
    %%% Load Inclusion data %%%
    load Eunicorn
    Eunicorn = abs(Eunicorn);
    Emax = 250;
    Emin = 100;
    Evar = Emax-Emin;
    E = Emin + Evar*Eunicorn/max(Eunicorn);
    Esim =  E;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Sim data and get grid %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[u,ux,uy,K,Ael,sNinv] = SimulateData(E,nu,th,constraint,cond,force,x,y,Tri);
%%

    ux = reshape(ux,nelx+1,nely+1);
    uy = reshape(uy,nelx+1,nely+1);
    
    DIC_pattern = double(rgb2gray(imread('image29','png'))) ;
        
    Xlim = [0 Lx]; Ylim = [0 Ly];
    
    ScalingFactor = 1; 
    tic
    DIC_pattern_warped = DIC_pattern_forward_warping(DIC_pattern, Xlim, Ylim, ux, uy, ScalingFactor);
    toc
 
    
    
    
%%
um=u;

%%%%%%%%%%%%%%%%%%%%%%%%
%%%% True data plot %%%%
%%%%%%%%%%%%%%%%%%%%%%%%
IO = isInterior(Tri);

figure(1)
F=scatteredInterpolant(Ex,Ey,E);
int=F(g(:,1),g(:,2));
trisurf(Tri(IO,:),Tri.Points(:,1), Tri.Points(:,2),int),view(2),colormap('jet'),set(0,'defaulttextInterpreter','latex'),daspect([1 1 1]),shading interp, colorbar('eastoutside');caxis([min(E) max(E)]),axis tight,title('$E$','FontSize',14), axis off, box on;

%%%%%%%%%%%%%%%%%%%
%%% Noise model %%%
%%%%%%%%%%%%%%%%%%%
if adhoc_weighting
    WeightingMultiplier = 2;
    meas_noise_coef = WeightingMultiplier*1e-3;
    meas_noise_coef2 = WeightingMultiplier*1e-2;
    
    beta_u_QSEI = (meas_noise_coef*(max(max(u))-min(min(u))))^2;
    var_u_QSEI = beta_u_QSEI + (meas_noise_coef2*abs(u)).^2;
    
    dGamma_n_QSEI = var_u_QSEI(:);
    Gamma_n_QSEI = 2*diag(dGamma_n_QSEI(:));
    InvGamma_n_QSEI = sparse(inv(Gamma_n_QSEI));
    Ln_QSEI = chol(InvGamma_n_QSEI);
    W_QSEI = Ln_QSEI'*Ln_QSEI;
else
    meas_noise_coef = 1e-3;
    meas_noise_coef2 = 1e-2;
    
    beta_u_QSEI = (meas_noise_coef*(max(max(u))-min(min(u))))^2;
    var_u_QSEI = beta_u_QSEI + (meas_noise_coef2*abs(u)).^2;
    
    dGamma_n_QSEI = var_u_QSEI(:);
    Gamma_n_QSEI = 2*diag(dGamma_n_QSEI(:));
    InvGamma_n_QSEI = sparse(inv(Gamma_n_QSEI));
    Ln_QSEI = chol(InvGamma_n_QSEI);
    W_QSEI=Ln_QSEI'*Ln_QSEI;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% ADD NOISE TO SIMULATED DISPLACEMENTS%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
um = u + meas_noise_coef*abs(u).*randn(size(u));
um = um + (meas_noise_coef*(max(um)-min(um)))*randn(size(um));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% EXPECTED (HOMOGENEOUS) ESTIMATE %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Make sure these coeficients are consistent with the simulated or
%%% experimantal data
Ehomguess = 5*ones(nel,1);
Estep = 0.25*Ehomguess;
[thetaexp] = BestHomogeneousE(Ehomguess,nu,th,x,y,Tri,um,Estep,constraint,Tri,g,cond,force);
drawnow

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% TV Prior initiliazation %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[R,Ai] = getTVMat([Ex Ey],delaunay(Ex,Ey),nel);
%%%%%%%% select TV alpha parameter %%%%%%%%%%
max_difference = 2*thetaexp(1);
element_width = elwidth;
max_difference = max_difference/element_width;
p = 50; %%% User-defined confidence (%) %%%
alphaS = 1;
alpha = -log(1-p/100)/max_difference;
alpha = alphaS*alpha;
beta = (1e-3)*max_difference^2;%%% beta may also be simply assigned a value %%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% Weighted smoothness prior %%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
coef = 4;
maxc = coef*thetaexp(1);%%% Define max value of smoothness distribution
minc =  50;%%% Define min value of smoothness distribution
range = [minc maxc];
var = (diff(range)/6)^2;
corr_x = 1.0;%%% "corr" refers to the spatial correlation between distant points
corr_y = corr_x;%%% Isotropic
smooth_pr = WeightedSmoothnessPrior(ginv,var,corr_y);
iGamma = inv(smooth_pr);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% Inversion %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
theta = thetaexp;%%% Inital guess for the parameterizatization.Often thetaexp is used (theta=thetaexp is used for TV).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialize inversion parameters %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
max_iter_GN = 2;
max_iter_linesearch = 50;
FIRSTSTEP = 0.01;
DRAW = 1;
minval = 1e-1;%%% Minimum allowable E for projection and barrier constraint %%%%
tmax = Emax;%%% Maximum allowable E for projection and barrier constraint %%%%
ii=1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Cost Function Params %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Ffunc = 'costfun';
a=0;
aS2_1 =0;
bS2_1 =0;
cS2_1 =0;
a2=0;
b2=0;
c2=0;
ii=1;
cost_params_QSEI.SET_TV_ON = SET_TV_ON;
cost_params_QSEI.Tri = Tri;
cost_params_QSEI.R = R;
cost_params_QSEI.Ai = Ai;
cost_params_QSEI.beta = beta;
cost_params_QSEI.alpha = alpha;
cost_params_QSEI.thetaexp = thetaexp;
cost_params_QSEI.SET_MAX_D = SET_MAX_D;
cost_params_QSEI.SET_MIN_D = SET_MIN_D;
cost_params_QSEI.minval = minval;

cost_params_QSEI.ii=ii;
cost_params_QSEI.g=g;
cost_params_QSEI.alpha=alpha;
cost_params_QSEI.E=E;
cost_params_QSEI.tmax=tmax;
cost_params_QSEI.Esim=Esim;
cost_params_QSEI.theta=theta;
cost_params_QSEI.um=um;
cost_params_QSEI.nu=nu;
cost_params_QSEI.th=th;
cost_params_QSEI.sNinv=sNinv;
cost_params_QSEI.a=a;
cost_params_QSEI.a2=a2;
cost_params_QSEI.b2=b2;
cost_params_QSEI.c2=c2;
cost_params_QSEI.aS2_1 = aS2_1;
cost_params_QSEI.bS2_1 = bS2_1;
cost_params_QSEI.cS2_1 = cS2_1;
cost_params_QSEI.iGamma=iGamma;
cost_params_QSEI.FIRST_ORDER = FIRST_ORDER;
cost_params_QSEI.L_ON = L_ON;
cost_params_QSEI.constraint = constraint;
cost_params_QSEI.cond = cond;
cost_params_QSEI.force = force;
cost_params_QSEI.lambda = lambda;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Initialize Cost Function %%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[Fnorm(1),usim] = costfun(theta(:,end),cost_params_QSEI);
F00 = Fnorm(1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Getting Gradients and Hessians %%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[grad_TV,Hess_TV,gradq,Hessq,gradq2,Hessq2,g_smooth,Hess_smooth,cost_params_QSEI] = gradshessians(theta,cost_params_QSEI,Fnorm);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Begin GN iterations %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure(100); set(gcf,'units','normalized','outerposition',[0 0 1 1])

for ii = 2:max_iter_GN
    
    if ii > 2
        %%% plotting data mismatch %%%
        figure(100), subplot(4,3,[3 6])
        plot(um)
        hold on
        plot(usim);
        hold off
        title('Displacement field mismatch'),set(0,'defaulttextInterpreter','latex')
        
        figure(100), subplot(4,3,[9 12])
        plot(E)
        hold on
        plot(theta(:,ii-1))
        hold off
        legend('show')
        legend('True','Simulated')
        title('Elasticity modulus mismatch'),set(0,'defaulttextInterpreter','latex')
        drawnow
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Estimate J using central differencing %%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    J=PertubedJ(nel,K,theta(:,ii-1),nu,th,x,y,Tri,constraint,Tri,g,cond,force,CD_Level_2);
    
    if SET_TV_ON
        %%%% TV %%%%
        zz =  J'*W_QSEI*[um - usim] - alpha*grad_TV - gradq - gradq2;
        HH = J'*W_QSEI*J + alpha*Hess_TV + Hessq + Hessq2;
        dtheta=HH\zz;
    elseif FIRST_ORDER
        %%%% Weighted Smoothness %%%%
        zz = J'*W_QSEI*[um - usim] -  gradq - gradq2 - g_smooth;
        HH = J'*W_QSEI*J +  Hessq + Hessq2 +  Hess_smooth;
        dtheta=HH\zz;
    else
        %%%% unconstrained Tikhonov regularized solution %%%%
        dtheta=inv(J'*J+lambda*eye(size(J'*J)))*(J'*[um - usim]);
    end
    
    %%% Linesearch to determine step size, sk %%%
    F0 = Fnorm(ii-1);
    sk=linesearch_uniform(theta(:,ii-1),dtheta,max_iter_linesearch,20,cost_params_QSEI);
    
    %%% new estimate
    theta(:,ii) = theta(:,ii-1) + sk*dtheta;
    
    %%% projecting to avoid complex values of E %%%
    neg = find(theta(:,ii)<minval);
    theta(neg,ii) = minval;
    
    %%% Update Cost Function Parameters %%%
    cost_params_QSEI.SET_TV_ON = SET_TV_ON;
    cost_params_QSEI.Tri = Tri;
    cost_params_QSEI.beta = beta;
    cost_params_QSEI.alpha = alpha;
    cost_params_QSEI.thetaexp = thetaexp;
    cost_params_QSEI.SET_MAX_D = SET_MAX_D;
    cost_params_QSEI.SET_MIN_D = SET_MIN_D;
    cost_params_QSEI.minval = minval;
    cost_params_QSEI.ii=ii;
    cost_params_QSEI.g=g;
    cost_params_QSEI.alpha=alpha;
    cost_params_QSEI.E=E;
    cost_params_QSEI.tmax=tmax;
    cost_params_QSEI.Esim=Esim;
    cost_params_QSEI.theta=theta;
    cost_params_QSEI.um=um;
    cost_params_QSEI.nu=nu;
    cost_params_QSEI.th=th;
    cost_params_QSEI.sNinv=sNinv;
    cost_params_QSEI.a=a;
    cost_params_QSEI.a2=a2;
    cost_params_QSEI.b2=b2;
    cost_params_QSEI.c2=c2;
    cost_params_QSEI.aS2_1 = aS2_1;
    cost_params_QSEI.bS2_1 = bS2_1;
    cost_params_QSEI.cS2_1 = cS2_1;
    cost_params_QSEI.iGamma=iGamma;
    cost_params_QSEI.FIRST_ORDER = FIRST_ORDER;
    cost_params_QSEI.L_ON = L_ON;
    cost_params_QSEI.constraint = constraint;
    cost_params_QSEI.cond = cond;
    cost_params_QSEI.force = force;
    cost_params_QSEI.R = R;
    cost_params_QSEI.Ai = Ai;
    
    [Fnorm(ii)] = costfun(theta(:,end),cost_params_QSEI);
    
    %%%% Get updated hessians and gradients %%%
    [grad_TV,Hess_TV,gradq,Hessq,gradq2,Hessq2,g_smooth,Hess_smooth,cost_params_QSEI] = gradshessians(theta(:,ii),cost_params_QSEI,Fnorm);
    
    cmin1 = min(min(min(E)));
    cmin2 = min(theta(:,ii));
    cmin = min(cmin1,cmin2);
    
    cmax1 = max(max(max(E)));
    cmax2 = max(theta(:,ii));
    cmax = max(cmax1,cmax2);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Plot True/inv images %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    figure(100), subplot(4,3,[1 4])
    F=scatteredInterpolant(Ex,Ey,E);
    int=F(g(:,1),g(:,2));
    trisurf(Tri(IO,:),Tri.Points(:,1), Tri.Points(:,2),int),view(2),colormap('jet'),set(0,'defaulttextInterpreter','latex'),daspect([1 1 1]),shading interp, colorbar('eastoutside');caxis([cmin cmax]),axis tight,title('$E_{true}$','FontSize',14), axis off, box on;
    
    figure(100), subplot(4,3,[7 10])
    F=scatteredInterpolant(Ex,Ey,theta(:,ii));
    int=F(g(:,1),g(:,2));
    trisurf(Tri(IO,:),Tri.Points(:,1), Tri.Points(:,2),int),view(2),colormap('jet'),set(0,'defaulttextInterpreter','latex'),daspect([1 1 1]),shading interp, colorbar('eastoutside');caxis([cmin cmax]),axis tight,title('$E_{inverse}$','FontSize',14), axis off, box on;
    
    %%%% Simulate data for plotting and for the next iteration %%%
    [usim,K] = FMDL(theta(:,ii),nu,th,constraint,Tri,g,cond,force);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% collect x/y displacements at each iteration if desired %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [uxsim,uysim] = uxuy(usim);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Plot cost function %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    figure(100), subplot(4,3,[2 5])
    semilogy(Fnorm),title('Cost function'),set(0,'defaulttextInterpreter','latex'); grid on
    drawnow
    
    stopcriteria(ii) = norm((Fnorm(ii)-Fnorm(ii-1))/Fnorm(ii-1))
    
    if( norm((Fnorm(ii)-Fnorm(ii-1))/Fnorm(ii-1)) < 10^-6 )| Fnorm(ii) > Fnorm(ii-1)
        break;
    end
end
