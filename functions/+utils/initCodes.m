function codes = initCodes()
% INITCODES Defines numerical values for all strobe event codes.
%
% This function creates a structure that assigns a unique numerical value
% to every event code used in the experimental tasks. This file is the
% counterpart to `initCodeCats.m`, which defines the category of each code.
%
% NOTE: This file is a critical part of the data analysis pipeline.
% Changing any of these values will break the analysis of all previously
% collected data. New codes can be added, but existing codes must not be
% changed. The validation section at the end helps ensure uniqueness.

%% Task Identification Codes
% Paired-strobe. Its pair is a unique task code that is set in the
% settings file.
codes.taskCode          = 32000;

% Each task gets its own unique task code for easy identification.
codes.uniqueTaskCode_mcd        	= 32001;
codes.uniqueTaskCode_gSac    		= 32002;
codes.uniqueTaskCode_freeView   	= 32003;
codes.uniqueTaskCode_pFix       	= 32004;
codes.uniqueTaskCode_pFixLfp    	= 32005;
codes.uniqueTaskCode_pFixMotDir 	= 32006;
codes.uniqueTaskCode_mFlash     	= 32007;
codes.uniqueTaskCode_tod        	= 32008;
codes.uniqueTaskCode_scd        	= 32009;
codes.uniqueTaskCode_nfl        	= 32010;
codes.uniqueTaskCode_gSac_jph  		= 32011;
codes.uniqueTaskCode_gSac_contrast  = 32012;
codes.uniqueTaskCode_seansFirstTask = 32013;
codes.uniqueTaskCode_tokens         = 32014;
codes.uniqueTaskCode_gSac_4factors  = 32015;

%% Internal Codes
% These codes are used by the 'classyStrobe' utility.
codes.isCell        = 32123;
codes.cellLength    = 32124;

%% Trial-level Codes
codes.trialBegin        = 30001; % The very beginning of a trial.
codes.trialEnd          = 30009; % The very end of a trial.
codes.connectPLX        = 11001; % TODO: Clarify purpose.
codes.trialCount        = 11002; 
codes.blockNumber       = 11003; 
codes.trialInBlock      = 11004;
codes.setNumber         = 11005;
codes.state             = 11008;
codes.trialCode         = 11009;
codes.trialType         = 11010;
codes.fileSufix         = 11011; 
codes.taskType          = 11099;
codes.goodTrialCount    = 11100;
codes.goodtrialornot    = 21101; % 1 if trial was good, 0 if bad.

%% Date & Time Codes
% '1' is prepended to prevent loss of leading zeros (e.g., 0932 -> 10932).
codes.date_1yyyy      = 11102;
codes.date_1mmdd      = 11103;
codes.time_1hhmm      = 11104;

%% Task-Specific Flags
codes.repeat20          = 11098; % 1 = 20 repeat trials in MemSac task.
codes.vissac            = 11097; % 1 = vis sac; 0 = memsac protocol.
codes.inactivation      = 11095; % During inactivation.
codes.useMotionStim     = 11094; % Use motion stim for mapping.

%% End of Trial Codes
codes.nonStart          = 22004;
codes.joyBreak          = 2005;
codes.fixBreak          = 3005;
codes.fixBreak2         = 3006; % Fixation break while not holding joystick.

%% Saccade Codes
codes.saccadeOnset      = 2003;
codes.saccadeOffset     = 2004;
codes.blinkDuringSac    = 2007;
codes.saccToTargetOne	= 3007; % Saccade made to target one.
codes.saccToTargetTwo	= 3008; % Saccade made to target two.

%% Joystick Codes
codes.joyPress          = 2001;
codes.joyRelease        = 2002;
codes.joyPressVoltDir   = 2010;
codes.passJoy           = 2011;

%% Fixation Point Codes
codes.fixOn             = 3001;
codes.fixDim            = 3002;
codes.fixOff            = 3003;
codes.fixAq             = 3004;
codes.fixTheta          = 13001;
codes.fixRadius         = 13002;
codes.fixDimValue       = 13003;
codes.fixChangeTrial    = 13004;

