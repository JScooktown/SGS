
%% SECTION: COMPUTATIONAL SAVING

clear all;

% General setting
parm.k.covar(1).model = 'spherical';
parm.k.covar(1).azimuth = 0;
parm.k.covar(1).c0 = 1;
parm.k.covar(1).alpha = 1;
parm.seed_path = 'default';
parm.seed_search = 'shuffle';
parm.seed_U = 'default';

parm.k.covar(1).range0 = [15 15];
parm.k.wradius = 1;
parm.n_real = 1;
parm.saveit = 0;

parm.mg = 1;

N=2.^[8 10 12]+1;%[255 511 1023 2047 4095 8191];
K=[20 52 108];

T_trad_g=nan(numel(N),numel(K));
T_cst_par_g=nan(numel(N),numel(K));
T_cst_par_real=nan(numel(N),numel(K));
T_trad_real =nan(numel(N),numel(K));

for i_n=1:numel(N)
    for i_k=1:numel(K)
        nx = N(i_n); % no multigrid
        ny = N(i_n);
        parm.k.nb = K(i_k);
        
        [~,t] = SGS_cst_par(nx,ny,parm);
        title = ['T_cst_par_' num2str(N(i_n)) 'N_' num2str(K(i_k)) 'K' ];
        %save(['./cst_path_paper/' title ],'parm','t')
        T_cst_par_g(i_n,i_k) = t.global;
        T_cst_par_real(i_n,i_k) = t.real;
        
        [~,t] = SGS_trad(nx,ny,parm);
        title = ['T_trad_' num2str(N(i_n)) 'N_' num2str(K(i_k)) 'K' ];
        %save(['./cst_path_paper/' title ],'parm','t')
        T_trad_g(i_n,i_k) = t.global;
    end
end


% Load
for i_k=1:numel(K)
    load(['Y:/SGS/cst_path_paper/T_cst_par_' num2str(N(1)) 'N_' num2str(K(i_k)) 'K' ])
    T_cst_par_g(1,i_k) = mean(tt.global);
    T_cst_par_real(1,i_k) = mean(tt.real);
    
    load(['./cst_path_paper/T_trad_' num2str(N(1)) 'N_' num2str(K(i_k)) 'K' ])
    T_trad_g(1,i_k) = mean(tt.global);

end
for i_n=1:numel(N)
    for i_k=1:numel(K)
        load(['./cst_path_paper/T_cst_par_' num2str(N(i_n)) 'N_' num2str(K(i_k)) 'K' ])
        T_cst_par_g(i_n,i_k) = t.global;
        T_cst_par_real(i_n,i_k) = t.real;
        
        load(['./cst_path_paper/T_trad_' num2str(N(i_n)) 'N_' num2str(K(i_k)) 'K' ])
        T_trad_g(i_n,i_k) = t.global;
        T_trad_real(i_n,i_k) = t.real;
    end
end
save(['./cst_path_paper/T_N_K_all'],'parm','T_cst_par_g','T_cst_par_real','T_trad_g','T_trad_real','N','K')

figure(2); clf
m=0:100;
for i_n=1:numel(N)
    subplot(1,numel(N),i_n); hold on
    plot([0 100],[0 100],'--k')
    for i_k=1:numel(K)
        eta = ( T_trad_g(i_n,i_k) + (m-1).*T_trad_real(i_n,i_k)) ./ ( T_cst_par_g(i_n,i_k) + (m-1).*T_cst_par_real(i_n,i_k));
        h(i_k)=plot(m,eta);
    end
    legend(h,{'20 Neighbors','52 Neighbors','108 Neighbors'}); 
    axis equal tight
    xlabel('Number of realizations')
    ylabel('Speed-up')
end


