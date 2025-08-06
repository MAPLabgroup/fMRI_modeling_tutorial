%% this is a demo script of how you might extract some onset times of interest from a behavioral log from your task, so that you can do 1st-lvl modeling
% NOTE: there is no one-size fits all for all studies, nor do you have to
% use a matlab script to do this at all.
% What is critical is that at the end you have a matlab data structure
% (.mat) file with names, onsets, and durations arrays in it (see SPM
% tutorials and their sample data as well for examples...)
%
%
% You must change the subject number and run_names
%
% This .M script is used for the NECOS experiment which you can read about
% here: https://pmc.ncbi.nlm.nih.gov/articles/PMC8373678/

% this script will NOT run unless you also have "seekstr.m" script (also in
% this repository) in your matlab path. That is a helper script that
% contains a function which "seeks" out strings (lines of text) in your log
% file

% "run_names" should be in the correct order of the experiment. To find this
% information, refer to your notes for your study (e.g., you likely have an experiment randomization excel sheet or the log
% book.)
% "run_durations", in TRs, must be set according to exact times recorded in log
% book / the exact number of images acquired in the run

% Every single event type of the experiment that you want to be modeled must be
% represented below as a vector. These will be used to create the regressors.

%% study prefixes, paths, parameters you need to specify for the code to find and read the correct files...
sub = 12; %what is the subject ID you want to analyze? The rest of the name is filled in below...
run_names = {'1','2','3','4','5'}; %what are the scan run numbers you want to analyze? the rest of the runs' names are "filled in" below, but I put this here as an example, in case you want to manually skip a run file for a subject for some reason
runs = 5; %how many runs are there for this subject?