%% Target Codes
codes.targetOn          = 4001;
codes.targetDim         = 4002;
codes.targetOff         = 4003;
codes.targetAq          = 4004;
codes.targetFixBreak    = 4005;
codes.targetReillum     = 4006; % Target re-illumination after mem-guided saccade.
codes.targetTheta       = 14001;
codes.targetRadius      = 14002;

%% Cue Codes
codes.cueOn             = 5001;
codes.cueOff            = 5003;
codes.stimLoc1Elev      = 15001;
codes.stimLoc1Ecc       = 15002;
codes.stimLoc2Elev      = 15003;
codes.stimLoc2Ecc       = 15004;

%% Stimulus Codes
codes.stimOnDur                 = 5991;
codes.stimOffDur                = 5992;
codes.stimOn                    = 6002;
codes.stimOff                   = 6003;
codes.cueChange                 = 6004;
codes.foilChange                = 6005;
codes.noChange                  = 6006;
codes.isCueChangeTrial          = 6007;
codes.isFoilChangeTrial         = 6008;
codes.isNoChangeTrial           = 6009;
codes.cueMotionDelta            = 6010;
codes.foilMotionDelta           = 6011;
codes.cueStimIsOn               = 6012;
codes.foilStimIsOn              = 6013;
codes.isContrastChangeTrial     = 6014;
codes.hit                       = 6015;
codes.miss                      = 6016;
codes.foilFa                    = 6017;
codes.cr                        = 6018;
codes.fa                        = 6019;
codes.stimChange                = 6020;
% codes.noChange                  = 6021; % Note: Duplicate name.
codes.isStimChangeTrial         = 6022;
% codes.isNoChangeTrial           = 6023; % Note: Duplicate name.
codes.stimLoc1On                = 6024;
codes.stimLoc2On                = 6025;
codes.stimLoc3On                = 6026;
codes.stimLoc4On                = 6027;
codes.stimChangeTrial           = 16003;
codes.chgLoc                    = 16004;
codes.cueLoc                    = 16005;
codes.stimLocRadius_x100        = 16001;
codes.stimLocTheta_x10          = 16002;
codes.stimMotDir                = 24000;
codes.stimSeed                  = 16666;
codes.trialSeed                 = 16667;
codes.orn                       = 25000;

%% Reward, Audio, and Other Codes
codes.reward            = 8000;
codes.freeReward        = 8001;
codes.noFreeReward      = 8002;
codes.rewardDuration    = 18000;
codes.microStimOn       = 7001;
codes.audioFBKon        = 9000;
codes.lowTone           = 9001;
codes.noiseTone         = 9002;
codes.highTone          = 9003;
codes.imageId           = 6660;
codes.imageOn           = 6661;
codes.imageOff          = 6662;
codes.freeViewDur       = 6663;

%% Tokens Task Codes
codes.CUE_ON                = 5;
codes.REWARD_GIVEN          = 7;
codes.TRIAL_END             = 6;
codes.REWARD_AMOUNT_BASE    = 100;
codes.OUTCOME_DIST_BASE     = 90;
codes.rwdAmt                = 101;

%% gSac_4factors Task Codes
codes.halfBlock     = 16010;
codes.stimType      = 16011;
codes.salience      = 16012;
codes.targetColor   = 16013;
codes.targetLocIdx  = 16014;

%% Optical Stimulation Codes
codes.optoStimOn        = 17001;
codes.optoStimTrial     = 17002;
codes.optoStimSham      = 17003;

%% Validation Section
% This section checks for duplicate numerical values in the codes structure
% to ensure that every defined code is unique.

% Use structfun to extract all numerical values from the struct.
allValues = structfun(@(x) x, codes);

% Find any values that occur more than once.
uValues = unique(allValues);
counts = histc(allValues, uValues);
duplicateCodes = uValues(counts > 1);

if ~isempty(duplicateCodes)
    flds = fieldnames(codes);
    dupeNames = {};
    for d = 1:numel(duplicateCodes)
        dupeNames = [dupeNames; flds(structfun(@(x) x==duplicateCodes(d), codes))];
    end

    error('initCodes:DuplicateValues', ...
        'Duplicate code values found! Fix immediately.\n%s', ...
        strjoin(dupeNames,', '));
end

end