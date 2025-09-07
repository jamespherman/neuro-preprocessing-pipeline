function codes = initCodeCats()
% INITCODECATS Defines categories for all strobe event codes.
%
% This function creates a structure that assigns a category to every
% event code used in the experimental tasks. This categorization is
% critical for the data parsing function `utils.getEventTimes.m`.
%
% There are two categories for event codes:
%   - Timing Strobe (value of 0): Marks a specific point in time when an
%     event occurred (e.g., fixOn, targetOn).
%   - Information Strobe (value of 1): Indicates that the *next* strobed
%     value is not a code, but rather the data value for a variable
%     (e.g., trialCount, stimSeed).
%
% NOTE: This file is a critical part of the data analysis pipeline.
% Modifying the values in this file without a corresponding change in the
% data acquisition code will break the analysis of all previously
% collected data.

%% Task Identification Codes
% Paired-strobe. Its pair is a unique task code that is set in the
% settings file. The value is defined in `initCodes.m`.
codes.taskCode          = 1;

% The following 'uniqueTaskCode' fields are for categorizing the *value*
% that follows the 'taskCode' strobe. They are all info strobes.
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

%% Internal Codes
% These codes are used by the 'classyStrobe' utility to handle
% special data types like cell arrays.
codes.isCell        = 1;
codes.cellLength    = 1;

%% Trial-level Codes
codes.trialBegin        = 0; % The very beginning of a trial.
codes.trialEnd          = 0; % The very end of a trial.
codes.connectPLX        = 1; % Status of Plexon connection.
codes.trialCount        = 1; % The sequential trial number from PLDAPS.
codes.blockNumber       = 1; % The block number.
codes.trialInBlock      = 1;
codes.setNumber         = 1;
codes.state             = 1; % The state of the trial state machine.
codes.trialCode         = 1;
codes.trialType         = 1;
codes.fileSufix         = 1; 
codes.taskType          = 1;
codes.goodTrialCount    = 1;
% Indicates if the trial was successful (e.g., 1=good, 0=bad).
codes.goodtrialornot    = 1;

%% Date & Time Codes
% These codes have a '1' prepended to the date/time value to prevent
% the loss of leading zeros (e.g., time 09:32 becomes 10932).
codes.date_1yyyy      = 1;
codes.date_1mmdd      = 1;
codes.time_1hhmm      = 1;

%% Task-Specific Flags
codes.repeat20          = 1; % Flag for repeat trials in MemSac task.
codes.vissac            = 1; % 1 = visually-guided sac; 0 = memory-guided sac.
codes.inactivation      = 1; % Flag for inactivation sessions.
codes.useMotionStim     = 1; % Flag for using motion stimuli.

%% End of Trial Codes
codes.nonStart          = 0; % Trial aborted because subject failed to start.
codes.joyBreak          = 0; % Trial aborted due to premature joystick release.
codes.fixBreak          = 0; % Trial aborted due to fixation break.
codes.fixBreak2         = 0; % A secondary fixation break code.

%% Joystick Codes
codes.joyPress              = 0;
codes.joyRelease            = 0;
codes.joyPressVoltDir       = 1; 
codes.passJoy               = 1; % Flag to simulate correct joystick behavior.

%% Fixation Point Codes
codes.fixOn             = 0;
codes.fixDim            = 0;
codes.fixOff            = 0;
codes.fixAq             = 0;
codes.fixTheta          = 1;
codes.fixRadius         = 1;
codes.fixDimValue       = 1;
codes.fixChangeTrial    = 1;

%% Saccade Codes
codes.saccadeOnset      = 0;
codes.saccadeOffset     = 0;
codes.blinkDuringSac    = 0;
codes.saccToTargetOne	= 0; % Saccade was made to target one.
codes.saccToTargetTwo	= 0; % Saccade was made to target two.

%% Target Codes
codes.targetOn          = 0;
codes.targetDim         = 0;
codes.targetOff         = 0;
codes.targetAq          = 0;
codes.targetFixBreak    = 0;
codes.targetReillum     = 0; % Target re-illumination after mem-guided saccade.
codes.targetTheta       = 1;
codes.targetRadius      = 1;

%% Cue Codes
codes.cueOn             = 0;
codes.cueOff            = 0;
codes.stimLoc1Elev      = 1;
codes.stimLoc1Ecc       = 1;
codes.stimLoc2Elev      = 1;
codes.stimLoc2Ecc       = 1;

%% Tokens Task Codes
codes.CUE_ON                = 0;
codes.REWARD_GIVEN          = 0;
codes.TRIAL_END             = 0;
codes.REWARD_AMOUNT_BASE    = 1;
codes.OUTCOME_DIST_BASE     = 1;
codes.rwdAmt                = 1;

%% gSac_4factors Task Codes
codes.halfBlock     = 1;
codes.stimType      = 1;
codes.salience      = 1;
codes.targetColor   = 1;
codes.targetLocIdx  = 1;

%% Stimulus Codes
codes.stimOnDur                 = 1;
codes.stimOffDur                = 1;
codes.stimOn                    = 0;
codes.stimOff                   = 0;
codes.stimChange                = 0;
codes.noChange                  = 0; % Note: redundant with stimChange?

% Trial type info
codes.isCueChangeTrial          = 1;
codes.isFoilChangeTrial         = 1;
codes.isNoChangeTrial           = 1;
codes.isContrastChangeTrial     = 1;
codes.isStimChangeTrial         = 1; % Note: redundant.

% Trial outcome info
codes.hit                       = 1;
codes.miss                      = 1;
codes.foilFa                    = 1;
codes.cr                        = 1;
codes.fa                        = 1;

% Stimulus location info
codes.stimLoc1On                = 1;
codes.stimLoc2On                = 1;
codes.stimLoc3On                = 1;
codes.stimLoc4On                = 1;
codes.stimChangeTrial           = 1; % Note: redundant.
codes.chgLoc                    = 1;
codes.changeLoc                 = 1; % Note: redundant with chgLoc.
codes.cueLoc                    = 1;
codes.stimLocRadius_x100        = 1;
codes.stimLocTheta_x10          = 1;
codes.stimMotDir                = 1;

% Random number generation seeds
codes.stimSeed                  = 1;
codes.trialSeed                 = 1;

% Stimulus identity info
codes.stimIdentity          = 1;
codes.stimIdentityDots      = 1;
codes.stimIdentityGabor     = 1;
codes.stimIdentityGrating   = 1;
codes.stimIdentityTarget    = 1;

%% TOD Task Codes
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

%% Orientation Tuning Codes
codes.orn               = 1;

%% Reward Codes
codes.reward            = 0;
codes.freeReward        = 0;
codes.noFreeReward      = 0;
codes.rewardDuration    = 1;

%% Other Codes
codes.microStimOn       = 0;
codes.audioFBKon        = 0;
codes.lowTone           = 0;
codes.noiseTone         = 0;
codes.highTone          = 0;
codes.imageId           = 1;
codes.imageOn           = 0;
codes.imageOff          = 0;
codes.freeViewDur       = 1;
codes.optoStimOn        = 0;
codes.optoStimSham      = 0;
codes.optoStimTrial     = 1;
end