figure(2); clf
m=1:10;
color = get(gca,'colororder');
for i_n=1:numel(N)
    subplot(1,numel(N),i_n); hold on
    for i_k=1:numel(K)
        h(i_k)=plot(T_cst_par_g(i_n,i_k)/60/60 + (m-1).*T_cst_par_real(i_n,i_k)/60/60,'Color',color(i_k,:));
        plot(T_trad_g(i_n,i_k)*m/60/60,'--','Color',color(i_k,:));
    end
    legend(h,{'20 Neighbors','52 Neighbors','108 Neighbors'}); axis tight
    xlabel('Number of realizations')
    ylabel('Time of Computations [hrs]')
end












%% SECTION: ERRORS OF SIMULATIONS
clear all;

% General setting
parm.k.covar.model = 'exponential';
parm.k.covar.azimuth = 0;
parm.k.covar.c0 = 1;
parm.k.covar.alpha = 1;
parm.seed_path = Inf;
parm.seed_search = 'shuffle';


parm.k.covar.range0 = [15 15];
parm.k.wradius = 1;
parm.mg = 1;
nx = 2^6+1; % no multigrid
ny = 2^6+1;
parm.k.nb = 20;


vario = {'exponential', 'gaussian', 'spherical', 'hyperbolic','k-bessel', 'cardinal sine'};

% True
[Y, X]=ndgrid(1:nx,1:ny);
XY = [Y(:) X(:)];
for v=1:numel(vario)
    covar=parm.k.covar;
    covar(1).model = vario{v};
    covar = kriginginitiaite(covar);
    DIST = squareform(pdist(XY*covar.cx));
    CY_true{v} = kron(covar.g(DIST), covar.c0);
end
err_frob_fx = @(CY,v) sqrt(sum((CY(:)-CY_true{v}(:)).^2)) / sum((CY_true{v}(:).^2));


% Run the program
CY = SGS_varcovar(nx,ny,parm);

% Simulation
N = 10;
tic
parpool(6)
vario_g=cell(numel(vario),1);
D = pdist2(XY,XY);
h = unique(D);
h = h(h<=parm.k.covar.range0(1)*1.5);


parfor v=1:numel(vario)
    parm1=parm;
    parm1.gen.covar.model = vario{v};
    CY=repmat({nan(ny*nx,nx*ny,2)},N,1);
    eta{v}=cell(N,1);
    nn=cell(N,1);
    for n=1:(2^(N-1))
        vec = de2bi(n-1,N);
        CY{1}(:,:,vec(1)+1) = full(SGS_varcovar(nx,ny,parm1));
        eta{v}{1} = [eta{v}{1}; err_frob_fx(CY{1}(:,:,vec(1)+1),v)];
        nn{1} = [nn{1}; 2^(1-1)];
        i=1;
        while (vec(i)==1)
            CY{i+1}(:,:,vec(i+1)+1) = mean(CY{i},3);
            eta{v}{i+1} = [eta{v}{i+1}; err_frob_fx(CY{i+1}(:,:,vec(i+1)+1),v)];
            nn{i+1} = [nn{i+1}; 2^(i)];
            i=i+1;
        end
        disp(['N: ' num2str(n) ])
    end
    
    vario_g{v} = nan(N,numel(h));
    for n=1:N
        for i=1:numel(h)
            id = D ==h(i);
            id2 = CY{n}(id);
            vario_g{v}(n,i) = sum(id2)/sum(id(:));
        end
    end
    %save(['frobenium_',vario{v},'_20_512_MG'])
end
toc

save(['./cst_path_paper/frobenium_65n_20k_512N_1MG'],'eta','vario','vario_g','n','parm','nx','ny');

boxplot(cell2mat(eta{v}),cell2mat(nn),'Orientation','horizontal');





%figure
% Multiple Vario - Boxplot
figure(3);clf; hold on;
lim=8;
load('Y:/SGS/cst_path_paper/frobenium_65n_20k_512N_1MG');
for v=1:numel(vario)
    subplot(numel(vario)/2,2,v); hold on;
    boxplot(cell2mat(eta{v}(1:lim)),cell2mat(nn(1:lim)),'Orientation','horizontal','Color',[0 113 188]/255);
    axis tight;
    xlabel(['Number of Path\newline' vario{v} ' variogram']);
    ylabel(['Standardized Frobenius Norm Error'])
