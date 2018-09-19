function [ cifti ] = ciftiopen(filename,caret7command)
%Open a CIFTI file by converting to GIFTI external binary first and then
%using the GIFTI toolbox

if(~exist('caret7command','var') || isempty(caret7command))
    [~,caret7command]=system('which wb_command');
    caret7command=regexp(caret7command,'\n','split');
    caret7command=caret7command(~cellfun(@isempty,caret7command));
    caret7command=caret7command{1};
end

%grot=fileparts(filename);
%if (size(grot,1)==0)
%grot='.';
%end
%tmpname = tempname(grot);
tmpname=tempname;

%tic
%disp([caret7command ' -cifti-convert -to-gifti-ext ' filename ' ' tmpname '.gii']);
unix([caret7command ' -cifti-convert -to-gifti-ext ' filename ' ' tmpname '.gii']);
%toc

%which gifti
%tic
cifti = gifti([tmpname '.gii']);
%toc

unix(['rm ' tmpname '.gii ' tmpname '.gii.data']);

end

