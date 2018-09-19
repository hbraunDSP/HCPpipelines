function ssConcat(txtfile,wbcommand,outputConcat,VN)
%function [ output_args ] = ssConcat(txtfile,wbcommand,outputConcat,VN)
%This code demeans and concatinates timeseries on a single subject and expects to find these
%functions on the path:
%ciftiopen.m
%ciftisave.m
%demean.m

% edits by T.B.Brown to output debugging information

func_name='ssConcat';
fprintf('%s - start\n', func_name);
fprintf('%s - txtfile: %s\n', func_name, txtfile);
fprintf('%s - wbcommand: %s\n', func_name, wbcommand);
fprintf('%s - outputConcat: %s\n', func_name, outputConcat);
fprintf('%s - VN: %s\n', func_name, VN);

fid = fopen(txtfile);
fprintf('%s - open txtfile fid: %d\n', func_name, fid)

txtfileArray = textscan(fid,'%s');

txtfileArray = txtfileArray{1,1};
fprintf('%s - after txtfileArray conversion\n', func_name);

Vhdr = [];
volsize = [];

for i=1:length(txtfileArray)
    fprintf('%s - in loop over txtfileArray, i: %d\n', func_name, i);
    dtseriesName = txtfileArray{i,1};
    fprintf('%s - dtseriesName: %s\n', func_name, dtseriesName);
    fprintf('%s - opening: %s.dtseries.nii\n', func_name, dtseriesName);
    %dtseries = ciftiopen([dtseriesName '.dtseries.nii'],wbcommand);
    if isempty(Vhdr)
		Vhdr=load_nifti([dtseriesName '.nii.gz']);
		volsize=size(Vhdr.vol);
    end
    dtseries = loadnii2cifti([dtseriesName '.nii.gz']);
    if strcmp(VN,'YES')
        fprintf('%s - opening: %s._vn.dscalar.nii\n', func_name, dtseriesName);
        %vn = ciftiopen([dtseriesName '_vn.dscalar.nii'],wbcommand);
        vn = loadnii2cifti([dtseriesName '_vn.nii.gz']);
        fprintf('%s - opening: %s._bias.dscalar.nii\n', func_name, dtseriesName);
        %bias = ciftiopen([dtseriesName '_bias.dscalar.nii'],wbcommand);
        bias = loadnii2cifti([dtseriesName '_bias.nii.gz']);
    end    
    grot=demean(double(dtseries.cdata)')'; 
    fprintf('%s - after demean, i: %d\n', func_name, i);
    if i == 1
        if strcmp(VN,'YES')
            grot=grot.*repmat(bias.cdata,1,size(grot,2));
            grot=grot./repmat(max(vn.cdata,0.001),1,size(grot,2));
            grot=grot.*repmat(+(vn.cdata>0),1,size(grot,2)); %mask out VN=0
        end
        TCS=single(demean(grot')); clear grot;
    elseif i > 1
        if strcmp(VN,'YES')        
            grot=grot.*repmat(bias.cdata,1,size(grot,2));
            grot=grot./repmat(max(vn.cdata,0.001),1,size(grot,2));
            grot=grot.*repmat(+(vn.cdata>0),1,size(grot,2)); %mask out VN=0
        end    
        TCS=[TCS; single(demean(grot'))]; clear grot;
    end    
    
end

BO = dtseries;
BO.cdata = TCS';
fprintf('%s - About to ciftisave: %s\n', func_name, outputConcat);
%ciftisave(BO,outputConcat,wbcommand);
savecifti2nii(BO,Vhdr,outputConcat);

end

%%
function V = fillmask(mask,maskeddata)
V=zeros(size(mask,1),size(maskeddata,2));
V(mask,:)=maskeddata;
end

%%
function V = loadnii2cifti(filename)
if(ischar(filename) && exist(filename,'file'))
    Vhdr=load_nifti(filename);
    data=Vhdr.vol;
elseif(isstruct(filename))
    data=filename.vol;
elseif(isnumeric(filename) && ~isempty(filename))
    data=filename;
else
    error('unknown input');
end
   
if(ndims(data)>=3)
    data = reshape(data,[],size(data,4));
end
V=struct('cdata',data);
end