run_durations = [428, 406, 384, 382, 378]; %how long (this code assumes in SECONDS, NOT TRs) are each of your scan runs? \\
% Note: you could replace this hard-coding with some lines that go into each run folder and count how many files there are, IF your files \\
% are 3D niftis and not 4D ones. If you do that, many sure you only count the preprocessed files you will analyze (that is, make sure \\
% it doesn't double-count each file by countint the slice-time corrected and the non-slice-time corrected copies...

logname_prefixes = 'new_conte_';%what are your desired log file names called? we specify this because maybe you have other files in that folder you don't want to analyze...

pathtodata = 'C:\Users\giova\GaTech Dropbox\CoS\Psychology\MAP_Lab\Published_study_files_archive\NECOS_taskfiles\new_conte_task_eprime\data\behavioral_data\'; %where is the folder \\
% that contains behavioral data for your subjects? Here, we assume inside "behavioral_data" there is a folder for  subject "necos1", for "necos2", etc - and in their folders are the log files



%% first, let's have our code change directories to our desired subject...
cd([pathtodata 'necos' num2str(sub) '_tutorial']); %this enters the folder for the subject (necos) with ID # specified above


%% second, load your text log files (in this case, from e-prime software), one at a time, into MATLAB using its text reading capabilities
for run = 1:runs
    % Builds e-prime output text filename for matlab
    filename = [logname_prefixes num2str(sub) '-run' num2str(run) '.txt'];
    fid = fopen(filename, 'r','ieee-le','UTF-8'); % "r" is telling it to read file
    F = fread(fid);
    s = char(F');
    s =s(find(s~=char(0)));
    fclose(fid);


    %% say you want to model two types of events (NOTE a real analysis will likely need 8+ event types modeled to be sufficiently precise for your research questions...)
    % 1) when were they given the "cue" for what context the current trial is
    % (in this case, what environment season, heading direction...)?
    % 2) when were they given the "test" image where they make a choice from
    % memory?

    %this section defines what we call "conditions" to use as regressors in SPM
    %1st-level modeling

    %Event onsets for cue images and then test images
    oevents = {'cueimage','testimage'}; % CRITICAL - this is text you are searching for in your log file \\
    % - the more specific it is to the event you want to find the better (e.g., don't use "imagedisplay" \\
    % or something if that is a process your code runs and logs for BOTH the cue image AND the test \\
    % image - then this section of code will grab onset times for both types of events but treat them as the same event). \\
    % However, when desperate or in doubt, you can probably come up with a clever way of dividing up non-specific onset \\
    % times like that into what you really want (e.g., if the onset times you have are for cues and tests, and cue and test \\
    % events simply alternate in your task, you could pull out the onset times specific to the test period by simply taking \\
    % every other value from this list of onset times)
    for i = 1:length(oevents) % for each event type you want to seek out in your log file...
        %my onset times are numbers in the log that sit in-between two
        %strings: the number I want comes AFTER the text reading
        %"OnsetTime" and BEFORE the text reading [eventname].DurationError.
        % So...
        onsetofevent = [char(oevents(i)) '.OnsetTime'];
        onsetofNEXTevent = [char(oevents(i)) '.DurationError'];
        [event_ind] = seek_str(s,onsetofevent); %to start finding the numbers for the time
        [nextevent_ind] = seek_str(s,onsetofNEXTevent); %to stop reading the onset time numbers

        event_times = []; %make an empty temporary vector to store all the onset times I find between those two strings in my log file

        for j = 1:length(event_ind)
            event_time = str2num(s(event_ind(j)+length(onsetofevent)+2:nextevent_ind(j)-1)); %if you look at the log file, the \\
            % actual number starts 2 characters after the string "OnsetTime" and ends one blank "space" (character) before the text \\
            % for the next event in the log file. Therefore to pin down the characters of interes (my onset time number) in this line \\
            % of code I'm doing +2 characters and -1 characters

            event_times = [event_times; event_time/1000]; %SPM takes onset times in seconds, not milliseconds, so I convert this into seconds by /1000
        end

        eval(['event_times' num2str(i) ' = event_times;']); %finally, to avoid overwriting the first condition's onset times when we seek out the \\
        % second condition's onset times, we change the variable name to have the event number associated with it

    end


    %% but there's a problem - your onset times are usually "wrong" because the code starts logging before the scanner has started. So you want to \\
    % adjust these times to when the trigger "t" happened!
    % Ideally, your log file actually has a named timestamp for when the "t" happened - but in NECOS the first Cue image appears \\
    % as soon as the "t" happens - so its onset time is equivalent to when
    % the scanner started


    %to addust onsets to the run start time ("t")...

    t_onset_time = event_times1(1); %again, my first cueimage event = when the "t" happened. Edit this code as needed to provide the "t" time to our script here

    for i=1:length(oevents)
        eval(['event_times' num2str(i) ' = event_times' num2str(i) '-t_onset_time;']) %this line of code is taking the event times you pulled from the log file, \\
        % and subtracting the time the "t" happened from them, which is adjusting the behavioral timestamps so they line of up with the timestamps in the MRI recordings

        %The next line below is OPTIONAL: uncomment it if you want to then
        % go and adjust the timestamps further such that they can be "concatenated"
        % into one behavioral timeseries instead of "resetting to 0s" each run. This
        %is **NOT recommended** for most studies, because there are shifts in
        %MRI signal between each scan run, and if you do this it means you are
        %going to ignore that fact and pretend the data are all just one
        %timeseries (as if there was only one scan run).
        % SPM and other packages can only do so much to
        %counteract that assumption - they can remove linear and curvilinear trends
        % in the signal but struggle to remove abrupt steps between runs.
        %
        % HOWEVER, if you have few trials (or even 0!) of a condition of
        % interest in some runs of the task, it may still be best to do this
        % and concatenate the timepoints into one continuous
        %timeseries of events.
        %
        % Why? Think back to when you have learned about
        %correlations and regression. Would you do a regression with only 3
        %datapoints? Fitting a line between a dependent measure (brain activity) and
        % just 3 datapoints from the predictor (e.g., cueimages) is possible, but
        %extremely sensitive to noise (if one of those datapoints shifts
        %just slightly the line moves too). That's what you are doing in the recommended case if
        %you model each run separately with the timestamps resetting to 0
        % WHEN there are only a few trials for your experimental condition in
        %that run.

        % nevertheless, this is a decision you must make informed as an
        % experimenter. In SPM you can actually estimate brain activity
        % from a SINGLE trial, and you might have an experimental reason to
        % do that (e.g., you are interested in a unique episodic memory
        % which, by definition, can only be experienced once to be a pure
        % episodic memory). In that case even with small trial counts it
        % doesn't make sense to concatenate the data and you should stay
        % with the recommended option and leave the next section commented
        % out

        % uncomment next 3 lines if concatenating run data into one model
        % if run > 1
        %     eval(['event_times' num2str(i) ' = event_times' num2str(i) '+ sum(run_durations(1: ' num2str(run) ' -1));']) %what this optional code line does is add the durations of the prior scan runs to the onset times of the current run, thus putting its onset times into a "continuous count up" from the start to end of the study
        % end
    end

    %% side note, you can do this same thing to extract other behavioral things of interest from your log - e.g., instead \\
    % of onset times for modeling, you can pull out reaction times for each test period with the same type of code!

    % %response times
    % event = {'testimage'};
    % for i = 1:length(event)
    %     eventp0 = [char(event(i)) '.RTTime'];
    %     eventp2 = [char(event(i)) '.ACC'];
    %     [event_ind] = seek_str(s,eventp0); %to start
    %     [eventp2_ind] = seek_str(s,eventp2); %to stop
    %     response_times = [];
    %     for j = 1:length(event_ind)
    %         %this code uses "character numbers" to target the RTTime value
    %         % - a +2 value means the number lies 2 spaces ahead
    %         response_time = str2num(s(event_ind(j)+length(eventp0)+2:eventp2_ind(j)-1));
    %         response_times = [response_times; response_time/1000];
    %     end
    %     response_times = response_times-onset_time_exp;
    %     eval(['response_times' num2str(i) ' = response_times;']);
    %     if run >1
    %         eval(['response_times' num2str(i) ' = response_times' num2str(i) '+sum(run_durations(1: ' num2str(run) ' -1));'])
    %     end
    % end

    %% finally, let's rename this in the format SPM wants

    names = {'cue', 'test'}; %spm needs to you provide it with NAMES for your conditions. You type whatever you want your conditions \\
    % to be called in your SPM analyses here, to assign a name to the bins of events you've calculated so far.
    onsets = {event_times1', event_times2'}; %SPM needs those onset times in a row (not columns) so I transposed them with a "'"
    durations = {[0], [0]}; %if your events are a "stick" function (i.e., you want to model them as a single canonical HRF) you can \\
    % enter "0" once. If you provide any number just once for a condition's DURATION, even if there are 30 onsets corresponding to it, \\
    % SPM is smart enough to know/assume all 30 events have that same
    % duration. \\


    %% save your "model file" for this run, for use by SPM
    savename= ['necos' num2str(sub) '_modelfile_run' run_names{run} ];
    save(savename, 'names', 'onsets', 'durations');