end


figure(2);clf;hold on;
lim=8;
for v=1:numel(vario)
    for i=1:numel(nn)-1
        stat_eta{v}(i,:) = [mean(eta{v}{i}) std(eta{v}{i})];
        xx(i) = nn{i}(1);
        [f(i,:),xi(i,:)] = ksdensity(eta{v}{i});
        yi(i,:) = xx(i)*ones(1,numel(f(i,:)));
        ksdensity(eta{v}{i})
    end 
    %F=scatteredInterpolant(xi(:),yi(:),f(:))
    
    [X,Y]=meshgrid(linspace(min(min(xi)),max(max(xi)),100), linspace(min(min(yi)),max(max(yi)),256));
    
    a = F(X,Y);
    imagesc(X(1,:),Y(:,1),ones(256,100),'alphadata',a./max(max(a)))
   
%     plot(stat_eta{v}(:,1),xx)
%     plot(stat_eta{v}(:,1) - stat_eta{v}(:,2),xx,'--')
%     plot(stat_eta{v}(:,1) + stat_eta{v}(:,2),xx,'--')
end
ylabel('Number of Path');
xlabel('Standardized Frobenius Norm Error')
axis tight;


% Multiple Vario -- Neigh Size
figure(1); clf; hold on;
lim=8;
filename2={'frobenium_sph_8_512', 'frobenium_sph_20_512' ,'frobenium_sph_52_512'};
col={'b','r','g','y'};
for i=1:numel(filename2)
    s=load(['result-SGSIM/Constant Path/' filename2{i}]);
    xlim_b=get(gca,'xlim');
    boxplot(cell2mat(s.eta(1:lim)),cell2mat(nn(1:lim)),'Orientation','horizontal','color',col{i},'symbol',['+' col{i}]);
    xlim_a=get(gca,'xlim');
    if i>1
        xlim([ min(xlim_b(1), xlim_a(1)) max(xlim_b(2), xlim_a(2))])
    end
end
hLegend = legend(findall(gca,'Tag','Box'), {'Neighboors: 8', 'Neighboors: 20', 'Neighboors: 52'});
ylabel('Number of Path');
xlabel('Standardized Frobenius Norm Error')


% Multiple Vario -- Path
figure(5);clf;
lim=8;
filename2={'frobenium_65n_20k_512N_0MG' ,'frobenium_65n_20k_512N_1MG'};
col={'b','r','g','y'};
for v=1:numel(vario)
    subplot(numel(vario)/2,2,v); hold on;
    for i=1:numel(filename2)
        s=load(['Y:/SGS/cst_path_paper/' filename2{i}]);
        xlim_b=get(gca,'xlim');
        boxplot(cell2mat(s.eta{v}(1:lim)),cell2mat(nn(1:lim)),'Orientation','horizontal','color',col{i},'symbol',['+' col{i}]);
        xlim_a=get(gca,'xlim');
        if i>1
            xlim([ min(xlim_b(1), xlim_a(1)) max(xlim_b(2), xlim_a(2))])
        end
    end
    hLegend = legend(findall(gca,'Tag','Box'), {'Random Path', 'Mutli-grid Path'});
    ylabel('Number of Path');
    xlabel('Standardized Frobenius Norm Error')
end




%% MG CST Variable Level HYBRID

% General setting
parm.k.covar.model = 'gaussian';
parm.k.covar.azimuth = 0;
parm.k.covar.c0 = 1;
parm.k.covar.alpha = 1;
parm.seed_path = 4;
disp(num2str(parm.seed_path))
parm.seed_search = 'default';
parm.k.covar.range0 = [15 15];
parm.k.wradius = 1;
parm.mg = 1;
nx = 2^7+1; % no multigrid
ny = 2^7+1;
parm.k.nb = 20;

parm.seed_search = 5;

