function [status, errorMsg] = run_nondartel_1struct(subNam, owd, codeDir, output,...
    runID, funcID, mpragedirID, execTAG, voxSize, FWHM, tpmPath)

%% Parameters
funcFormat=2;       % format of your raw functional images (1=img/hdr, 2=4D nii)

%% Setup for Matlabbatch
status = NaN;
errorMsg = '';
try
    spm('defaults','fmri'); spm_jobman('initcfg');
    
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
            tmpString=sprintf('^%s.*\\.img$',funcID);
            [raw_func_filenames{i},dirs] = spm_select('List',load_dir{i},tmpString, inf);
            filenames_orig{i}=cellstr(strcat(load_dir{i},filesep,raw_func_filenames{i}));
            %filenames_norm{i}=cellstr(strcat(load_dir{i},filesep,'w',raw_func_filenames{i}));
            allfiles_orig = [allfiles_orig; filenames_orig{i}];
        else
            tmpString=sprintf('^%s.*\\.nii$',funcID);
            [raw_func_filenames{i},dirs] = spm_select('ExtFPList',load_dir{i},tmpString, inf);
            filenames_orig{i}=cellstr(strcat(raw_func_filenames{i}));
            %filenames_norm{i}=cellstr(strcat('w',raw_func_filenames{i}));
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
    
    % find the mprage folder
    d=dir(mpragedirID);
    mprdir = [base_dir filesep d(1).name];
    
    % get the images
    cd(mprdir); d = dir([mpragedirID '.nii']);
    mprage_name = d.name; clear d
    t1vol = [mprdir filesep mprage_name];
    fprintf('MPRAGE is: %s\n\n',t1vol)
    
    %% Build Matlabbatch
    
    matlabbatch{1}.cfg_basicio.cfg_cd.dir = cellstr(strcat(swd,filesep,'notes'));
    
    % Realign & Unwarp Functionals
    for i = 1:numruns
        matlabbatch{2}.spm.spatial.realignunwarp.data(i).scans = filenames_orig{i};
        matlabbatch{2}.spm.spatial.realignunwarp.data(i).pmscan = '';
    end
    matlabbatch{2}.spm.spatial.realignunwarp.eoptions.quality = 0.9;
    matlabbatch{2}.spm.spatial.realignunwarp.eoptions.sep = 4;
    matlabbatch{2}.spm.spatial.realignunwarp.eoptions.fwhm = 5;
    matlabbatch{2}.spm.spatial.realignunwarp.eoptions.rtm = 1; % default is 0, changed to 1 (potentially more accurate)
    matlabbatch{2}.spm.spatial.realignunwarp.eoptions.einterp = 4; % default is 2, changed to 4 (more accurate)
    matlabbatch{2}.spm.spatial.realignunwarp.eoptions.ewrap = [0 0 0];
    matlabbatch{2}.spm.spatial.realignunwarp.eoptions.weight = '';
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.basfcn = [12 12];
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.regorder = 1;
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.lambda = 100000;
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.jm = 0;
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.fot = [4 5];
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.sot = [];
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.uwfwhm = 4;
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.rem = 1;
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.noi = 5;
    matlabbatch{2}.spm.spatial.realignunwarp.uweoptions.expround = 'Average';
    matlabbatch{2}.spm.spatial.realignunwarp.uwroptions.uwwhich = [2 1];
    matlabbatch{2}.spm.spatial.realignunwarp.uwroptions.rinterp = 4;
    matlabbatch{2}.spm.spatial.realignunwarp.uwroptions.wrap = [0 0 0];
    matlabbatch{2}.spm.spatial.realignunwarp.uwroptions.mask = 1;
    matlabbatch{2}.spm.spatial.realignunwarp.uwroptions.prefix = 'u';
    
    % Segment, bias-correct, and spatially-normalize MPRAGE
    matlabbatch{3}.spm.spatial.preproc.channel.vols = cellstr(t1vol);
    matlabbatch{3}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{3}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{3}.spm.spatial.preproc.channel.write = [0 1];
    matlabbatch{3}.spm.spatial.preproc.tissue(1).tpm = cellstr([tpmPath '/TPM.nii,1']);
    matlabbatch{3}.spm.spatial.preproc.tissue(1).ngaus = 2;
    matlabbatch{3}.spm.spatial.preproc.tissue(1).native = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(1).warped = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(2).tpm = cellstr([tpmPath '/TPM.nii,2']);
    matlabbatch{3}.spm.spatial.preproc.tissue(2).ngaus = 2;
    matlabbatch{3}.spm.spatial.preproc.tissue(2).native = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(2).warped = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(3).tpm = cellstr([tpmPath '/TPM.nii,3']);
    matlabbatch{3}.spm.spatial.preproc.tissue(3).ngaus = 2;
    matlabbatch{3}.spm.spatial.preproc.tissue(3).native = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(3).warped = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(4).tpm = cellstr([tpmPath '/TPM.nii,4']);
    matlabbatch{3}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{3}.spm.spatial.preproc.tissue(4).native = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(4).warped = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(5).tpm = cellstr([tpmPath '/TPM.nii,5']);
    matlabbatch{3}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{3}.spm.spatial.preproc.tissue(5).native = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(5).warped = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(6).tpm = cellstr([tpmPath '/TPM.nii,6']);
    matlabbatch{3}.spm.spatial.preproc.tissue(6).ngaus = 2;
    matlabbatch{3}.spm.spatial.preproc.tissue(6).native = [0 0];
    matlabbatch{3}.spm.spatial.preproc.tissue(6).warped = [0 0];
    matlabbatch{3}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{3}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{3}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{3}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{3}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{3}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{3}.spm.spatial.preproc.warp.write = [0 1];
    
    % Coregister mean functional to MPRAGE
    matlabbatch{4}.spm.spatial.coreg.estimate.ref(1) = cfg_dep('Segment: Bias Corrected (1)', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','channel', '()',{1}, '.','biascorr', '()',{':'}));
    matlabbatch{4}.spm.spatial.coreg.estimate.source(1) = cfg_dep('Realign & Unwarp: Unwarped Mean Image', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','meanuwr'));
    for i = 1:numruns
        matlabbatch{4}.spm.spatial.coreg.estimate.other(i) = cfg_dep(['Realign & Unwarp: Unwarped Images (Sess ' num2str(i) ')'], substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{i}, '.','uwrfiles'));
    end
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{4}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7]; 
    
    % Apply normalization parameters from MPRAGE to functionals
    matlabbatch{5}.spm.spatial.normalise.write.subj.def(1) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
    matlabbatch{5}.spm.spatial.normalise.write.subj.resample(1) = cfg_dep('Coregister: Estimate: Coregistered Images', substruct('.','val', '{}',{4}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
    matlabbatch{5}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
        78 76 85];
    matlabbatch{5}.spm.spatial.normalise.write.woptions.vox = [voxSize voxSize voxSize];
    matlabbatch{5}.spm.spatial.normalise.write.woptions.interp = 4;
    matlabbatch{5}.spm.spatial.normalise.write.woptions.prefix = 'w';
    
    % Smooth
    matlabbatch{6}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{5}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
    matlabbatch{6}.spm.spatial.smooth.fwhm = [FWHM FWHM FWHM];
    matlabbatch{6}.spm.spatial.smooth.dtype = 0;
    matlabbatch{6}.spm.spatial.smooth.im = 0;
    matlabbatch{6}.spm.spatial.smooth.prefix = 's';
    
catch
    status = 0;
    errorMsg = 'Error making matlabbatch';
    disp([errorMsg ' for ' subNam]);
    cd(codeDir);
    return
end

%% Save matlabbatch
try
    time_stamp = datestr(now, 'yyyymmdd_HHMM');
    filename = [output '/nondartel_1struct_' subNam '_' time_stamp];
    save(filename, 'matlabbatch');
catch
    status = 0;
    errorMsg = 'Error saving matlabbatch';
    disp([errorMsg ' for ' subNam]);
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
    disp([errorMsg ' for ' subNam]);
    cd(codeDir);
    return
end
