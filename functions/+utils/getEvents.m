function eventsPerTrial = getEvents(startTimes, eventValues, eventTimes, stimcode)



% function that obtains the events that occured for each trial and stores
% them in a cell array called eventsPerTrial.

nTrials = length(startTimes);
% eventsPerTrial = zeros(nTrials, 10);
eventsPerTrial = [];

% determine the events that occur during each trial.
for i = 1:nTrials
    if i < nTrials
        eventsLogical = eventTimes > startTimes(i) & ...
            eventTimes < startTimes(i+1);
    else
        eventsLogical = eventTimes > startTimes(i); % this line is specific to the last trial -- if it's the last trial, only look for eventTimes that occured after the last startTime.
    end

    % Store the event values for the current trial in temp_events
    temp_events = eventValues(eventsLogical);

    %check to see if current trial event values include the "task type" for
    %the "Attention task" and checking to see if there ia a vlaue after
    %11099
    
    stimcodeIdx = temp_events == stimcode;

    if any(temp_events == stimcode)
        eventsPerTrial(i) = temp_events(circshift(stimcodeIdx, 1));
    end
    
end
end