% True
[Y, X]=ndgrid(1:nx,1:ny);
XY = [Y(:) X(:)];
covar = kriginginitiaite(parm.k.covar);
DIST = squareform(pdist(XY*covar.cx));
CY_true = kron(covar.g(DIST), covar.c0);
err_frob_fx = @(CY) sqrt(sum((CY(:)-CY_true(:)).^2)) / sum((CY_true(:).^2));

N=2;
CY=repmat({nan(ny*nx,nx*ny,2)},N,1);
eta=cell(N,1);
nn=cell(N,1);
for n=1:(2^(N-1))
    vec = de2bi(n-1,N);
    CY{1}(:,:,vec(1)+1) = full(SGS_varcovar(nx,ny,parm));
    eta{1} = [eta{1}; err_frob_fx(CY{1}(:,:,vec(1)+1))];
    nn{1} = [nn{1}; 2^(1-1)];
    i=1;
    while (vec(i)==1)
        CY{i+1}(:,:,vec(i+1)+1) = mean(CY{i},3);
        eta{i+1} = [eta{i+1}; err_frob_fx(CY{i+1}(:,:,vec(i+1)+1))];
        nn{i+1} = [nn{i+1}; 2^(i)];
        i=i+1;
    end
    disp(['N: ' num2str(n) ])
end

sx = 1:ceil(log(nx+1)/log(2));   sy = 1:ceil(log(ny+1)/log(2));   sn = max([numel(sy), numel(sx)]);
nb = nan(sn,1);start = zeros(sn+1,1);   path = nan(nx*ny,1); Path = nan(ny,nx);
for i_scale = 1:sn
   dx(i_scale) = 2^(sn-sx(min(i_scale,end))); dy = 2^(sn-sy(min(i_scale,end)));
   [Y_s,X_s] = ndgrid(1:dy:ny,1:dx(i_scale):nx); % matrix coordinate
   id = find(isnan(Path(:)) & ismember(XY, [Y_s(:) X_s(:)], 'rows'));
   nb(i_scale) = numel(id); start(i_scale+1) = start(i_scale)+nb(i_scale);
   path( start(i_scale)+(1:nb(i_scale)) ) = id(randperm(nb(i_scale)));
   Path(path( start(i_scale)+(1:nb(i_scale)) )) = start(i_scale)+(1:nb(i_scale));
end

% save(['./cst_path_paper/frobenium_129n_20k_16N_MG_' num2str(parm.seed_path) 'CSTP'],'eta','nn','parm','nx','ny','nb');



% Figure
figure(10);clf; hold on; 
CST=1:9; cnb = cumsum(nb); ldgd=cell(numel(CST),1);
for i = 1:numel(CST)
    load(['Y:/SGS/cst_path_paper/frobenium_129n_20k_16N_MG_' num2str(CST(i)) 'CSTP'])
    %boxplot(cell2mat(eta),cell2mat(nn),'Orientation','horizontal','Color',[0 113 188]/255);
    M = cellfun(@median,eta);
    S = cellfun(@std,eta);
    n = flipud(cellfun(@numel,eta));
    errorbar(n,M,S)
    ldgd{i} = ['Level ' num2str(CST(i)-1) ' (' num2str(cnb(CST(i)-1)) ' nodes | ' num2str(cnb(CST(i)-1)./cnb(end)*100,'%4.2f') '% | \Deltax=' num2str(dx(CST(i)-1)) ')' ];
end
view(90,-90); box on
xlabel('Number of Path');
ylabel('Standardized Frobenius Norm Error')
title('Constant path from level x with Multi-grid');

legend(ldgd)


% General setting
parm.k.covar.model = 'spherical';
parm.k.covar.azimuth = 0;
parm.k.covar.c0 = 1;
parm.k.covar.alpha = 1;
parm.seed_search = 'shuffle';
parm.k.covar.range0 = [15 15];
parm.k.wradius = 3;
parm.mg = 1;
nx = 2^7+1; % no multigrid
ny = 2^7+1;
parm.k.nb = 20;

seed_path=1:9;

