%% User-editable Parameters

% Path/directory/name information
owd = '/u/project/sanscn/kevmtan/scripts/SPM12_nondartel/spm12_nondartel_1struct/endo2';  % base study directory
codeDir = '/u/project/sanscn/kevmtan/scripts/SPM12_nondartel/spm12_nondartel_1struct'; % where code lives
output = '/u/project/sanscn/kevmtan/scripts/SPM12_nondartel/spm12_nondartel_1struct/endo2batch'; % dir in which to save scripts
subID = 'endo*'; % pattern for finding subject folders (use wildcards)
runID = 'BOLD_*'; % pattern for finding functional run folders (use wildcards)
funcID ='BOLD_'; % first character(s) in your functional images? (do NOT use wildcards)
structID = 'MBW_*'; % pattern for finding structural folder (use wildcards)

% Subjects to do/skip, example: {'sub001' 'sub002'}
subNam = {}; % do which subjects? (leave empty to do all)
skipSub = {}; % skip which subjects? (leave empty to do all)

% 4d or 3d functional .nii?
fourDnii = 1; % 1=4d, 0=3d

% Path of TPM tissues in your SPM directory
tpmPath = '/u/project/CCN/apps/spm12/tpm';

% Customizable preprocessing parameters
voxSize = 3;    % voxel size at which to re-sample functionals (isotropic)
FWHM = 8; % smoothing kernel (isotropic)

% Execute (1) or just make matlabbatches (0)
execTAG = 0;
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

try
    mkdir(output);
catch
end

pool = parpool('local', numSubs);
parfor i = 1:numSubs
    % Pre-allocate subject in runStatus struct
    runStatus(i).subNam = subNam{i};
    
    % Cross-check subject with run/skip list
    if ismember(subNam{i}, skipSub)
        runStatus(i).status = 0;
        runStatus(i).error = 'Subject in exclusion list';
        disp(['Skipping subject ' subNam{i} ', is in exclusion list']);
        continue
    else % Run subject
        disp(['Running subject ' subNam{i}]);
            [runStatus(i).status, runStatus(i).error]...
                = run_nondartel_1struct(subNam{i}, owd, codeDir, output, runID,...
                funcID, structID, execTAG, voxSize, FWHM);
        if runStatus(i).status == 1
            disp(['subject ' subNam{i} ' successful']);
        else
            runStatus(i).status = 0;
            disp([runStatus(i).error ' for ' subNam{i}]);
        end
    end
end
delete(pool);



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