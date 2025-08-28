function codes = initCodeCats
%   codes = pds.initCodes
%
% PAN-TASK function that initializes codes used to strobe events to the 
% ehpys recording system.
% These are the same codes that will identify events in the ephys file
% so this file is HOLY. 
% Once recording has been done, this file is the only way to reconstruct 
% the data so I'm not kidding-- H O L Y.
%
% For every new taks you code, it will likely use many event codes that are
% already present in this file. Enjoy them. For any new codes you might
% need, just add them to this file and verify that don't overlap with
% existing codes by running the verification cell at the bottom. 

% two kinds of strobes:
% Paired-strobe (value of 1)
% timing-strobe (value of 0)

%% task code
% Paired-strobe. Its pair is a unique task code that is set in the
% settings file, and takes the value of one of the unique task codes 
% defined in the cell "holy unique task codes", below.
codes.taskCode          = 1;

%% holy unique task codes:
% Each task gets its own unique task code for easy identification. These
% are the values that are strobed after taskCode is strboed. 
codes.uniqueTaskCode_mcd        = 1;
codes.uniqueTaskCode_gSac    	= 1;
codes.uniqueTaskCode_freeView   = 1;
codes.uniqueTaskCode_pFix       = 1;
codes.uniqueTaskCode_pFixLfp    = 1;
codes.uniqueTaskCode_pFixMotDir = 1;
codes.uniqueTaskCode_mFlash     = 1;
codes.uniqueTaskCode_tod        = 1;
codes.uniqueTaskCode_scd        = 1;
codes.uniqueTaskCode_nfl        = 1;
codes.uniqueTaskCode_gSac_jph  	= 1;
codes.uniqueTaskCode_gSac_contrast  = 1;
codes.uniqueTaskCode_seansFirstTask = 1;
codes.uniqueTaskCode_tokens         = 1;
codes.uniqueTaskCode_gSac_4factors  = 1;

%% unique codes that are internal to the 'classyStrobe' function class
% (see pds.classyStrobe.m for more details)
codes.isCell        = 1;
codes.cellLength    = 1;

%% currently using fst codse...

% trial codes
codes.trialBegin        = 0; % The very beginning of a trial 
codes.trialEnd          = 0; % The very end of a trial 
codes.connectPLX        = 1; % ???
codes.trialCount        = 1; 
codes.blockNumber       = 1; 
codes.trialInBlock      = 1;
codes.setNumber         = 1;
codes.state             = 1;
codes.trialCode         = 1;
codes.trialType         = 1;
codes.fileSufix         = 1; 
codes.taskType          = 1;
codes.goodTrialCount    = 1;
codes.goodtrialornot    = 1; % Gongchen Added on 2019/12/30 I think it is better than goodTrialCount
                                 % Also I think these codes are better
                                 % start from '2~9' rather than 1, because
                                 % the code.time_1hhmm can sometimes contaminate the code  
%%  date & time
% these codes have a '1' before the date/time signifiers because a given
% date could lose its 0, e.g. the time_hhmm: 0932, would be sent as 932. By
% adding a '1' we get 10932, thus saving the 0. As long as user remembers
% to remove the first digit from the strobed values, we're all good.
codes.date_1yyyy      = 1;
codes.date_1mmdd      = 1;
codes.time_1hhmm      = 1;

%%
codes.repeat20          = 1; % 1 = 20 repeat trials during MemSac task.
codes.vissac            = 1; % 1 = vis sac; 0 = memsac protocol
codes.inactivation      = 1; % during inactivation
codes.useMotionStim     = 1; % use motion stim for mapping


%% end of trial codes:
% code to represent a trial non strat 
codes.nonStart          = 0;
codes.joyBreak          = 0;
codes.fixBreak          = 0;
codes.fixBreak2         = 0; % this is if monkey breaks fixation whennot holding joystick in attn task


%% joystick codes
codes.joyPress              = 0;
codes.joyRelease            = 0;
codes.joyPressVoltDir       = 1; 
codes.passJoy               = 1;

%% fixation codes
codes.fixOn             = 0;
codes.fixDim            = 0;
codes.fixOff            = 0;
codes.fixAq             = 0;
codes.fixTheta          = 1;
codes.fixRadius         = 1;
codes.fixDimValue       = 1;
codes.fixChangeTrial    = 1;

%% saccade codes (used in gSac)
codes.saccadeOnset      = 0;
codes.saccadeOffset     = 0;
codes.blinkDuringSac    = 0;

%% target codes (used in gSac)
codes.targetOn          = 0;
codes.targetDim         = 0;
codes.targetOff         = 0;
codes.targetAq          = 0;
codes.targetFixBreak    = 0;
codes.targetReillum     = 0; % target reillumination after a successful memory guided saccade
codes.targetTheta       = 1;
codes.targetRadius      = 1;

