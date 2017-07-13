%% Parameters

% Folder/directory information
owd='/space/raid8/data/lieber/MINERVA2/nondartel/data';  % study directory
codeDir = '/space/raid8/data/lieber/MINERVA2/nondartel/preproc/170227'; % where code lives
output='/space/raid8/data/lieber/MINERVA2/nondartel/preproc/170227/batches'; % dir in which to save scripts
subID='SLEEP_*';      % pattern for finding subject folders (use wildcards)
subNam = {'SLEEP_035'};     % do which subjects? ('all' to do all, position vector, e.g. 1:4, to do a subset)
skipSub = {};
runID='BOLD_*';     % pattern for finding functional run folders (use wildcards)
% mbwdirID='Matched_Bandwidth_HiRes*';    % pattern for finding matched-bandwidth folder (use wildcards)
mpragedirID='MPRAGE_SAG_*';  % pattern for finding mprage folder (use wildcards)

%% Setup subjects

% Find subject directories
if isempty(subNam)
    d = dir([owd '/' subID '*']);
    for ii = 1:length(d)
        subNam{ii} = d(ii).name;
        fprintf('Adding %s\n', subNam{ii})
    end
end
numSubs = length(subNam);
cd(codeDir);

% Prepare status struct
runStatus = struct('subNam',[],'status',[],'error',[]);
runStatus(numSubs).subNam = [];
runStatus(numSubs).status = [];
runStatus(numSubs).error = [];

%% Run subjects

%if you want to run just one subject, comment out pool & parfor, leave for
%uncommented -->opposite for multiple

%pool = parpool('local');
for i = 1:numSubs
%parfor i = 1:8;
    
    runStatus(i).subNam = subNam{i};
    
    if ismember(subNam{i}, skipSub) % Skip subjects or not
        runStatus(i).status = 0;
        runStatus(i).error = 'Subject in exclusion list';
        disp(['Skipping subject ' subNam{i} ', is in exclusion list']);
        continue
    else % Run subject
        disp(['Running subject ' subNam{i}]);
        try % Try running subfunction
            [runStatus(i).status, runStatus(i).error]...
                = run_nondartel_1struct(subNam{i}, owd, codeDir, output, runID, mpragedirID);
            if runStatus(i).status == 1
                disp(['subject ' subNam{i} ' successful']);
            elseif runStatus(i).status == 0
                disp([runStatus(i).error ' for ' subNam{i}]);
            end
        catch % Log if fail
            runStatus(i).status = 0;
            runStatus(i).error = 'Unexpected error in run function';
            disp(['Unexpected ERROR on subject ' subNam{i}]);
        end
    end
end
%delete(pool);

% Save stuff
date = datestr(now,'yyyymmdd_HHMM');
filename = [output '/runStatus_' date '.mat'];
save(filename,'runStatus');
filename = [output '/workspace_' date '.mat']; % Use this to re-do "run dartel" if it fails
save(filename);