nt=2;
t_real=nan(nt,numel(seed_path));
t_global=nan(nt,numel(seed_path));
for j=1:numel(seed_path)
    parm.seed_path = seed_path(j);
    for i=1:nt
        profile on
        [~,t] = SGS_hybrid(ny,nx,parm);
        profile viewer
        t_global(i,j)=t.global-t.covtable;
        t_real(i,j)=t.real;
    end
end


clear eta;
m=1:10;
for i_m=m
    eta(i_m,:) = i_m.*mean(t_global) ./ ( mean(t_global) + (i_m-1).*mean(t_real));
end

figure(5); clf; hold on;
plot(eta)
plot([0 10], [0 10], '--k')
legend(ldgd); 
axis tight equal
xlabel('Number of realizations')
ylabel('Speed-up')












%% OLD FROBENIUM 

clear all;clc;
addpath(genpath('./.'))

% General setting
grid_gen.sx = 6; % (65 x 65)
grid_gen.sy = 6;
grid_gen.x = 0:2^grid_gen.sx;
grid_gen.y = 0:2^grid_gen.sy;
[grid_gen.X, grid_gen.Y] = meshgrid(grid_gen.x,grid_gen.y);
sigma.d=[];
sigma.x=[];
sigma.y=[];
sigma.n=0;
parm.k.covar(1).model = 'spherical';
parm.k.covar(1).range0 = [15 15];
parm.k.covar(1).azimuth = 0;
parm.k.covar(1).c0 = .98;
parm.k.covar(1).alpha = 1;
parm.k.covar(2).model = 'nugget';
parm.k.covar(2).range0 = [0 0];
parm.k.covar(2).azimuth = 0;
parm.k.covar(2).c0 = 0.02;
parm.saveit = false;
parm.nscore = 0;
parm.par = 0;
parm.n_realisation  = 1;
parm.cstk = true;
parm.seed = 'default';
parm.varcovar = 0;
parm.scale=[grid_gen.sx;grid_gen.sy]; % no multigrid
parm.k.wradius=Inf;


parm.path = 'linear';
parm.path_random = 1;

vario = {'exponential', 'gaussian', 'spherical', 'hyperbolic','k-bessel', 'cardinal sine'};
neigh = [20];%[8 20 52 108];
dist_lim=[.0004 .0005 .0005 .04 .004 .2];

% True
parfor v=1:numel(vario)
    parm1=parm;
    parm1.k.covar(1).model = vario{v};
    parm1 = kriginginitiaite(parm1);
    CY_true{v} = covardm_perso([grid_gen.X(:) grid_gen.Y(:)],[grid_gen.X(:) grid_gen.Y(:)],parm1.k.covar);
end
err_frob_fx = @(CY,v) sqrt(sum((CY(:)-CY_true{v}(:)).^2)) / sum((CY_true{v}(:).^2));

% Simulation
N=3;
nv=numel(vario);
nn =numel(neigh);
nxy =numel(grid_gen.X);
for v=1:nv
    dist{v}=linspace(-dist_lim(v),dist_lim(v),1000);
    parm1=parm;
    parm1.k.covar(1).model = vario{v};
    parm1 = kriginginitiaite(parm1);
    errhit{v} = nan(nn,N,numel(dist{v})-1);
    err{v} = nan(nn,N);
    errhit_ag{v} = nan(nn,numel(dist{v})-1);
    err_ag{v} = nan(nn);
    for n = 1:nn
        parm1.k.nb_neigh = [0 0 0 0 0; neigh(n) 0 0 0 0];
        CY=nan(nxy,nxy,N);
        for i=1:N
            Res = SGSIM(sigma,grid_gen,parm1);
            CY(:,:,i) = full(varcovar(Res));
            errhit{v}(n,i,:)=histcounts(reshape(CY(:,:,i),numel(CY_true{v}),1)-CY_true{v}(:),dist{v});
            err{v}(n,i) = err_frob_fx(CY(:,:,i),v);
        end
        CCY=mean(CY,3);
        errhit_ag{v}(n,:)=histcounts(CCY(:)-CY_true{v}(:),dist{v});
        err_ag{v}(n) = err_frob_fx(CCY,v);
    end