end


 %% independent study part 1
    % HOWEVER - especially for an "event-related design" each event for a
    % given condition is often NOT the same duration. E.g., a
    % decision-point in a maze might have taken 1.5s on trial 1, and 2s on
    % trial 2. If you want to capture this variability in your model
    % (usually, yes you do) then you must enter a vector of durations, with
    % the number of values being the same as the number of onsets you have
    % for that event. The best way to do this is through coding... just
    % like you used the script above to search for onset times
    % corresponding to your events, you could have a separate set of lines
    % hunting for a corresponding duration value for each of those events.
    % E.g., each time it finds a "cue" in this tutorial, it grabs the
    % participant's response time to that cue event and stores that as a
    % duration to go along with the onset time for that event. 
    % 

    % Save a copy of this code and try this on your own: see if you can correctly \\
    % pull in duration values matching what you
    % find by skimming the log file by eye! To make things easy, use the
    % "duration" entry for the cue images i nthe log file, and the response time ("RT") \\
    % entry in the log file corresponding to the test events as your model of the
    % duration of the neural response to the event



%% independent study part 2

% most studies are more complex than having just two conditions (here, cue
% and test images). Technically, those event types can be treated as
% conditions for modeling, but more than likely what you actually want to
% do is compare the brain response between different types of cue images -
% in this case, my task had 3 psychologically-interesting experimental
% conditions (STAY rule trials, rule SUBORDINATE trials, and SUPERORDINATE
% switch trials). All 3 of these conditions have cue images in them - so
% you aren't actually interested in modeling the brain's average response
% to cue images in my study. Rather, to compare how the brain responds to
% cue images depending on the experimental condition, you want to model 3
% different types of cue events.

