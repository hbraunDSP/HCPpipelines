
%%
function savecifti2nii(tcs,Vhdr,filename,mask)
sz=Vhdr.dim(2:4);
if(isstruct(tcs))
    tcs=tcs.cdata;
end

if(exist('mask','var') && ~isempty(mask))
    maskdata=reshape(tcs,sum(mask>0),[]);
    fulldata=zeros(sz(1)*sz(2)*sz(3),size(maskdata,2));
    fulldata(mask,:)=tcs;
    Vhdr.vol=reshape(fulldata,sz(1),sz(2),sz(3),[]);
else
    Vhdr.vol=reshape(tcs,sz(1),sz(2),sz(3),[]);
end
if(size(Vhdr.vol,4) == 1)
    Vhdr.dim([1 5])=[3 1];
elseif(size(Vhdr.vol,4) > 1)
    Vhdr.dim([1 5])=[4 size(Vhdr.vol,4)];
end
save_nifti(Vhdr,filename);
end