end

figure;
subplot(2,2,1);
imagesc(CY(:,:,1));colorbar;caxis([0 1]);set(gca,'xticklabel',[]);set(gca,'yticklabel',[])
xlabel('C_Z')
subplot(2,2,2);
imagesc(CY_true{v}); caxis([0 1]);colorbar;set(gca,'xticklabel',[]);set(gca,'yticklabel',[])
    xlabel('C_\gamma')
subplot(2,2,3);
imagesc(mean(CY,3)-CY_true{v});colorbar;set(gca,'xticklabel',[]);set(gca,'yticklabel',[])
xlabel('E[\varepsilon_Z]')
subplot(2,2,4);
imagesc(std(CY,[],3));colorbar;set(gca,'xticklabel',[]);set(gca,'yticklabel',[])
xlabel('Var[\varepsilon_Z]')


%figure
figure(1);clf; 
for v=1:nv
    subplot(3,2,v); hold on
    for n = 1:nn
        plot((dist{v}(2:end)+dist{v}(1:end-1))/2,reshape(errhit_ag{v}(n,:),1,numel(dist{v})-1),'r','linewidth',2)
        for i=1:N
            plot((dist{v}(2:end)+dist{v}(1:end-1))/2,reshape(errhit{v}(n,i,:),1,numel(dist{v})-1),'k')
        end
        legend('variable path with 20 random paths','unique random path')
    end
    set(gca, 'YScale', 'log');
    xlabel(['Error of Covariance\newline' vario{v}]);
    ylabel('Distribution')
end



figure(2); clf
for v=1:numel(vario)
    subplot(3,2,v); hold on;
    for n = 1:numel(neigh)
        histogram(err{v}(n,:),'FaceColor','k')
        plot(err_ag{v}(n),0,'or','MarkerFaceColor','r')
        legend('variable path with 20 random paths','unique random path')
    end
    xlabel(['Frobenium Norm Error\newline' vario{v}]);
    ylabel('Histogram')
end

figure(3);clf; hold on
boxplot(reshape([err{:}],N,nv),vario)
set(gca, 'YScale', 'log');
plot([err_ag{:}],'og')


%% OLD MG and Random Path: boxplot
parm.path = 'maximize';
parm.path_random = 1;
vario = {'exponential', 'gaussian', 'spherical', 'hyperbolic','k-bessel', 'cardinal sine'};
parm.k.nb_neigh = [0 0 0 0 0; 20 0 0 0 0];%[8 20 52 108];

% True
parfor v=1:numel(vario)
    parm1=parm;
    parm1.gen.covar(1).model = vario{v};
    parm1 = kriginginitiaite(parm1);
    CY_true{v} = covardm_perso([grid_gen.X(:) grid_gen.Y(:)],[grid_gen.X(:) grid_gen.Y(:)],parm1.k.covar);
end
err_frob_fx = @(CY,v) sqrt(sum((CY(:)-CY_true{v}(:)).^2)) / sum((CY_true{v}(:).^2));


% Simulation
tic
for v=1:numel(vario)
    parm1=parm;
    parm1.gen.covar(1).model = vario{v};
    N = 10;
    CY=repmat({nan(numel(grid_gen.X),numel(grid_gen.X),2)},N,1);
    eta{v}=cell(N,1);
    nn=cell(N,1);
    for n=1:(2^(N-1))
        vec = de2bi(n-1,N);
        Res = SGSIM(sigma,grid_gen,parm1);
        CY{1}(:,:,vec(1)+1) = full(varcovar(Res));
        eta{v}{1} = [eta{v}{1}; err_frob_fx(CY{1}(:,:,vec(1)+1),v)];
        nn{1} = [nn{1}; 2^(1-1)];
        i=1;
        while (vec(i)==1)
            CY{i+1}(:,:,vec(i+1)+1) = mean(CY{i},3);
            eta{v}{i+1} = [eta{v}{i+1}; err_frob_fx(CY{i+1}(:,:,vec(i+1)+1),v)];
            nn{i+1} = [nn{i+1}; 2^(i)];
            i=i+1;
        end
    end
    %save(['frobenium_',vario{v},'_20_512_MG'])
