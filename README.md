# spm12-nondartel

Code for preprocessing of functional and structural MRI data into standardized MNI space using SPM12. 

* Code in <b>/spm12_nondartel_1struct</b> is for datasets that include only one structural scan (e.g. either T1 MPRAGE or T2 matched-bandwidth)
* Code for datasets that include two structural scans (e.g. T1 MPRAGE *and* T2 matched-bandwidth) may be developed in the future

<b>Instructions:</b>

Within each folder there is a <b>wrapper</b> script and a <b>run</b> function. All user-editable parameters are in an the epynomous section of the wrapper. Other sections of the wrapper script and run function shouldn't be edited unless you know what you're doing. Call only the wrapper as the wrapper will call the run function in either a for or parfor loop. Make sure to enable the "parallelize" variable in the wrapper if running 4+ subjects.
A "runStatus" struc containg each subject's status will be saved in the folder specified in "batchDir"
A text log of the matlab console output will be saved for predartel & dartel in the "batchDir" folder

<b>1struct algorithm:</b>
1) Realign functionals to mean functional & unwarp 
2) Segment, bias-correct, and get MNI normalization deformation fields for structural
3) Coregister functionals to bias-corrected structural grey matter
4) Normalize functionals to MNI space using forward deformations from structural
5) Smooth functionals using FWHM kernel
6) Normalize bias-corrected structural from segmentation deformations