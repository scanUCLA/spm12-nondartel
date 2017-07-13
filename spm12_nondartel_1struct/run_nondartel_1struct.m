function [status, errorMsg] = run_nondartel_1struct(subNam, owd, codeDir, output, runID, mpragedirID)

%% Parameters
funcFormat=2;       % format of your raw functional images (1=img/hdr, 2=4D nii)
funcName='BOLD';       % first character(s) in your functional images? (do not use wildcards)
mbwID = 'Matched_Bandwidth_HiRes_*.nii';   % pattern for finding matched-bandwidth image (use wildcards)
mprageID = 'MPRAGE_SAG_*.nii';    % pattern for finding mprage image (use wildcards)

% customizable preprocessing parameters
vox_size = 2;    % voxel size at which to re-sample functionals (isotropic)
smooth_FWHM = 8; % smoothing kernel (isotropic)

execTAG = 1;
%% Setup for Matlabbatch
spm12_path;
spm('defaults','fmri'); spm_jobman('initcfg');

status = NaN;
errorMsg = '';
try
    
    cd(owd)
    swd = sprintf('%s/%s',owd,subNam);
    fprintf('Subject directory is %s\n',swd)
    cd(swd)
    cd raw
    base_dir = pwd;
    
    % Find run directories
    d=dir(runID);
    run_names = {d.name};
    numruns=length(run_names);
    fprintf('Found %d runs\n',numruns)
    
    % Find functional images for run(s)
    %-----------------------------------------------------------------%
    load_dir = {};
    raw_func_filenames = {};
    allfiles_orig = {};
    allfiles_norm = {};
    for i = 1:numruns
        load_dir{i} = fullfile(base_dir,run_names{i});
        if funcFormat==1
            tmpString=sprintf('^%s.*\\.img$',funcName);
            [raw_func_filenames{i},dirs] = spm_select('List',load_dir{i},tmpString, inf);
            filenames_orig{i}=cellstr(strcat(load_dir{i},filesep,raw_func_filenames{i}));
            filenames_norm{i}=cellstr(strcat(load_dir{i},filesep,'w',raw_func_filenames{i}));
            allfiles_orig = [allfiles_orig; filenames_orig{i}];
        else
            tmpString=sprintf('^%s.*\\.nii$',funcName);
            [raw_func_filenames{i},dirs] = spm_select('ExtFPList',load_dir{i},tmpString, inf);
            filenames_orig{i}=cellstr(strcat(raw_func_filenames{i}));
            filenames_norm{i}=cellstr(strcat('w',raw_func_filenames{i}));
            allfiles_orig = [allfiles_orig; filenames_orig{i}];
        end
    end
    if funcFormat==1
        mean_func=cellstr(strcat(load_dir{1},filesep,'mean',raw_func_filenames{1}(1,:)));
    else
        [path name ext] = fileparts(allfiles_orig{1});
        mean_func=cellstr(strcat(path,filesep,'mean',name,'.nii'));
    end
    load_dir = fullfile(base_dir,run_names{i});
    
    % Find the anatomicals
    % -------------------------------------------------
    
    %     % find the mbw folder
    %     d=dir(mbwdirID);
    %     mbwdir = [base_dir filesep d(1).name];
    %     cd(mbwdir); d = dir(mbwID);
    %     mbw_name = d.name; clear d
    %     mbw = [mbwdir filesep mbw_name];
    %     fprintf('MBW is: %s\n',mbw)
    
    % find the mprage folder
    d=dir(mpragedirID);
    mprdir = [base_dir filesep d(1).name];
    cd(mprdir); d = dir(mprageID);
    mprage_name = d.name; clear d
    t1vol = [mprdir filesep mprage_name];
    fprintf('MPRAGE is: %s\n\n',t1vol)
    
    %     % for DARTEL
    %     allfuncs = allfiles_orig;
    %     allt1 = [t1vol];
    %     allrc1 = [mprdir filesep 'rc1' mprage_name(1:end-4) '.nii'];
    %     allrc2 = [mprdir filesep 'rc2' mprage_name(1:end-4) '.nii'];
    %     allu_rc1 = [mprdir filesep 'u_rc1' mprage_name(1:end-4) '_Template.nii'];
    
    %% Build Matlabbatch
    
    matlabbatch{1}.cfg_basicio.cfg_cd.dir = cellstr(strcat(swd,filesep,'notes'));
    
    % Realign Functionals
    for i = 1:numruns
        matlabbatch{2}.spm.spatial.realign.estwrite.data{i} = filenames_orig{i};
    end
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;         % higher quality
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.sep = 4;               % default is 4
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;              % default
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.rtm = 1;               % changed from 0 (=realign to first) to 1 (realign to mean) for
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.interp = 4;            % default
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];        % default
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.weight = '';           % don't weight
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.which  = [0 1];        % create mean image only when reslicing
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.interp = 4;            % default
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.wrap   = [0 0 0];      % no wrap (default)
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.mask   = 1;            % enable masking (default)
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.prefix = 'r';
    
    % Normalize/segment MPRAGE
    matlabbatch{3}.spm.spatial.normalise.est.subj.vol = cellstr(t1vol);
    matlabbatch{3}.spm.spatial.normalise.est.eoptions.biasreg = 0.0001;
    matlabbatch{3}.spm.spatial.normalise.est.eoptions.biasfwhm = 60;
    matlabbatch{3}.spm.spatial.normalise.est.eoptions.tpm = {'/u/project/CCN/apps/spm12/tpm/TPM.nii'};
    matlabbatch{3}.spm.spatial.normalise.est.eoptions.affreg = 'mni';
    matlabbatch{3}.spm.spatial.normalise.est.eoptions.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{3}.spm.spatial.normalise.est.eoptions.fwhm = 0;
    matlabbatch{3}.spm.spatial.normalise.est.eoptions.samp = 3;
    
    % Coregister mean functional to MPRAGE
    matlabbatch{4}.spm.spatial.coreg.estimate.ref = cellstr(t1vol);
    matlabbatch{4}.spm.spatial.coreg.estimate.source(1) = cfg_dep('Realign: Estimate & Reslice: Mean Image', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rmean'));
    for i = 1:numruns
        matlabbatch{4}.spm.spatial.coreg.estimate.other(i) = cfg_dep(['Realign: Estimate & Reslice: Realigned Images (Sess ' num2str(i) ')'], substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{i}, '.','cfiles'));
    end
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];
    
    % Apply normalization parameters from MPRAGE to functionals
    matlabbatch{5}.spm.spatial.normalise.write.subj.def(1) = cfg_dep('Normalise: Estimate: Deformation (Subj 1)', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','def'));
    matlabbatch{5}.spm.spatial.normalise.write.subj.resample(1) = cfg_dep('Coregister: Estimate: Coregistered Images', substruct('.','val', '{}',{4}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
    matlabbatch{5}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
        78 76 85];
    matlabbatch{5}.spm.spatial.normalise.write.woptions.vox = [vox_size vox_size vox_size];
    matlabbatch{5}.spm.spatial.normalise.write.woptions.interp = 4;
    
    % Smooth
    matlabbatch{6}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{5}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
    matlabbatch{6}.spm.spatial.smooth.fwhm = [smooth_FWHM smooth_FWHM smooth_FWHM];
    matlabbatch{6}.spm.spatial.smooth.dtype = 0;
    matlabbatch{6}.spm.spatial.smooth.im = 0;
    matlabbatch{6}.spm.spatial.smooth.prefix = 's';
    
catch
    status = 0;
    errorMsg = 'Error making matlabbatch';
    cd(codeDir);
    return
end

%% Save matlabbatch
try
    time_stamp = datestr(now, 'yyyymmdd_HHMM');
    filename = [output '/nondartelSeg_' subNam '_' time_stamp];
    save(filename, 'matlabbatch');
catch
    status = 0;
    errorMsg = 'Error saving matlabbatch';
    cd(codeDir);
    return
end
%% Run Matlabbatch
try
    if execTAG == 1
        spm_jobman('run',matlabbatch);
    end
    status = 1;
    cd(codeDir);
catch
    status = 0;
    errorMsg = 'Error running matlabbatch';
    cd(codeDir);
    return
end
