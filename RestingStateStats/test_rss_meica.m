%%

%avoid strsplit conflict
rmpath('/home/range1-raid1/kjamison/Source/knkutils/string/');
rmpath('/home/range1-raid1/kjamison/Source/analyzePRF/utilities/');

wbcommand='/home/range1-raid1/kjamison/workbench_v1.1.1/bin_rh_linux64/wb_command';
studydir='/home/range1-raid1/kjamison/Data/MBME';

subj='MBMEV0*';
%ScanName='rfMRI_REST1_2.5mm_MB4R2ME3_6_8pf_PA';

%scangroup={'REST1','REST2','REST1v2','REST2v2','REST1v3','REST2v3'};
scangroups={'REST1v4','REST2v4','REST1v3','REST2v3'};


for sg = 1:numel(scangroups)
    scangroup=scangroups{sg};
    %res='2.5';
    res='';
    suff='_tsoc';
    [~,statfiles]=system(sprintf('find %s/%s/MNINonLinear/Results/*%s*%smm*/ -type f -name "*_PA%s_Atlas_stats.txt" | grep -E ''REST[12](v[0-9])?'' | grep stats.txt | sort',studydir,subj,scangroup,res,suff));
    statfiles=strsplit(statfiles,'\n');
    statfiles=statfiles(~cellfun(@isempty,statfiles));

    for sc = 1:numel(statfiles)
        Subject=regexprep(statfiles{sc},'^.+Data/MBME/(MBMEV0[^/]+)/.+$','$1');
        ScanName=justfilename(justdir(statfiles{sc}));
        scandir=sprintf('%s/%s/MNINonLinear/Results/%s',studydir,Subject,ScanName)

        fixnoisefile=sprintf('%s/%s_ctab_fixformat.txt',scandir,ScanName);

        [~,stout]=system(sprintf('meica_ctab_to_fix %s/%s_ctab.txt %s',scandir,ScanName,fixnoisefile));

        [~,TR]=call_fsl(sprintf('fslval %s/%s pixdim4',scandir,ScanName));
        TR=str2num(TR);
        motionparameters=sprintf('%s/Movement_Regressors.txt',scandir);
        hp=2000;

        ICAs=sprintf('%s/meica/TED/meica_mix.1D',scandir);
        noiselist=fixnoisefile;
        inputdtseries=sprintf('%s/%s_tsoc_Atlas.dtseries.nii',scandir,ScanName);
        bias=[];
        outprefix=sprintf('%s/%s_meicaRSS_Atlas',scandir,ScanName);
        dlabel=[];
        RestingStateStats_meica(motionparameters,hp,TR,ICAs,noiselist,wbcommand,inputdtseries,bias,outprefix,dlabel)
    end
end