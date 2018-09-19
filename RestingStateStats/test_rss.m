
%resultsfolder='/home/range1-raid1/kjamison/Data/MPS/MPS-1031/MNINonLinear/Results/REST1_LR';
%icafolder=[resultsfolder '/REST1_LR_hp2000.ica'];
% RestingStateStats([resultsfolder '/Movement_Regressors'],...
% 2000,0.905400 ,...
% [icafolder '/filtered_func_data.ica/melodic_mix'],...
% [icafolder '/.fix'],...
% '/home/range1-raid1/kjamison/workbench_dev/bin_rh_linux64/wb_command',...
% [resultsfolder '/REST1_LR_Atlas'],...
% [resultsfolder '/REST1_LR_Atlas_BiasField.dscalar.nii'],...
% [],'');

% studyfolder='/home/range1-raid1/kjamison/Data/Phase2_7T';
% alltasks={'REST_REST1_PA','REST_REST2_AP','REST_REST3_PA','REST_REST4_AP'};
% %subject='690152';
% subject='102311';
% fmrires='1.60';

studyfolder='/home/range1-raid1/kjamison/Data/HCP3T';
alltasks={'rfMRI_REST1_LR','rfMRI_REST1_RL','rfMRI_REST2_LR','rfMRI_REST2_RL'};
%alltasks={'rfMRI_REST1_RL','rfMRI_REST2_LR'};
%subject='690152';
subject='102311';
fmrires='2';

%alltasks=alltasks(2:end);


%taskname='REST_REST1_PA';

for tn=1:numel(alltasks)
    taskname=alltasks{tn};

    resultsfolder=sprintf('%s/%s/MNINonLinear/Results/%s',studyfolder,subject,taskname);
    icafolder=sprintf('%s/%s_hp2000.ica',resultsfolder,taskname);


    inseries=sprintf('%s/%s.nii.gz',resultsfolder,taskname);
    %biasfield=sprintf('%s/%s_hp2000_BiasField.nii.gz',resultsfolder,taskname);
    ribbonfolder=sprintf('%s/RibbonVolumeToSurfaceMapping',resultsfolder);

    graymask=sprintf('%s/ribbon_only_dil1mask.nii.gz',ribbonfolder);
    if(~exist(graymask,'file'))
        system(sprintf(['fslmaths ' ribbonfolder '/ribbon_only.nii.gz -dilM -mul ' ribbonfolder '/mask.nii.gz -bin ' graymask ]));
        %fslmaths ribbon_only.nii.gz -dilM -mul mask.nii.gz -bin ribbon_only_dil1mask.nii.gz
    end

    %biasfield=[];

    biasfield=sprintf('%s/BiasField.%s.nii.gz',resultsfolder,fmrires);
    if(~exist(biasfield,'file'))
        origfolder=sprintf('%s/%s/%s',studyfolder,subject,taskname);
        biasfield=sprintf('%s/BiasField.%s.nii.gz',origfolder,fmrires);
    end

    noisetext=sprintf('%s/HandNoise.txt',icafolder);
    if(~exist(noisetext,'file'))
        noisetext=sprintf('%s/Noise.txt',icafolder);
    end
    hp=2000;
    %hp=inseries;

    tic
    RestingStateStats_nifti(sprintf('%s/Movement_Regressors',resultsfolder),...
    hp,0.905400 ,...
    sprintf('%s/filtered_func_data.ica/melodic_mix',icafolder),...
    noisetext,...
    '/home/range1-raid1/kjamison/workbench_dev/bin_rh_linux64/wb_command',...
    inseries,...
    biasfield,...
    [],'',graymask);
    toc
end