% You already have almost all the tools you need to do this. The code above
% already finds onsets for every cue image based on seeking out the string
% in the log file denoting when a cue event happens. What you are missing
% is a SECOND search criterion - something that can be used to then divide
% those cue events up further into ones for, e.g., STAY trials, vs.
% SUBORDINATE trials.

% There are many ways to identify and implement such a second rule, and it
% will depend on your log files and what kind of info you put in them. This
% is why you should ideally do this tutorial BEFORE running your study -
% this will prompt you to design what goes into your log files according to
% what you know you will want to do with those log files after they've been
% recorded...

% For this study tutorial, I was smart and gave my conditions a "type"
% entry - this number signifies the condition type. 
% STAY trials are type = 600 and 500
% SUBORDINATE trials are type = 601 and 501
% SUPERORDINATE switch trials are type = 602 and 502

% Another thing I did was label each decision period with a "code" = 10.
% There are other times in the task - some of them do NOT occur once per
% cue and test trial. But the "10" codes do. This is useful because if I find each "code" and "type" in the log, and
% I restrict the type numbers down to ones where the corresponding code =
% 10, then I have gone line by line through the log file and grabbed the
% condition types, in order, that correspond to each cue and test onset
% time.

% 
%     conditioncode = {'code','type'}; %same logic as above - identify some strings we want \\
%     % to track down in the log. This time it's lines with a "code" and "type"
%     for i = 1:length(conditioncode)
%         code = (char(conditioncode(i)));
%         [event_ind] = seek_str(s,code); %to start
%         event_codes = [];
%         for j = 1:length(event_ind)
%             event_code = str2num(s(event_ind(j)+length(code)+2:event_ind(j)+length(code)+6));
%             if isempty(event_code), event_code = -99;
%             end
%             event_codes = [event_codes; event_code];
%         end
%         eval(['event_codes' num2str(i) ' = event_codes;'])
%     end
% 
% 
% type_choiceevents = [];
% 
% 
%     for i = 1:length(event_codes1)
%         %seeks out choice point codes and grabs the corresponding condition type
%         if event_codes1(i) == 10
%             %code_choiceevents = [code_choiceevents event_codes1(i)];
%             type_choiceevents=[type_choiceevents event_codes2(i)];
%         end
%     end
% 
% 
%      type_label_for_each_onset = type_choiceevents;%ok... now it's up to you, \\
%      % can you split the conditions' onsets you found up according to these labels?
% 
%      %A couple of hints for doing this:
%      % 1) First, you should know the nature of your numbers here - I know my trick
%      % for finding condition labels probably worked IF the number of
%      % "type_label_for_each_onset" is the same as the number of onsets for
%      % the cue and test periods here. If that number isn't the same...
%      % something is off with my logic in the code and what strings I'm
%      % seeking out. E.g., in run 1, there are 115 cue events for this
%      % subject, therefore there should be 115 numbers for onset AND the
%      % "type_label_for_each_onset" if this logic is going to work.
%      % 2) Your number of names, onsets, and conditions must always be equal
%      % - right now you have two (cue and test). If you are splitting those
%      % out by condition type here then you should wind up with 6 entries in
%      % names, onsets, and durations - i.e., cue_SUBORDINATE, cue_SUPERORDINATE,
%      % cue_stay, test_SUBORDINATE, test_SUPERORDINATE, test_stay
% 
%  end

