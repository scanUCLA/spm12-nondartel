%% SPM12 non-dartel using one structural file (just MPRAGE or just MBW)
% Created by Kevin Tan on Jul 13, 2017 (some code adopted from Bob Spunt)

% Instructions, agorithmic description & edit history:
%   https://github.com/scanUCLA/spm12-nondartel

% Last revision: 29 July 2017 - Kevin Tan
%% User-editable Parameters

% Path/directory/name information
owd = '/u/project/sanscn/kevmtan/scripts/SPM12_nondartel/spm12_nondartel_1struct/endo2';  % base study directory
codeDir = '/u/project/sanscn/kevmtan/scripts/SPM12_nondartel/spm12_nondartel_1struct'; % where code lives
batchDir = '/u/project/sanscn/kevmtan/scripts/SPM12_nondartel/spm12_nondartel_1struct/endo2batch170727'; % dir in which to save batch scripts & subject status
subID = 'endo*'; % pattern for finding subject folders (use wildcards)
runID = 'BOLD_*'; % pattern for finding functional run folders (use wildcards)
funcID ='BOLD_'; % first character(s) in your functional images? (do NOT use wildcards)
structID = 'MBW_*'; % pattern for finding structural folder (use wildcards)

% Subjects to do/skip, example: {'sub001' 'sub002'}
subNam = {}; % do which subjects? (leave empty to do all)
skipSub = {}; % skip which subjects? (leave empty to do all)

% Parallelize across subjects? (enable for 4+ subjects)
parallelize = 1; % (1=yes, 0=no)

% 4d or 3d functional nifti files?
fourDnii = 1; % 1=4d, 0=3d

% Voxel size to resample to (use AFNI's dicom_hdr on the functional & structural DICOM files to figure out "slice thickness" and use that)
fVoxSize = 3; % functionals (mm isotropic)
sVoxSize = 1; % structurals (mm isotropic)

% smoothing kernel for functionals  (mm isotropic)
FWHM = 8;

% Path of TPM tissues in your SPM directory
tpmPath = '/u/project/CCN/apps/spm12/tpm';

% Execute (1) or just make matlabbatches (0)
execTAG = 0;

%% Setup subjects
diary([batchDir '/nondartel_log_' datestr(now,'yyyymmdd_HHMM') '.txt']);
% Find subject directories
if isempty(subNam)
    d = dir([owd '/' subID]);
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

% Make batch output folder
try
    mkdir(batchDir);
catch
end

if parallelize

% Determine number of parallel workers
myCluster = parcluster('local');
nWorkers = min(numSubs, myCluster.NumWorkers);

pool = parpool('local', nWorkers);
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
                = run_nondartel_1struct(subNam{i}, owd, codeDir, batchDir, runID,...
                funcID, structID, execTAG, fVoxSize, sVoxSize, FWHM, tpmPath);
            if runStatus(i).status == 1
                disp(['subject ' subNam{i} ' successful']);
            else
                runStatus(i).status = 0;
                disp([runStatus(i).error ' for ' subNam{i}]);
            end
        end
    end
    delete(pool);
else
    for i = 1:numSubs
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
                = run_nondartel_1struct(subNam{i}, owd, codeDir, batchDir, runID,...
                funcID, structID, execTAG, fVoxSize, sVoxSize, FWHM, tpmPath);
            if runStatus(i).status == 1
                disp(['subject ' subNam{i} ' successful']);
            else
                runStatus(i).status = 0;
                disp([runStatus(i).error ' for ' subNam{i}]);
            end
        end
    end
end

% Save stuff
date = datestr(now,'yyyymmdd_HHMM');
filename = [batchDir '/runStatus_' date '.mat'];
save(filename,'runStatus');
filename = [batchDir '/workspace_' date '.mat']; % You can use this to deep-dive into what went wrong
save(filename);
diary off