%% cue codes (used in mcd)
codes.cueOn             = 0;
codes.cueOff            = 0;
codes.stimLoc1Elev      = 1;
codes.stimLoc1Ecc       = 1;
codes.stimLoc2Elev      = 1;
codes.stimLoc2Ecc       = 1;

%% stimulus codes (used in mcd, pFix, etc.)

codes.stimOnDur                 = 1;
codes.stimOffDur                = 1;
codes.stimOn                    = 0; % timing
codes.stimOff                   = 0; % timing

codes.cueChange                 = 0;
codes.foilChange                = 0;
codes.noChange                  = 0;
codes.isCueChangeTrial          = 1;
codes.isFoilChangeTrial         = 1;
codes.isNoChangeTrial           = 1;
codes.cueMotionDelta            = 1;
codes.foilMotionDelta           = 1;
codes.cueStimIsOn               = 1; % cued stimulus was shown in this trial
codes.foilStimIsOn              = 1; % foil stimulus was shown in this trial
codes.isContrastChangeTrial     = 1; % this trial had a contrast change
codes.hit                       = 1; % this trial ended in a hit
codes.miss                      = 1; % this trial ended in a miss
codes.foilFa                    = 1; % this trial ended in a foil FA
codes.cr                        = 1; % this trial ended in a CR
codes.fa                        = 1; % this trial ended in a FA
codes.stimChange                = 0;
codes.noChange                  = 0;
codes.isStimChangeTrial         = 1;
codes.isNoChangeTrial           = 1;
codes.stimLoc1On                = 1; % stimulus at location one was on in this trial
codes.stimLoc2On                = 1; % stimulus at location one was on in this trial
codes.stimLoc3On                = 1; % stimulus at location one was on in this trial
codes.stimLoc4On                = 1; % stimulus at location one was on in this trial
codes.stimChangeTrial           = 1;
codes.chgLoc                    = 1;
codes.changeLoc                 = 1;
codes.cueLoc                    = 1;

% stimulus location & direction:
codes.stimLocRadius_x100  = 1; % used to be named 'rfLocEcc'
codes.stimLocTheta_x10    = 1; % used to be named 'rfLocTheta'
codes.stimMotDir          = 1; % this is to send stim info; for eevnt codes for each dir see trialcodes.dirtun.m

% code for random number generation seeds
codes.stimSeed          = 1;
codes.trialSeed         = 1;

%% stimulus identity (used in pFix tasks):
codes.stimIdentity          = 1;
codes.stimIdentityDots      = 1;
codes.stimIdentityGabor     = 1;
codes.stimIdentityGrating   = 1;
codes.stimIdentityTarget    = 1;


%% FA PA stuff that may or may not be relevant:
% codes for PA motion task
% codes.loc1dir           = 1;
% codes.loc2dir           = 1;
% codes.loc1del           = 1;
% codes.loc2del           = 1;

% % codes for PA orientation task
% codes.loc1orn           = 16005;
% codes.loc2orn           = 16006;
% codes.loc1amp           = 16007;
% codes.loc2amp           = 16008;

%% code for TOD task
codes.targ1LocTheta_x10         = 1;
codes.targ1LocRadius_x100       = 1;
codes.targ2LocTheta_x10         = 1;
codes.targ2LocRadius_x100       = 1;
codes.earliestTar               = 1;
codes.soaDuration_x1000         = 1;
codes.overlapDuration_x1000     = 1;
codes.saccadeComplete_plus10    = 1;
codes.chosenTarget_plus10       = 1;
codes.correctOrnot_plus10       = 1;

codes.gapStart                  = 0;
codes.targ1On                   = 0;
codes.targ2On                   = 0;

%%

% code for orientations in orn tuning task
codes.orn               = 1; % this is to send stim info; for eevnt codes for each orn see trialcodes.orntun.m

% reward code
codes.reward            = 0;
codes.freeReward        = 0;
codes.noFreeReward      = 0;
codes.rewardDuration    = 1;

% micro stim codes
codes.microStimOn       = 0;

% audio codes
codes.audioFBKon        = 0;
codes.lowTone           = 0;
codes.noiseTone         = 0;
codes.highTone          = 0;

%% image codes (used in freeview)
codes.imageId           = 1;     % id of image
codes.imageOn           = 0;     % time of image onset
codes.imageOff          = 0;     % time of image offset
codes.freeViewDur       = 1;     % duration of free image viewing

% opto codes.
codes.optoStimOn        = 0;     % time of opto stim onset
codes.optoStimSham      = 0;     % time of sham opto stim
codes.optoStimTrial     = 1;     % indicator that the current trial is ...