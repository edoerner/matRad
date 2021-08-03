function dij = matRad_calcBrachyDose(ct,stf,pln,cst)
% matRad_calcBrachyDose calculates dose influence matrix according to the
% AAPM update Rivard et al. 2004
%
% call
%   dij = matRad_calcBrachyDose(ct,stf,pln,cst)
%
% input
%   ct:         ct cube
%   cst:        matRad cst struct
%               (positions and constraints of patient structures)
%   pln:        matRad plan meta information struct
%   stf:        struct containing geometric information
%
% output
%   dij:        stuct containing dose influence information

%%Configure
matRad_cfg =  MatRad_Config.instance();
matRad_calcBrachyDoseInit;

% initialize waitbar (always indented to seperate from important code)
        figureWait = waitbar...
            (0,'calculating dose inlfluence matrix for brachytherapy...');
        display('Starting calculation');
        tic;

%% get dose points and seedpoints
% "dosePoints" and "seedPoints" are both structs with fields x,y,z:
% each contains a 1D row vector of position components [mm]

seedPoints.x = single(stf.seedPoints.x);
seedPoints.y = single(stf.seedPoints.y);
seedPoints.z = single(stf.seedPoints.z);

[XGrid,YGrid,ZGrid] = meshgrid(dij.doseGrid.x,dij.doseGrid.y,dij.doseGrid.z);
dosePoints.x = single(reshape(XGrid,1,[]));
dosePoints.y = single(reshape(YGrid,1,[]));
dosePoints.z = single(reshape(ZGrid,1,[]));


%% get seed dosepoint distance matrix
% [seedPoint x dosePoint] matrix with relative distance as entries
% detailed documentation in function
DistanceMatrix = matRad_getDistanceMatrix(seedPoints,dosePoints);
        
        % update waitbar
        waitbar(0.125);
        display('Finished calculating distances after')
        toc;

% ignore all distances > Cutoff for the following calculations to save time
Ignore = DistanceMatrix.dist > pln.propDoseCalc.DistanceCutoff;
calcDistanceMatrix.x = DistanceMatrix.x(~Ignore);
calcDistanceMatrix.y = DistanceMatrix.y(~Ignore);
calcDistanceMatrix.z = DistanceMatrix.z(~Ignore);
calcDistanceMatrix.dist = DistanceMatrix.dist(~Ignore);
clear DistanceMatrix
% now all fields of calcDistanceMatrix are n x 1 arrays!


%% seed dosepoint angle matrix
% [seedPoint x dosePoint] matrix with relative theta angle as entries
% detailed documentation in function
% only call for 2D formalism
if strcmp(pln.propDoseCalc.TG43approximation,'2D')
    [ThetaMatrix,ThetaVector] = ...
    matRad_getThetaMatrix(pln.propStf.template.normal,calcDistanceMatrix);
end

        % update waitbar
        waitbar(0.25);
        display('Finished calculating angles after')
toc;
%% Calculate Dose Rate matrix
% Calculation according to  Rivard et al. (2004): AAPM TG-43 update

DoseRate = zeros(length(dosePoints.x),length(seedPoints.x));
switch pln.propDoseCalc.TG43approximation
    case '1D'
        DoseRate(~Ignore) = ...
        matRad_getDoseRate1D_poly(machine,calcDistanceMatrix.dist);
    case '2D'
        DoseRate(~Ignore) = ...
        matRad_getDoseRate2D_poly(machine,calcDistanceMatrix.dist,ThetaMatrix);
end
        

        % update waitbar, delete waitbar
        waitbar(1);
        display('Finished calculating Doses after')
        toc;
        pause(1);
        delete(figureWait);


dij.physicalDose = {DoseRate};
end



