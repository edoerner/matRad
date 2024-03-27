% matRad script
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright 2015 the matRad development team. 
% 
% This file is part of the matRad project. It is subject to the license 
% terms in the LICENSE file found in the top-level directory of this 
% distribution and at https://github.com/e0404/matRad/LICENSES.txt. No part 
% of the matRad project, including this file, may be copied, modified, 
% propagated, or distributed except according to the terms contained in the 
% LICENSE file.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% set matRad runtime configuration
matRad_rc

%% load patient data, i.e. ct, voi, cst

%load HEAD_AND_NECK
load PROSTATE.mat
%load PROSTATE.mat
%load LIVER.mat
%load BOXPHANTOM.mat

% meta information for treatment plan
pln.numOfFractions  = 30;
pln.radiationMode   = 'brachy';           % either photons / protons / helium / carbon / brachy
pln.machine         = 'HDR';              % generic for RT / LDR or HDR for BT

% beam geometry settings
pln.propStf.bixelWidth      = 5; % [mm] / also corresponds to lateral spot spacing for particles
pln.propStf.gantryAngles    = [0:72:359]; % [°] ;
pln.propStf.couchAngles     = [0 0 0 0 0]; % [°] ; 
pln.propStf.numOfBeams      = numel(pln.propStf.gantryAngles);
pln.propStf.isoCenter       = ones(pln.propStf.numOfBeams,1) * matRad_getIsoCenter(cst,ct,0);
% optimization settings
pln.propOpt.runDAO          = false;      % 1/true: run DAO, 0/false: don't / will be ignored for particles
pln.propOpt.runSequencing   = false;      % 1/true: run sequencing, 0/false: don't / will be ignored for particles and also triggered by runDAO below

quantityOpt  = 'physicalDose';     % options: physicalDose, effect, RBExD
modelName    = 'none';             % none: for photons, protons, carbon, brachy           % constRBE: constant RBE for photons and protons 
                                   % MCN: McNamara-variable RBE model for protons  % WED: Wedenberg-variable RBE model for protons 
                                   % LEM: Local Effect Model for carbon ions       % HEL: data-driven RBE parametrization for helium
% dose calculation settings
pln.propDoseCalc.doseGrid.resolution.x = 5; % [mm]
pln.propDoseCalc.doseGrid.resolution.y = 5; % [mm]
pln.propDoseCalc.doseGrid.resolution.z = 5; % [mm]

scenGenType  = 'nomScen';          % scenario creation type 'nomScen'  'wcScen' 'impScen' 'rndScen'                                          

% retrieve bio model parameters
pln.bioParam = matRad_bioModel(pln.radiationMode,quantityOpt, modelName);

% retrieve scenarios for dose calculation and optimziation
pln.multScen = matRad_multScen(ct,scenGenType);

% optimization settings
pln.propOpt.optimizer       = 'IPOPT';
% pln.propOpt.bioOptimization = 'none'; % none: physical optimization;             const_RBExD; constant RBE of 1.1;
%                                       % LEMIV_effect: effect-based optimization; LEMIV_RBExD: optimization of RBE-weighted dose
pln.propOpt.runDAO          = false;  % 1/true: run DAO, 0/false: don't / will be ignored for particles
pln.propSeq.runSequencing   = true;  % true: run sequencing, false: don't / will be ignored for particles and also triggered by runDAO below


%% initial visualization and change objective function settings if desired
matRadGUI

%% generate steering file 
% -marios interchanging the stfs between normal RT and BT
if strcmp(pln.radiationMode, 'brachy')
    stf = matRad_generateBrachyStf(ct,cst,pln,1);
elseif ismember(pln.radiationMode, {'photons', 'protons', 'helium', 'carbon'})
    stf = matRad_generateStf(ct,cst,pln);
end

%% dose calculation
if strcmp(pln.radiationMode, 'brachy')
    dij = matRad_calcBrachyDose(ct, stf, pln, cst);

elseif ismember(pln.radiationMode, {'photons', 'protons', 'helium', 'carbon'})
    dij = matRad_calcDoseInfluence(ct, cst, stf, pln);

end

%% inverse planning for imrt
resultGUI  = matRad_fluenceOptimization(dij,cst,pln);

%% sequencing
resultGUI = matRad_sequencing(resultGUI,stf,dij,pln);


%% DAO
if strcmp(pln.radiationMode,'brachy') && pln.propOpt.runDAO
   resultGUI = matRad_directApertureOptimization(dij,cst,resultGUI.apertureInfo,resultGUI,pln);
   matRad_visApertureInfo(resultGUI.apertureInfo);
end

%% start gui for visualization of result
matRadGUI

%% indicator calculation and show DVH and QI
[dvh,qi] = matRad_indicatorWrapper(cst,pln,resultGUI);

