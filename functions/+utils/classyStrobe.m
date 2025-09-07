classdef classyStrobe < handle
% CLASSYSTROBE A class for managing and sending event codes (strobes).
%
% This class provides a structured way to send numerical event markers to an
% ephys recording system (e.g., Plexon) via a Datapixx device. It allows
% for queueing values, sending them in a batch, and preventing duplicate
% strobes using a veto system.

% NOTE: This class is currently hardcoded for use with a Plexon system via
%       Datapixx. It will not work with other hardware without modification.

    properties
        % A list of values queued to be sent on the next call to 'strobeList'.
        valueList = [];

        % A boolean flag indicating if there are values in the valueList.
        armedToStrobe = false;

        % A list of values that have been strobed once and should not be
        % strobed again unless the veto is removed.
        vetoList = [];
        
        % A log of all values that have been successfully strobed.
        strobedList = [];

        % Internal codes used to handle special data types like cell arrays.
        % CRITICAL: These codes must not overlap with any experimental event
        % codes defined elsewhere (e.g., in pds.initCodes).
        internalStrobeCodes = struct('isCell', 32123, 'cellLength', 32124);
    end
    
    methods
        function self = classyStrobe(self)
            % CLASSYSTROBE Constructor for the classyStrobe class.
        end
        
        function self = addValue(self, value)
            % ADDVALUE Adds a value or list of values to the strobe queue.
            %
            % This method handles numeric arrays, cell arrays, and logicals.
            % Cell arrays are specially encoded with a header triplet for
            % robust decoding later.
            
            if isnumeric(value)
                % Add numeric scalars or vectors directly to the list.
                self.valueList = [self.valueList; value];
            
            elseif iscell(value)
                % For cell arrays, prepend each cell's data with a
                % three-part header for robust decoding:
                %   1. A code indicating the start of a cell's data.
                %   2. A code indicating that the next value is the length.
                %   3. The length of the cell's data.
                cellOfValues = value; % Use a more descriptive name.
                for ii = 1:numel(cellOfValues)
                    cellLength = numel(cellOfValues{ii});
                    
                    % Define the header triplet.
                    strobeTriplet = [self.internalStrobeCodes.isCell; ...
                                     self.internalStrobeCodes.cellLength; ...
                                     cellLength];
                    self.valueList = [self.valueList; strobeTriplet];
                    
                    % Add the actual cell contents to the list.
                    self.valueList = [self.valueList; value{ii}];
                end
                
            elseif islogical(value)
                % Convert logicals to doubles before adding to the list.
                self.valueList = [self.valueList; double(value)];
            else
                error('classyStrobe:UnsupportedType', ...
                    'Input must be numeric, cell, or logical.');
            end
            self.armedToStrobe = true;
        end
        
        function self = strobeList(self)
            % STROBELIST Sends all values currently in the valueList queue.
            
            if isempty(self.valueList)
                return; % Do nothing if the list is empty.
            end
            
            % Strobe each value in the list.
            nValues = numel(self.valueList);
            for iV = 1:nValues
                value = self.valueList(iV);
                strobe(value); % Call the local strobe function.
                % Log the strobed value for bookkeeping.
                self.strobedList(end+1) = value;
            end
            
            % Clear the list and reset the armed flag.
            self.valueList = [];
            self.armedToStrobe = false;
        end
        
        function self = strobeNow(self, value)
            % STROBENOW Immediately sends a single value, bypassing the queue.
            
            strobe(value);
            % Log the strobed value for bookkeeping.
            self.strobedList(end+1) = value;
        end
        
        function self = addValueOnce(self, value)
            % ADDVALUEONCE Adds a value to the queue for a single strobe.
            %
            % After being strobed via 'strobeList', the value is added to a
            % vetoList to prevent it from being strobed again. To re-strobe,
            % the value must be removed from the vetoList first.
            
            if any(value == self.vetoList)
                % If the value is already on the veto list, do nothing.
            else
                self.addValue(value);
                self.vetoList = [self.vetoList; value];
            end
        end
        
        function self = flushVetoList(self)
            % FLUSHVETOLIST Clears all values from the vetoList.
            self.vetoList = [];
        end
        
        function self = flushStrobedList(self)
            % FLUSHSTROBEDLIST Clears the log of all strobed values.
            self.strobedList = [];
        end
        
        function self = removeFromVetoList(self, value)
            % REMOVEFROMVETOLIST Removes a specific value from the vetoList.
            
            if any(value == self.vetoList)
                ptr = (value == self.vetoList);
                self.vetoList(ptr) = [];
            end
        end
    end
end

function [] = strobe(value, verbose)
% STROBE Core function to send a value to the ephys system via Datapixx.
%
% This function performs the low-level hardware communication to send a
% 15-bit value and a strobe pulse.

if ~exist('verbose', 'var')
    verbose = false;
end

% This sequence sends a 15-bit value and a strobe pulse to the ephys rig.
% 1. Set the 15 digital output lines to the desired 'value'.
%    The mask 32767 (or '7FFF' hex) ensures only the first 15 bits are affected.
Datapixx('SetDoutValues', value, 32767);
Datapixx('RegWr'); % Write the register to apply the change.

% 2. Set the 16th bit (the strobe line) to 1 (high).
%    The mask 65536 (or '10000' hex) targets only the 16th bit.
Datapixx('SetDoutValues', 2^16, 65536);
Datapixx('RegWr');

% 3. Reset the strobe line and all 15 data lines to 0.
%    The mask 98303 ('17FFF' hex) covers all 16 bits.
Datapixx('SetDoutValues', 0, 98303);
Datapixx('RegWr');

% For debugging, display the strobed value to the command window.
if verbose
    disp(['Strobed: ', num2str(value)]);
end
end