end
toc

save('frobenium_v20_512_MG','eta','vario','nn')

boxplot(cell2mat(eta),cell2mat(nn),'Orientation','horizontal');

%figure
clear eta
vario = {'exponential', 'gaussian', 'spherical', 'hyperbolic','k-bessel', 'cardinal sine'};
load('result-SGSIM/Constant Path/frobenium_v20_x512_MG');
etaMG=eta;
load('result-SGSIM/Constant Path/frobenium_v20_x512');

figure(2);clf; hold on;
lim=8;
for v=1:numel(vario)
    subplot(numel(vario)/2,2,v); hold on;
    boxplot(cell2mat(eta{v}(1:lim)),cell2mat(nn(1:lim)),'Orientation','horizontal','Color',[0 113 188]/255);
    xlim1=get(gca,'xlim');
    boxplot(cell2mat(etaMG{v}(1:lim)),cell2mat(nn(1:lim)),'Orientation','horizontal','Color',[216 82 24]/255);
    xlim2=get(gca,'xlim');
    xlim([ min(xlim1(1), xlim2(1)) max(xlim1(2), xlim2(2))])
    axis tight;
    legend('Random path','Multi-grid path')
    xlabel(['Number of Path\newline' vario{v} ' variogram']);
    ylabel(['Standardized Frobenius Norm Error'])
end


figure(2);clf;hold on;
lim=8;
for v=1:numel(vario)
    for i=1:numel(nn)-1
        stat_eta{v}(i,:) = [mean(eta{v}{i}) std(eta{v}{i})];
        xx(i) = nn{i}(1);
        [f(i,:),xi(i,:)] = ksdensity(eta{v}{i});
        yi(i,:) = xx(i)*ones(1,numel(f(i,:)));
        ksdensity(eta{v}{i})
    end 
    %F=scatteredInterpolant(xi(:),yi(:),f(:))
    
    [X,Y]=meshgrid(linspace(min(min(xi)),max(max(xi)),100), linspace(min(min(yi)),max(max(yi)),256));
    
    
    a = F(X,Y);
    imagesc(X(1,:),Y(:,1),ones(256,100),'alphadata',a./max(max(a)))
   
    
%     plot(stat_eta{v}(:,1),xx)
%     plot(stat_eta{v}(:,1) - stat_eta{v}(:,2),xx,'--')
%     plot(stat_eta{v}(:,1) + stat_eta{v}(:,2),xx,'--')
end
ylabel('Number of Path');
xlabel('Standardized Frobenius Norm Error')
axis tight;

figure(1); clf; hold on;
lim=8;
filename2={'frobenium_sph_8_512', 'frobenium_sph_20_512' ,'frobenium_sph_52_512'};
col={'b','r','g','y'};
for i=1:numel(filename2)
    s=load(['result-SGSIM/Constant Path/' filename2{i}]);
    xlim_b=get(gca,'xlim');
    boxplot(cell2mat(s.eta(1:lim)),cell2mat(nn(1:lim)),'Orientation','horizontal','color',col{i},'symbol',['+' col{i}]);
    xlim_a=get(gca,'xlim');
    if i>1
        xlim([ min(xlim_b(1), xlim_a(1)) max(xlim_b(2), xlim_a(2))])
    end
end
hLegend = legend(findall(gca,'Tag','Box'), {'Neighboors: 8', 'Neighboors: 20', 'Neighboors: 52'});
ylabel('Number of Path');
xlabel('Standardized Frobenius Norm Error')


lim=8;
for v=1:numel(vario)
   (mean(eta{v}{5})-mean(eta{v}{1}))./mean(eta{v}{1})
end

